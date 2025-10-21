#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
export SCRIPT_DIR

host_ip="$(hostname -I | awk '{ print $1 }')"
export INGRESS_HOST="${host_ip}.nip.io"
export JENKINS_PREFIX="/jenkins"
export JENKINS_URL="http://${INGRESS_HOST}${JENKINS_PREFIX}"
unset host_ip

if [[ "${CLEAN:-false}" == true ]]; then
    k3d cluster delete jenkins-agent-dind-test
fi

if k3d cluster get jenkins-agent-dind-test; then
    k3d cluster start jenkins-agent-dind-test
    k3d kubeconfig merge jenkins-agent-dind-test --kubeconfig-merge-default
else
    k3d cluster create jenkins-agent-dind-test --port 80:80@loadbalancer \
        --registry-create jenkins-agent-dind-test-registry:0.0.0.0:15432
fi

function cleanup() {
    if [[ "${CI:-}" == true ]]; then
        k3d cluster delete jenkins-agent-dind-test
    else
        echo >&2
        echo "Jenkins can be accessed at:"
        echo "  ${JENKINS_URL}" >&2
        echo >&2
        echo "To cleanup, run:" >&2
        echo "  k3d cluster delete jenkins-agent-dind-test" >&2
    fi
}

trap cleanup EXIT

function prepare_agent() {
    set -eux

    kubectl apply -f https://raw.githubusercontent.com/felipecrs/dynamic-hostports-k8s/master/deploy.yaml

    cd "${SCRIPT_DIR}/.."

    docker buildx bake jenkins-agent-dind --push \
        --set jenkins-agent-dind.tags=localhost:15432/jenkins-agent-dind:latest

    # kubectl run --rm doesn't always delete the pod, apparently
    kubectl delete pod test --ignore-not-found
    kubectl run --attach --restart=Never --rm --privileged --image-pull-policy=Always --image jenkins-agent-dind-test-registry:5000/jenkins-agent-dind:latest test -- \
        docker version
    kubectl delete pod test --ignore-not-found
}

function prepare_jenkins() {
    set -eux

    cd "${SCRIPT_DIR}/test-fixtures"

    # renovate: datasource=github-releases depName=jenkins-helm-chart packageName=jenkinsci/helm-charts extractVersion=^jenkins-(?<version>.*)$
    local jenkins_chart_version="5.8.104"

    rm -rf jenkins jenkins-*.tgz
    ./werf_as_helm.sh pull --untar \
        "https://github.com/jenkinsci/helm-charts/releases/download/jenkins-${jenkins_chart_version}/jenkins-${jenkins_chart_version}.tgz"
    rm -rf jenkins-*.tgz

    local default_jenkins_version
    default_jenkins_version=$(yq -e .appVersion jenkins/Chart.yaml)

    local default_plugins
    default_plugins=$(yq -e '.controller.installPlugins | join(" ")' jenkins/values.yaml)

    docker buildx build . \
        --build-arg JENKINS_VERSION="${JENKINS_VERSION:-"${default_jenkins_version}-alpine-jdk21"}" \
        --build-arg DEFAULT_PLUGINS="${default_plugins}" \
        --tag localhost:15432/jenkins:latest --push

    helmfile sync --enable-live-output

    kubectl exec jenkins-0 --container=jenkins -- \
        curl -fsSL "http://127.0.0.1:8080${JENKINS_PREFIX}/jnlpJars/jenkins-cli.jar" --output /tmp/jenkins-cli.jar
}

function build_jenkins_job() {
    set -eux

    kubectl exec jenkins-0 --container=jenkins -- \
        java -jar /tmp/jenkins-cli.jar -s "http://127.0.0.1:8080${JENKINS_PREFIX}" \
        build "${1}" -s -v -f
}

export -f prepare_agent prepare_jenkins build_jenkins_job

parallel_cmd=(parallel --line-buffer --tag --halt 'now,fail=1')

"${parallel_cmd[@]}" ::: \
    prepare_agent prepare_jenkins

if [[ "${SKIP_BUILDS:-false}" == false ]]; then
    "${parallel_cmd[@]}" -- \
        build_jenkins_job ::: test-agent/declarative test-agent/scripted
fi
