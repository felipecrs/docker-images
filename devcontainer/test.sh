#!/bin/bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

set -x

cd "${script_dir}/.."

devcontainer build --workspace-folder .

container_id=$(devcontainer up --workspace-folder . | tee /dev/stderr | jq -r .containerId)

trap 'docker rm -f "${container_id}"' EXIT

devcontainer exec --workspace-folder . docker version

# shellcheck disable=SC2016
devcontainer exec --workspace-folder . printenv | sort | tee /dev/stderr | grep ^USER=
