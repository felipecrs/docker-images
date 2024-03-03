#!/bin/bash

set -euxo pipefail

shopt -s inherit_errexit

readonly APT_GET="apt-get"
readonly APT_GET_INSTALL="${APT_GET} install -yq --no-install-recommends"
readonly CURL="curl -fsSL"

export DEBIANFRONTEND="noninteractive"

# create non-root user
groupadd -g "${NON_ROOT_UID}" "${NON_ROOT_USER}"
useradd -l -c "Jenkins user" -d "${NON_ROOT_HOME}" -u "${NON_ROOT_UID}" -g "${NON_ROOT_UID}" -m "${NON_ROOT_USER}" -s /bin/bash -p ""

# install sudo and locales
${APT_GET} update
${APT_GET_INSTALL} \
    sudo \
    locales \
    tzdata

# setup locale
sed --in-place "/${LANG}/s/^# //g" /etc/locale.gen
locale-gen

# setup sudo
echo "${NON_ROOT_USER} ALL=(ALL) NOPASSWD:ALL" | tee "/etc/sudoers.d/${NON_ROOT_USER}"
# dismiss welcome message
sudo -u "${NON_ROOT_USER}" true

# ensure jenkins-agent directory exists
mkdir -p "${AGENT_WORKDIR}"
chown -R "${NON_ROOT_USER}:${NON_ROOT_USER}" "${AGENT_WORKDIR}"
chmod 755 "${AGENT_WORKDIR}"

## apt repositories
${APT_GET_INSTALL} \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

mkdir -p /etc/apt/keyrings
chmod 755 /etc/apt/keyrings

VERSION_CODENAME=$(lsb_release -cs)
APT_ARCH=$(dpkg --print-architecture)
readonly VERSION_CODENAME APT_ARCH

# git
${CURL} "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xE1DD270288B4E6030699E45FA1715D88E1DF1F24" |
    gpg --dearmor -o /etc/apt/keyrings/git-core-ppa.gpg
echo "deb [arch=${APT_ARCH} signed-by=/etc/apt/keyrings/git-core-ppa.gpg] http://ppa.launchpad.net/git-core/ppa/ubuntu ${VERSION_CODENAME} main" |
    tee /etc/apt/sources.list.d/git-core-ppa.list

# git-lfs
${CURL} https://packagecloud.io/github/git-lfs/gpgkey |
    gpg --dearmor -o /etc/apt/keyrings/git-lfs.gpg
echo "deb [arch=${APT_ARCH} signed-by=/etc/apt/keyrings/git-lfs.gpg] https://packagecloud.io/github/git-lfs/ubuntu/ ${VERSION_CODENAME} main" |
    tee /etc/apt/sources.list.d/git-lfs.list

# docker
${CURL} https://download.docker.com/linux/ubuntu/gpg |
    gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=${APT_ARCH} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable" |
    tee /etc/apt/sources.list.d/docker.list

# install apt packages
${APT_GET} update
packages=(
    build-essential
    git
    git-lfs
    tree
    jq
    parallel
    rsync
    sshpass
    zip
    unzip
    time
    openssl
    openssh-server
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
    netcat
    # docker
    docker-ce
    docker-ce-cli
    containerd.io
    docker-buildx-plugin
    docker-compose-plugin
)
${APT_GET_INSTALL} "${packages[@]}"

# setup docker
usermod -aG docker "${NON_ROOT_USER}"

# setup docker-switch (docker-compose v1 compatibility)
version=$(basename "$(${CURL} -o /dev/null -w "%{url_effective}" https://github.com/docker/compose-switch/releases/latest)")
${CURL} -o /usr/local/bin/docker-compose "https://github.com/docker/compose-switch/releases/download/${version}/docker-compose-$(uname -s)-amd64"
chmod +x /usr/local/bin/docker-compose

## dind
# https://github.com/docker-library/docker/blob/9ee39bafc3844108938e3469b262738a5b0e804b/Dockerfile-dind.template#L47
addgroup --system dockremap
adduser --system --ingroup dockremap dockremap
echo 'dockremap:165536:65536' | tee -a /etc/subuid
echo 'dockremap:165536:65536' | tee -a /etc/subgid
# install dind hack
# https://github.com/moby/moby/commits/master/hack/dind
version="65cfcc28ab37cb75e1560e4b4738719c07c6618e"
${CURL} -o /usr/local/bin/dind "https://raw.githubusercontent.com/moby/moby/${version}/hack/dind"
chmod +x /usr/local/bin/dind

# install retry
version=$(basename "$(${CURL} -o /dev/null -w "%{url_effective}" "https://github.com/kadwanev/retry/releases/latest")")
${CURL} "https://github.com/kadwanev/retry/releases/download/${version}/retry-${version}.tar.gz" |
    tar -C /usr/local/bin -xzf - retry

# install pkgx
version=$(basename "$(${CURL} -o /dev/null -w "%{url_effective}" "https://github.com/pkgxdev/pkgx/releases/latest")" | sed 's/^v//')
${CURL} "https://github.com/pkgxdev/pkgx/releases/download/v${version}/pkgx-${version}+linux+$(uname -m | sed 's/_/-/g').tar.xz" |
    tar -C /usr/local/bin -xJf - pkgx

# install s6-overlay
version="3.1.6.2"
${CURL} "https://github.com/just-containers/s6-overlay/releases/download/v${version}/s6-overlay-noarch.tar.xz" |
    tar -C / -Jxpf -
${CURL} "https://github.com/just-containers/s6-overlay/releases/download/v${version}/s6-overlay-x86_64.tar.xz" |
    tar -C / -Jxpf -

# fix sshd not starting
mkdir -p /run/sshd

# install fixuid
# https://github.com/boxboat/fixuid/releases
version="0.6.0"
curl -fsSL "https://github.com/boxboat/fixuid/releases/download/v${version}/fixuid-${version}-linux-amd64.tar.gz" |
    tar -C /usr/local/bin -xzf -
chown root:root /usr/local/bin/fixuid
chmod 4755 /usr/local/bin/fixuid
mkdir -p /etc/fixuid
printf '%s\n' "user: ${NON_ROOT_USER}" "group: ${NON_ROOT_USER}" "paths:" "  - /" "  - ${AGENT_WORKDIR}" |
    tee /etc/fixuid/config.yml

# cleanup and reduce image size
shopt -s nullglob dotglob
rm -rf /tmp/* /var/cache/* /usr/share/doc/* /usr/share/man/* /var/lib/apt/lists/*
