#!/bin/bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

set -x

cd "${script_dir}/.."

devcontainer build --workspace-folder .

container_id=$(
    devcontainer up --workspace-folder . |
        tee /dev/stderr |
        jq -r .containerId
)

trap 'docker rm -f "${container_id}"' EXIT

devcontainer exec --workspace-folder . docker version

devcontainer exec --workspace-folder . printenv | sort | tee /dev/stderr | grep -q ^USER=

# check if dond shim is setup correctly
devcontainer exec --workspace-folder . bash -c 'DOND_SHIM_PRINT_COMMAND=true docker version' | tee /dev/stderr | grep -q '^docker.orig version$'

docker rm -f "${container_id}"

container_id=$(
    devcontainer up --workspace-folder . --config devcontainer/test-fixtures/dind-devcontainer/devcontainer.json |
        tee /dev/stderr |
        jq -r .containerId
)

devcontainer exec --workspace-folder . --config devcontainer/test-fixtures/dind-devcontainer/devcontainer.json \
    docker version

devcontainer exec --workspace-folder . --config devcontainer/test-fixtures/dind-devcontainer/devcontainer.json \
    env IGNORE_FAILURE=false /ssh-command/get.sh

ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR ssh://devcontainer@localhost:2222 \
    docker version
