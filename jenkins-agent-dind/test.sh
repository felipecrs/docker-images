#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
export SCRIPT_DIR

set -x

if ! k3d cluster get jenkins-agent-dind-test; then
    k3d cluster create jenkins-agent-dind-test \
        --agents 3 \
        --registry-create jenkins-agent-dind-test-registry:0.0.0.0:15432
fi

function cleanup() {
    if [[ "${CI:-}" == true ]]; then
        k3d cluster delete jenkins-agent-dind-test
    else
        echo "To cleanup, run:" >&2
        echo "  k3d cluster delete jenkins-agent-dind-test" >&2
    fi
}

trap cleanup EXIT

function prepare_agent() {
    set -eux

    cd "${SCRIPT_DIR}/.."

    docker buildx bake jenkins-agent-dind --push \
        --set jenkins-agent-dind.tags=localhost:15432/jenkins-agent-dind:latest

    retry --tries=3 --sleep=3 -- \
        kubectl run --attach --restart=Never --rm --privileged --image jenkins-agent-dind-test-registry:5000/jenkins-agent-dind:latest test -- \
        docker version

    kubectl apply -f https://raw.githubusercontent.com/felipecrs/dynamic-hostports-k8s/master/deploy.yaml
}

function prepare_jenkins() {
    set -eux

    cd "${SCRIPT_DIR}/test-fixtures"

    # renovate: datasource=github-releases depName=jenkinsci/helm-charts extractVersion=^jenkins-(?<version>.*)$
    local jenkins_chart_version="5.4.3"

    rm -rf jenkins jenkins-*.tgz
    ./werf_as_helm.sh pull --untar \
        "https://github.com/jenkinsci/helm-charts/releases/download/jenkins-${jenkins_chart_version}/jenkins-${jenkins_chart_version}.tgz"

    local jenkins_version
    jenkins_version=$(yq -e .appVersion jenkins/Chart.yaml)

    docker buildx build . \
        --build-arg JENKINS_VERSION="${jenkins_version}" \
        --tag localhost:15432/jenkins:latest --push

    # retry because of https://github.com/werf/werf/issues/6048
    retry --tries=2 --sleep=0 -- \
        helmfile sync --enable-live-output

    kubectl exec jenkins-0 --container=jenkins -- \
        curl -fsSL http://127.0.0.1:8080/jnlpJars/jenkins-cli.jar --output /tmp/jenkins-cli.jar
}

function build_jenkins_job() {
    set -eux

    kubectl exec jenkins-0 --container=jenkins -- \
        java -jar /tmp/jenkins-cli.jar -s http://127.0.0.1:8080 \
        build "${1}" -s -v -f
}

export -f prepare_agent prepare_jenkins build_jenkins_job

parallel_cmd=(parallel --line-buffer --tag --halt 'now,fail=1')

"${parallel_cmd[@]}" ::: \
    prepare_agent prepare_jenkins

"${parallel_cmd[@]}" -- \
    build_jenkins_job ::: test-agent-declarative test-agent-scripted
