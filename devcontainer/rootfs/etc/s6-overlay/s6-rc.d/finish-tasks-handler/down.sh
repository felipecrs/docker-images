#!/bin/bash

set -eu

if [[ "${USER}" == "root" ]]; then
    cmd_prefix=()
else
    cmd_prefix=(s6-setuidgid "${USER}")
fi

# It is important not to exit with a non-zero code to avoid breaking the rest
# of the s6-overlay finalization process.
if timeout 120s "${cmd_prefix[@]}" /etc/s6-overlay/s6-rc.d/finish-tasks-handler/handle_finish_tasks.sh; then
    echo "[finish-tasks-handler] all tasks completed successfully." >&2
elif [[ $? -eq 124 ]]; then
    echo "[finish-tasks-handler] tasks timed out after 120 seconds, continuing with container finalization." >&2
else
    echo "[finish-tasks-handler] some task failed, continuing with container finalization." >&2
fi
