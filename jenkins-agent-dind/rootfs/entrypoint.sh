#!/bin/bash
#
# This entrypoint first decides what is the best CMD to run by default when
# none is provided based on some conditions.
#
# Then, it ensures s6-overlay is always executed as root, also ensuring that
# when the container is being executed as a non-root user, fixdockergid is
# called and CMD is executed as the non-root user.

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
    set -- /init "$@"
else
    # Otherwise, fix uid and gid, run s6-overlay as root and then drop
    # privileges back to the user
    export USER="${NON_ROOT_USER?}"
    set -- fixdockergid /init_as_root s6-setuidgid "${NON_ROOT_USER}" "$@"
fi

exec -- "$@"
