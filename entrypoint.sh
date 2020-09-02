#!/bin/bash

exec -- fixuid -q -- /_entrypoint "$(id -u)" "$(id -g)" "$@"
