#!/bin/bash
#
# This entrypoint first decides what is the best CMD to run by default when
# none is provided based on some conditions.
#
# Then, it ensures s6-overlay is always executed as root, also ensuring that
# when the container is being executed as a non-root user, fixdockergid is
# called and CMD is executed as the non-root user.

set -eu

shopt -s nullglob
for file in /entrypoint.d/*; do
    # shellcheck disable=SC1090
    source "${file}"
done

uid="$(id -u)"
if [[ "${uid}" -eq 0 ]]; then
    # If running as root, simply execute s6-overlay
    export USER="root"
    export HOME="/root"
    set -- /init "$@"
else
    # Otherwise, fix uid and gid, run s6-overlay as root and then drop
    # privileges back to the user
    set -- fixdockergid /init_as_root s6-setuidgid "${USER}" "$@"
fi

exec -- "$@"
