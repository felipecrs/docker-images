#!/bin/bash

exec -- /_entrypoint "$(id -u)" "$(id -g)" "$@"
