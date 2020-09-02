#!/bin/sh

UID=${1}
GID=${2}
shift
shift

S6_CMD_WAIT_FOR_SERVICES=1 exec /init setpriv "--reuid=$UID" "--regid=$GID" --init-groups -- "$@"
