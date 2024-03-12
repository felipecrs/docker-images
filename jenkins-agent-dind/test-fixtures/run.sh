#!/bin/bash

set -euxo pipefail

if ! k3d cluster get jenkins-agent-dind-test; then
    k3d cluster create jenkins-agent-dind-test
fi

function cleanup() {
    if [[ "${CI:-}" == "true" ]]; then
        k3d cluster delete jenkins-agent-dind-test
    else
        echo "To cleanup, run:" >&2
        echo "  k3d cluster delete jenkins-agent-dind-test" >&2
    fi
}

trap cleanup EXIT

script_dir=$(dirname "${0}")

cd "${script_dir}"

k3d image import --cluster jenkins-agent-dind-test --mode direct \
    localhost/jenkins-agent-dind:latest

kubectl apply -f https://raw.githubusercontent.com/felipecrs/dynamic-hostports-k8s/master/deploy.yaml

helmfile sync --enable-live-output

kubectl exec -it jenkins-0 -- bash <<EOF
set -euxo pipefail

curl -fsSL http://127.0.0.1:8080/jnlpJars/jenkins-cli.jar -o /tmp/jenkins-cli.jar

exec java -jar /tmp/jenkins-cli.jar -s http://127.0.0.1:8080 -auth admin:admin \
    build test-agent -s -v -f
EOF
