#!/bin/bash

set -eu

# if the docker socket is mounted, it means we are running in docker on docker
# mode and therefore we should not start the dind service
if mountpoint --quiet "/var/run/docker.sock"; then
    # in docker on docker mode, use docker-on-docker-shim by default
    docker_path=$(command -v docker)
    mv -f "${docker_path}" "${docker_path}.orig"
    dond_path=$(command -v dond)
    mv -f "${dond_path}" "${docker_path}"

    exit 1
fi

exit 0
