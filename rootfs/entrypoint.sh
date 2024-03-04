#!/bin/bash
#
# This entrypoint first executes fixuid to fix the uid and gid of the user
# within the to match the user which the container was executed as. Then,
# executes init_as_root.sh, which operates as root to execute s6-overlay, drops
# the permissions to the regular user which started the container and executes
# the passed in CMD.

set -eu

# Handle when no CMD is provided
if [[ $# -eq 0 ]]; then
    # If JENKINS_URL is preset, assume we are running as a Kubernetes Pod template agent
    if [[ -n "${JENKINS_URL:-}" ]]; then
        set -- jenkins-agent
    # Otherwise, if attached to a terminal, start a shell
    elif [[ -t 0 ]]; then
        set -- bash
    # Otherwise, just keep the container running
    else
        set -- sleep infinity
    fi
fi

uid="$(id -u)"
if [[ "${uid}" -eq 0 ]]; then
    # If running as root, simply execute s6-overlay
    export USER="root"
    set -- /init_as_root "$@"
else
    # Otherwise, fix uid and gid, run s6-overlay as root and then drop
    # privileges back to the user
    export USER="${NON_ROOT_USER?}"
    set -- fixdockergid /init_as_root s6-setuidgid "${NON_ROOT_USER}" "$@"
fi

exec -- "$@"
