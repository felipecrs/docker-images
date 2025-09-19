#!/bin/bash

set -euxo pipefail

shopt -s inherit_errexit

readonly APT_GET="apt-get"
readonly APT_GET_INSTALL="${APT_GET} install -yq --no-install-recommends"
readonly CURL="curl -fsSL"

export DEBIANFRONTEND="noninteractive"

# install sudo and locales
${APT_GET} update
${APT_GET_INSTALL} \
    sudo \
    locales \
    tzdata

# setup locale
sed --in-place "/${LANG}/s/^# //g" /etc/locale.gen
locale-gen

## apt repositories
${APT_GET_INSTALL} ca-certificates curl

# shellcheck source=/dev/null
VERSION_CODENAME=$(. /etc/os-release && echo "${VERSION_CODENAME?}")
DPKG_ARCH=$(dpkg --print-architecture)
UNAME_ARCH=$(uname -m)
readonly VERSION_CODENAME DPKG_ARCH UNAME_ARCH

# git
${CURL} "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xF911AB184317630C59970973E363C90F8F1B6217" -o /etc/apt/keyrings/git-core-ppa.asc
echo "deb [arch=${DPKG_ARCH} signed-by=/etc/apt/keyrings/git-core-ppa.asc] http://ppa.launchpad.net/git-core/ppa/ubuntu ${VERSION_CODENAME} main" |
    tee /etc/apt/sources.list.d/git-core-ppa.list

# git-lfs
${CURL} https://packagecloud.io/github/git-lfs/gpgkey -o /etc/apt/keyrings/git-lfs.asc
echo "deb [arch=${DPKG_ARCH} signed-by=/etc/apt/keyrings/git-lfs.asc] https://packagecloud.io/github/git-lfs/ubuntu/ ${VERSION_CODENAME} main" |
    tee /etc/apt/sources.list.d/git-lfs.list

# docker
${CURL} https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
echo "deb [arch=${DPKG_ARCH} signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable" |
    tee /etc/apt/sources.list.d/docker.list

# install apt packages
${APT_GET} update

# renovate: datasource=deb depName=docker packageName=docker-ce extractVersion=^5:(?<version>[0-9]+\.[0-9]+\.[0-9]+)-.+$ registryUrl=https://download.docker.com/linux/ubuntu?suite=noble&components=stable&binaryArch=amd64
DOCKER_VERSION="28.4.0"
# renovate: datasource=deb depName=containerd packageName=containerd.io extractVersion=^(?<version>[0-9]+\.[0-9]+\.[0-9]+)-.+$ registryUrl=https://download.docker.com/linux/ubuntu?suite=noble&components=stable&binaryArch=amd64
CONTAINERD_VERSION="1.7.27"
# renovate: datasource=deb depName=docker-buildx packageName=docker-buildx-plugin extractVersion=^(?<version>[0-9]+\.[0-9]+\.[0-9]+)-.+$ registryUrl=https://download.docker.com/linux/ubuntu?suite=noble&components=stable&binaryArch=amd64
DOCKER_BUILDX_VERSION="0.28.0"
# renovate: datasource=deb depName=docker-compose packageName=docker-compose-plugin extractVersion=^(?<version>[0-9]+\.[0-9]+\.[0-9]+)-.+$ registryUrl=https://download.docker.com/linux/ubuntu?suite=noble&components=stable&binaryArch=amd64
DOCKER_COMPOSE_VERSION="2.39.4"

packages=(
    gnupg
    lsb-release
    build-essential
    git
    git-lfs
    tree
    jq
    parallel
    wget
    python3
    pipx
    rsync
    sshpass
    zip
    unzip
    time
    openssl
    openssh-server
    nano
    # from jenkins/docker-agent
    openssh-client
    patch
    netbase
    less
    fontconfig
    # required for docker in docker
    # https://github.com/moby/moby/blob/7d9d601e6de0020bc49678d9b48b5d56d8163558/project/PACKAGERS.md#runtime-dependencies
    iptables
    xz-utils
    pigz
    # network debugging
    net-tools
    iputils-ping
    traceroute
    dnsutils
    netcat-openbsd
    # docker
    "docker-ce=5:${DOCKER_VERSION}-*"
    "docker-ce-cli=5:${DOCKER_VERSION}-*"
    "containerd.io=${CONTAINERD_VERSION}-*"
    "docker-buildx-plugin=${DOCKER_BUILDX_VERSION}-*"
    "docker-compose-plugin=${DOCKER_COMPOSE_VERSION}-*"
)

${APT_GET_INSTALL} "${packages[@]}"

# setup docker-compose-switch (docker-compose v1 compatibility)
# renovate: datasource=github-releases depName=docker-compose-switch packageName=docker/compose-switch
DOCKER_COMPOSE_SWITCH_VERSION="1.0.5"
${CURL} "https://github.com/docker/compose-switch/releases/download/v${DOCKER_COMPOSE_SWITCH_VERSION}/docker-compose-linux-${DPKG_ARCH}" \
    -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

## dind
# https://github.com/docker-library/docker/blob/485fefe743baed5a2dd9e5d22b685c14eda4c61e/Dockerfile-dind.template#L47
addgroup --system dockremap
adduser --system --ingroup dockremap dockremap
echo 'dockremap:165536:65536' | tee -a /etc/subuid
echo 'dockremap:165536:65536' | tee -a /etc/subgid

# install dind hack
# https://github.com/moby/moby/commits/master/hack/dind
${CURL} "https://github.com/moby/moby/raw/v${DOCKER_VERSION}/hack/dind" \
    -o /usr/local/bin/dind
chmod +x /usr/local/bin/dind

# install retry
# renovate: datasource=github-releases depName=kadwanev/retry
RETRY_VERSION="1.0.2"
${CURL} "https://github.com/kadwanev/retry/releases/download/${RETRY_VERSION}/retry-${RETRY_VERSION}.tar.gz" |
    tar -C /usr/local/bin -xzf - retry

# install pkgx
# Using my fork until https://github.com/pkgxdev/pkgx/pull/1187 is merged and released
# renovate: datasource=github-releases depName=pkgx packageName=felipecrs/pkgx
PKGX_VERSION="2.8.0-felipecrs.0"
${CURL} "https://github.com/felipecrs/pkgx/releases/download/v${PKGX_VERSION}/pkgx-linux-${DPKG_ARCH}" \
    -o /usr/local/bin/pkgx.orig
chmod +x /usr/local/bin/pkgx.orig

# install pkgs
# https://github.com/felipecrs/dotfiles/commits/master/home/dot_local/bin/executable_pkgs
PKGS_REVISION="eaa40dff3a02579e12ab9d84a7b018c899553bae"
${CURL} "https://github.com/felipecrs/dotfiles/raw/${PKGS_REVISION}/home/dot_local/bin/executable_pkgs" \
    -o /usr/local/bin/pkgs
chmod +x /usr/local/bin/pkgs

# install s6-overlay
# renovate: datasource=github-releases depName=s6-overlay packageName=just-containers/s6-overlay versioning=loose
S6_OVERLAY_VERSION="3.2.1.0"
${CURL} "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz" |
    tar -C / -Jxpf -
${CURL} "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-${UNAME_ARCH}.tar.xz" |
    tar -C / -Jxpf -

# fix sshd not starting
mkdir -p /run/sshd

# prepare for the docker shim that waits for the container initialization
docker_path=$(command -v docker)
mv -f "${docker_path}" "${docker_path}.real"

# install docker-on-docker-shim
# renovate: datasource=github-releases depName=docker-on-docker-shim packageName=felipecrs/docker-on-docker-shim
DOND_SHIM_VERSION="0.7.1"
${CURL} "https://github.com/felipecrs/docker-on-docker-shim/raw/v${DOND_SHIM_VERSION}/dond" \
    -o /usr/local/bin/dond
chmod +x /usr/local/bin/dond

# install docker-scripts
# renovate: datasource=github-releases depName=felipecrs/docker-scripts
DOCKER_SCRIPTS_VERSION="0.2.0"
mkdir -p /opt/docker-scripts
${CURL} "https://github.com/felipecrs/docker-scripts/archive/v${DOCKER_SCRIPTS_VERSION}.tar.gz" |
    tar -C /opt/docker-scripts --strip-components=2 -xzf - --wildcards "docker-scripts-*/scripts"

# setup oh my bash, useful when debugging the container
${CURL} https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh |
    bash -s -- --prefix=/opt/oh-my-bash --unattended

# cleanup
shopt -s nullglob dotglob
rm -rf /tmp/* /var/cache/* /var/lib/apt/lists/*
