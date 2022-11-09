#!/bin/bash
#
# This script needs to be compiled with shc enabling the suid bit, so we have
# privileges to operate as root.
#
# /init: s6-overlay
# /s6-setuidgid: drop privileges to the regular user
exec -- /init s6-setuidgid "${USER?}" "$@"
