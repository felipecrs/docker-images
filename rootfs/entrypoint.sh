#!/bin/bash
#
# This entrypoint first executes fixuid to fix the uid and gid of the user
# within the to match the user which the container was executed as. Then,
# executes init_as_root.sh, which operates as root to execute s6-overlay, drops
# the permissions to the regular user which started the container and executes
# the passed in CMD.

set -eu

uid="$(id -u)"
if [[ "${uid}" -eq 0 ]]; then
    # If running as root, simply execute s6-overlay
    export USER="root"
    cmd=(/init_as_root)
else
    # Otherwise, fix uid and gid, run s6-overlay as root and then drop
    # privileges back to the user
    export USER="${NON_ROOT_USER}"
    cmd=(fixdockergid /init_as_root s6-setuidgid "${NON_ROOT_USER}")
fi

exec -- "${cmd[@]}" "$@"
