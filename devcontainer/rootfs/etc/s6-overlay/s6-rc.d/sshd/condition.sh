#!/bin/bash

set -eu

if [[ "${SSHD_ENABLED:-false}" == false ]]; then
    exit 1
fi

# Needed for situations like:
#   docker run --rm -v /ssh-command:/ssh-command ubuntu /ssh-command/get.sh
echo "${USER}" >/ssh-command/user
if [[ -n "${DOMAIN:-}" ]]; then
    echo "${DOMAIN}" >/ssh-command/domain
fi

exit 0
