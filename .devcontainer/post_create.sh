#!/bin/bash

set -ex

# quiets the output a little
export CI=true

pkgx install \
    node@22 \
    npm@11 \
    k3d@5 \
    helmfile@0.169 \
    werf@2 \
    yq@4 \
    kubectl@1 \
    hadolint@2 \
    act@0.2

node --version
npm --version

# renovate: datasource=github-tags depName=devcontainers/cli
devcontainers_version="0.72.0"
npm install --global "@devcontainers/cli@${devcontainers_version}"
devcontainer --version

k3d version
kubectl version --client
werf version
werf helm version
yq --version
helmfile version
