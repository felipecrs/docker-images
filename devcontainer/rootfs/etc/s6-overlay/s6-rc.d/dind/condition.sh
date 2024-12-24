#!/bin/bash

set -eu

# if the docker socket is mounted, it means we are running in docker on docker
# mode and therefore we should not start the dind service
if mountpoint --quiet "/var/run/docker.sock"; then
    exit 1
fi

exit 0
