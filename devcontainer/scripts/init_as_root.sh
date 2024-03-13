#!/bin/bash
#
# This script needs to be compiled with shc enabling the suid bit, so even
# though the container starts as a non-root user, it operates as if it was
# ran as root.
#
# /init: s6-overlay

exec /init "$@"
