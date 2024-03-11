#!/bin/bash
#
# This script runs as S6_STAGE2_HOOK and is responsible for selecting which
# services to run based on some conditions.
#
# Refs: https://github.com/just-containers/s6-overlay/issues/394#issuecomment-1988361471

set -eu

shopt -s nullglob
for service_dir in "/etc/s6-overlay/s6-rc.d/"*; do
    if [[ -f "${service_dir}/condition.sh" ]]; then
        if "${service_dir}/condition.sh"; then
            service_name="$(basename "${service_dir}")"
            touch "/etc/s6-overlay/s6-rc.d/user/contents.d/${service_name}"
        fi
    fi
done
