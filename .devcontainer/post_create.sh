#!/bin/bash

set -eu

# quiets the output a little
export CI=true

# renovate: datasource=node-version depName=node
node_version="22.19.0"
# renovate: datasource=github-releases depName=npm packageName=npm/cli
npm_version="11.6.0"
# renovate: datasource=github-releases depName=k3d packageName=k3d-io/k3d
k3d_version="5.8.3"
# renovate: datasource=github-releases depName=helmfile packageName=helmfile/helmfile
helmfile_version="1.1.6"
# renovate: datasource=github-releases depName=werf packageName=werf/werf
werf_version="2.47.4"
# renovate: datasource=github-tags depName=kubectl packageName=kubernetes/kubectl extractVersion=^kubernetes-(?<version>.*)$
kubectl_version="1.34.1"
# renovate: datasource=github-releases depName=yq packageName=mikefarah/yq
yq_version="4.47.2"
# renovate: datasource=npm depName=@devcontainers/cli
devcontainers_version="0.80.1"

# hadolint and act are not part of any pipeline, there's no point in updating
# them automatically

set -x

pkgx install \
    "node@${node_version}" \
    "npm@${npm_version}" \
    "k3d@${k3d_version}" \
    "helmfile@${helmfile_version}" \
    "werf@${werf_version}" \
    "yq@${yq_version}" \
    "kubectl@${kubectl_version}" \
    hadolint@2 \
    act@0.2

node --version
npm --version

npm install --global "@devcontainers/cli@${devcontainers_version}"
devcontainer --version

k3d version
kubectl version --client
werf version
werf helm version
yq --version
helmfile version
