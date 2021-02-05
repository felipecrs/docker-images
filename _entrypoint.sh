#!/bin/bash
#
# This script needs to be compiled with shc enabling the suid bit, so we have
# privileges to operate as root.
#
# Takes the first two arguments as UID and GID, executes s6-overlay as root,
# and drop the privileges to the regular user provided by the UID and GID args.
#

set -e

readonly _UID=${1?"UID is mandatory. Usage: $0 UID GID"}
readonly _GID=${2?"GID is mandatory. Usage: $0 UID GID"}
shift
shift

# S6_CMD_WAIT_FOR_SERVICES=1: wait for services to be running before executing CMD
# /init: s6-overlay
# setpriv: drop privileges
S6_CMD_WAIT_FOR_SERVICES=1 exec -- /init setpriv "--reuid=$_UID" "--regid=$_GID" --init-groups -- "$@"
