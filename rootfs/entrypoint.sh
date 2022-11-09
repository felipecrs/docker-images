#!/bin/bash
#
# This entrypoint first executes fixuid to fix the uid and gid of the user
# within the to match the user which the container was executed as. Then,
# executes init_as_root.sh, which operates as root to execute s6-overlay, drops
# the permissions to the regular user which started the container and executes
# the passed in CMD.

exec -- fixuid -q -- /init_as_root "$@"
