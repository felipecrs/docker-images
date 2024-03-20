#!/bin/bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

set -x

if ! k3d cluster get jenkins-agent-dind-test; then
    k3d cluster create jenkins-agent-dind-test \
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

cd "${script_dir}/.."

docker buildx bake jenkins-agent-dind --push \
    --set jenkins-agent-dind.tags=localhost:15432/jenkins-agent-dind:latest

retry --verbose --tries=3 --sleep=3 -- kubectl run --rm -i --privileged --image jenkins-agent-dind-test-registry:5000/jenkins-agent-dind:latest test -- docker version

cd "${script_dir}/test-fixtures"

docker buildx build . --tag localhost:15432/jenkins:latest --push

kubectl apply -f https://raw.githubusercontent.com/felipecrs/dynamic-hostports-k8s/master/deploy.yaml

helmfile sync --enable-live-output

kubectl exec -it jenkins-0 -- bash <<EOF
set -euxo pipefail

curl -fsSL http://127.0.0.1:8080/jnlpJars/jenkins-cli.jar -o /tmp/jenkins-cli.jar

exec java -jar /tmp/jenkins-cli.jar -s http://127.0.0.1:8080 \
    build test-agent -s -v -f
EOF
