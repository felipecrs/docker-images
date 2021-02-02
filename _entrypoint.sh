#!/bin/bash

readonly _UID=${1?"UID is mandatory. Usage: $0 UID GID"}
readonly _GID=${2?"GID is mandatory. Usage: $0 UID GID"}
shift
shift

S6_CMD_WAIT_FOR_SERVICES=1 exec -- /init setpriv "--reuid=$_UID" "--regid=$_GID" --init-groups -- "$@"
