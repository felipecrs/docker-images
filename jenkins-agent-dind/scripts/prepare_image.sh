#!/bin/bash

set -euxo pipefail

shopt -s inherit_errexit

mkdir -p "${AGENT_WORKDIR?}"
chown -R "${USER?}:${USER}" "${AGENT_WORKDIR}"

new_json=$(jq --arg d "${AGENT_WORKDIR}/docker" '.["data-root"] = $d' /etc/docker/daemon.json)
echo "${new_json}" | tee /etc/docker/daemon.json

# set fixuid to update AGENT_WORKDIR permissions
tee -a /etc/fixuid/config.yml <<EOF
paths:
    - /
    - '${AGENT_WORKDIR}'
EOF
