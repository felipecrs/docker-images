#!/bin/bash

export SKIP_CONTAINER_INITIALIZATION_CHECK="true"
exec docker version &>/dev/null
