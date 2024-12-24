#!/bin/bash

set -eu

docker_binary_original_path="$(command -v docker.real)"
docker_path="${docker_binary_original_path/".real"/}"
docker_binary_final_path="${docker_path}"
# in docker on docker mode, use docker-on-docker-shim by default
if mountpoint --quiet "/var/run/docker.sock"; then
    docker_binary_final_path="${docker_path}.orig"
    dond_path="$(command -v dond)"
    mv -f "${dond_path}" "${docker_path}"
fi
mv -f "${docker_binary_original_path}" "${docker_binary_final_path}"

exec -- "$@"
