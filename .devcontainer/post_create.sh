#!/bin/bash

set -ex

# quiets the output a little
export CI=true

pkgx install \
    node@20 \
    npm@10 \
    k3d@5 \
    helmfile@0.162 \
    werf@1 \
    kubectl@1 \
    hadolint@2 \
    act@0.2

node --version
npm --version

npm install --global @devcontainers/cli@0.57
devcontainer --version
