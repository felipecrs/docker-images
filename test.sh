#!/bin/bash

set -eux

shopt -s nullglob

for test in */test.sh; do
    "${test}"
done
