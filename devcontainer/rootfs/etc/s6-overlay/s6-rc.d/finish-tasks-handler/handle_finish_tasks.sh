#!/bin/bash

set -eu

shopt -s nullglob

for task in /finish-tasks.d/*; do
    if [[ -x "${task}" ]]; then
        echo "[finish-tasks-handler] running task ${task}..." >&2

        if "${task}"; then
            echo "[finish-tasks-handler] task ${task} ran successfully." >&2
        else
            exit_code="$?"
            echo "[finish-tasks-handler] task ${task} failed with exit code ${exit_code}, stopping handling further tasks." >&2
            exit "${exit_code}"
        fi
    else
        echo "[finish-tasks-handler] skipping ${task} as it is not executable." >&2
    fi
done
