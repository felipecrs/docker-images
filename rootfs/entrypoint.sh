#!/bin/bash
#
# This entrypoint executes _entrypoint.sh, which operates as root to execute s6-overlay,
# drops the permissions to the regular user which started the container and executes CMD.
#

exec -- /_entrypoint "$(id -u)" "$(id -g)" "$@"
