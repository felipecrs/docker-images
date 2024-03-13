#!/bin/bash

set -ex

pkgx install k3d@5 helmfile@0.162 werf@1 kubectl@1

if [[ "${CI:-false}" == false ]]; then
    pkgx install npm@10 node@20 hadolint@2 act@0.2
fi

npm install --global @devcontainers/cli@0.57
