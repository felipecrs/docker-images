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
${APT_GET_INSTALL} \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

VERSION_CODENAME=$(lsb_release -cs)
DPKG_ARCH=$(dpkg --print-architecture)
UNAME_ARCH=$(uname -m)
readonly VERSION_CODENAME DPKG_ARCH UNAME_ARCH

# git
${CURL} "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xE1DD270288B4E6030699E45FA1715D88E1DF1F24" |
    gpg --dearmor -o /etc/apt/keyrings/git-core-ppa.gpg
echo "deb [arch=${DPKG_ARCH} signed-by=/etc/apt/keyrings/git-core-ppa.gpg] http://ppa.launchpad.net/git-core/ppa/ubuntu ${VERSION_CODENAME} main" |
    tee /etc/apt/sources.list.d/git-core-ppa.list

# git-lfs
${CURL} https://packagecloud.io/github/git-lfs/gpgkey |
    gpg --dearmor -o /etc/apt/keyrings/git-lfs.gpg
echo "deb [arch=${DPKG_ARCH} signed-by=/etc/apt/keyrings/git-lfs.gpg] https://packagecloud.io/github/git-lfs/ubuntu/ ${VERSION_CODENAME} main" |
    tee /etc/apt/sources.list.d/git-lfs.list

# docker
${CURL} https://download.docker.com/linux/ubuntu/gpg |
    gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=${DPKG_ARCH} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable" |
    tee /etc/apt/sources.list.d/docker.list

# install apt packages
${APT_GET} update

# renovate: datasource=github-releases depName=docker packageName=moby/moby
DOCKER_VERSION="27.1.1"

packages=(
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
    # https://github.com/moby/moby/blob/97a5435d33f644e7cfc0285e483306f2ea410710/project/PACKAGERS.md#runtime-dependencies
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
    containerd.io
    docker-buildx-plugin
    docker-compose-plugin
)

${APT_GET_INSTALL} "${packages[@]}"

# setup docker-switch (docker-compose v1 compatibility)
# renovate: datasource=github-releases depName=docker/compose-switch
DOCKER_COMPOSE_SWITCH_VERSION="1.0.5"
${CURL} "https://github.com/docker/compose-switch/releases/download/v${DOCKER_COMPOSE_SWITCH_VERSION}/docker-compose-linux-${DPKG_ARCH}" \
    -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

## dind
# https://github.com/docker-library/docker/blob/9ee39bafc3844108938e3469b262738a5b0e804b/Dockerfile-dind.template#L47
addgroup --system dockremap
adduser --system --ingroup dockremap dockremap
echo 'dockremap:165536:65536' | tee -a /etc/subuid
echo 'dockremap:165536:65536' | tee -a /etc/subgid

# install dind hack
# https://github.com/moby/moby/commits/master/hack/dind
DIND_COMMIT="65cfcc28ab37cb75e1560e4b4738719c07c6618e"
${CURL} "https://github.com/moby/moby/raw/${DIND_COMMIT}/hack/dind" \
    -o /usr/local/bin/dind
chmod +x /usr/local/bin/dind

# install retry
# renovate: datasource=github-releases depName=kadwanev/retry
RETRY_VERSION="1.0.2"
${CURL} "https://github.com/kadwanev/retry/releases/download/${RETRY_VERSION}/retry-${RETRY_VERSION}.tar.gz" |
    tar -C /usr/local/bin -xzf - retry

# install pkgx
# renovate: datasource=github-releases depName=felipecrs/pkgx versioning=loose
PKGX_VERSION="1.2.0-felipecrs.2"
${CURL} "https://github.com/felipecrs/pkgx/releases/download/v${PKGX_VERSION}/pkgx-${PKGX_VERSION}+linux+${UNAME_ARCH//_/-}.tar.xz" |
    tar -C /usr/local/bin -xJf - pkgx

# install s6-overlay
# renovate: datasource=github-releases depName=s6-overlay packageName=just-containers/s6-overlay
S6_OVERLAY_VERSION="3.1.6.2"
${CURL} "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz" |
    tar -C / -Jxpf -
${CURL} "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-${UNAME_ARCH}.tar.xz" |
    tar -C / -Jxpf -

# fix sshd not starting
mkdir -p /run/sshd

# install docker-on-docker-shim
# renovate: datasource=github-releases depName=felipecrs/docker-on-docker-shim
DOND_SHIM_VERSION="0.6.1"
${CURL} "https://github.com/felipecrs/docker-on-docker-shim/raw/v${DOND_SHIM_VERSION}/dond" \
    -o /usr/local/bin/dond
chmod +x /usr/local/bin/dond

# setup oh my bash, useful when debugging the container
${CURL} https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh |
    bash -s -- --prefix=/opt/oh-my-bash --unattended

# cleanup
shopt -s nullglob dotglob
rm -rf /tmp/* /var/cache/* /var/lib/apt/lists/*
