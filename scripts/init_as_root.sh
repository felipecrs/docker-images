#!/bin/bash
#
# This script needs to be compiled with shc enabling the suid bit, so we have
# privileges to operate as root.
#
# /init: s6-overlay

set -eu

# This can probably be improved:
# https://github.com/just-containers/s6-overlay/issues/394#issuecomment-1690769622
if [[ "${SSHD_ENABLED:-false}" == true ]]; then
    mv -f /etc/optional-services.d/sshd /etc/services.d/sshd
fi

# check if docker socket is mounted, meaning we are running in docker on docker mode
if [[ -S "/var/run/docker.sock" ]]; then
    # setup docker-on-docker-shim by default when running in docker on docker mode
    docker_path=$(command -v docker)
    mv -f "${docker_path}" "${docker_path}.orig"
    dond_path=$(command -v dond)
    mv -f "${dond_path}" "${docker_path}"
    unset docker_path dond_path
else
    mv -f /etc/optional-services.d/dind /etc/services.d/dind
fi

exec -- /init "$@"
