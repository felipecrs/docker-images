#!/usr/bin/with-contenv bash
# shellcheck shell=bash

set -euo pipefail

# Ensure bash will not leave any background processes running
trap 'kill 0' EXIT

echo "Waiting for dind to be stopped by s6-svc..." >&2
s6-svwait -D -t 15000 /var/run/s6/services/dind || true

echo "Starting dind again..." >&2
dind dockerd &>/dev/null &

# Wait until dind is ready
counter=0
until docker ps &>/dev/null; do
    echo "Waiting for dind to be up..." >&2
    sleep 1

    counter=$((counter + 1))
    if [[ $counter -gt 15 ]]; then
        echo "dind failed to start" >&2
        exit 1
    fi
done

echo "Cleaning up..." >&2

# Best effort to remove the kind cluster, perhaps not needed
echo "Attempting to delete kind clusters..." >&2
kind delete cluster || true
kind get clusters | xargs --max-lines=1 --no-run-if-empty -- kind delete cluster --name || true

echo "Removing all containers..." >&2
docker ps --all --quiet | xargs --no-run-if-empty -- docker rm --force
