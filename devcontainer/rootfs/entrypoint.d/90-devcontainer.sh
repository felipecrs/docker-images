# shellcheck shell=bash

if [[ $# -eq 0 ]]; then
    # If attached to a terminal, start a shell
    if [[ -t 0 ]]; then
        set -- bash
    # Otherwise, just keep the container running
    else
        set -- sleep infinity
    fi
fi
