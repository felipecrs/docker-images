#!/bin/bash

set -eu

touch /tmp/container_initialized

exec -- "$@"
