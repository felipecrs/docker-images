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
sed --in-place '/en_US.UTF-8/s/^# //g' /etc/locale.gen
locale-gen

# setup sudo
echo "${NON_ROOT_USER} ALL=(ALL) NOPASSWD:ALL" | tee "/etc/sudoers.d/${NON_ROOT_USER}"
# dismiss welcome message
sudo -u "${NON_ROOT_USER}" true

# ensure jenkins-agent directory exists
mkdir -p "${AGENT_WORKDIR}"
# and is owned by the jenkins user
chown -R "${NON_ROOT_USER}:${NON_ROOT_USER}" "${AGENT_WORKDIR}"

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

# adoptium openjdk
${CURL} https://packages.adoptium.net/artifactory/api/gpg/key/public |
    gpg --dearmor -o /etc/apt/keyrings/adoptium.gpg
# shellcheck source=/dev/null
echo "deb [arch=${APT_ARCH} signed-by=/etc/apt/keyrings/adoptium.gpg] https://packages.adoptium.net/artifactory/deb ${VERSION_CODENAME} main" |
    tee /etc/apt/sources.list.d/adoptium.list

# kubernetes
version="1.29"
${CURL} "https://pkgs.k8s.io/core:/stable:/v${version}/deb/Release.key" |
    gpg --dearmor -o /etc/apt/keyrings/kubernetes.gpg
echo "deb [arch=${APT_ARCH} signed-by=/etc/apt/keyrings/kubernetes.gpg] https://pkgs.k8s.io/core:/stable:/v${version}/deb/ /" |
    tee /etc/apt/sources.list.d/kubernetes.list

# yarn
${CURL} https://dl.yarnpkg.com/debian/pubkey.gpg |
    gpg --dearmor -o /etc/apt/keyrings/yarn.gpg
echo "deb [arch=${APT_ARCH} signed-by=/etc/apt/keyrings/yarn.gpg] https://dl.yarnpkg.com/debian/ stable main" |
    tee /etc/apt/sources.list.d/yarn.list

# jfrog
${CURL} https://releases.jfrog.io/artifactory/api/gpg/key/public |
    gpg --dearmor -o /etc/apt/keyrings/jfrog.gpg
echo "deb [arch=${APT_ARCH} signed-by=/etc/apt/keyrings/jfrog.gpg] https://releases.jfrog.io/artifactory/jfrog-debs xenial contrib" |
    tee /etc/apt/sources.list.d/jfrog.list

# git
${CURL} "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xE1DD270288B4E6030699E45FA1715D88E1DF1F24" |
    gpg --dearmor -o /etc/apt/keyrings/git-core-ppa.gpg
echo "deb [arch=${APT_ARCH} signed-by=/etc/apt/keyrings/git-core-ppa.gpg] http://ppa.launchpad.net/git-core/ppa/ubuntu ${VERSION_CODENAME} main" |
    tee /etc/apt/sources.list.d/git-core-ppa.list

# yq
${CURL} "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x9A2D61F6BB03CED7522B8E7D6657DBE0CC86BB64" |
    gpg --dearmor -o /etc/apt/keyrings/rmescandon-yq.gpg
echo "deb [arch=${APT_ARCH} signed-by=/etc/apt/keyrings/rmescandon-yq.gpg] http://ppa.launchpad.net/rmescandon/yq/ubuntu ${VERSION_CODENAME} main" |
    tee /etc/apt/sources.list.d/rmescandon-yq.list

# git-lfs
${CURL} https://packagecloud.io/github/git-lfs/gpgkey |
    gpg --dearmor -o /etc/apt/keyrings/git-lfs.gpg
echo "deb [arch=${APT_ARCH} signed-by=/etc/apt/keyrings/git-lfs.gpg] https://packagecloud.io/github/git-lfs/ubuntu/ ${VERSION_CODENAME} main" |
    tee /etc/apt/sources.list.d/git-lfs.list

# nodejs
version="18"
${CURL} https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key |
    gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
chmod a+r /etc/apt/keyrings/nodesource.gpg
echo "deb [arch=${APT_ARCH} signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${version}.x nodistro main" |
    tee /etc/apt/sources.list.d/nodesource.list

# docker
${CURL} https://download.docker.com/linux/ubuntu/gpg |
    gpg --dearmor -o /etc/apt/keyrings/docker.gpg
# shellcheck source=/dev/null
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
    yq
    parallel
    rsync
    sshpass
    python3-pip
    temurin-11-jdk
    nodejs
    yarn
    kubectl
    jfrog-cli
    jfrog-cli-v2-jf
    shellcheck
    maven
    ant
    ant-contrib
    zip
    unzip
    time
    # from jenkins/docker-agent
    openssh-client
    patch
    netbase
    less
    fontconfig
    # required for docker in docker
    iptables
    xz-utils
    btrfs-progs
    # network
    net-tools
    iputils-ping
    traceroute
    dnsutils
    netcat
    openssh-server
    # docker
    docker-ce
    docker-ce-cli
    containerd.io
    docker-buildx-plugin
    docker-compose-plugin
)
${APT_GET_INSTALL} "${packages[@]}"

usermod -aG docker "${NON_ROOT_USER}"

version=$(basename "$(${CURL} -o /dev/null -w "%{url_effective}" https://github.com/docker/compose-switch/releases/latest)")
${CURL} -o /usr/local/bin/docker-compose "https://github.com/docker/compose-switch/releases/download/${version}/docker-compose-$(uname -s)-amd64"
chmod +x /usr/local/bin/docker-compose

## dind
# set up subuid/subgid so that "--userns-remap=default" works out-of-the-box
addgroup --system dockremap
adduser --system --ingroup dockremap dockremap
echo 'dockremap:165536:65536' | tee -a /etc/subuid
echo 'dockremap:165536:65536' | tee -a /etc/subgid
# install dind hack
# https://github.com/moby/moby/commits/master/hack/dind
version="d58df1fc6c866447ce2cd129af10e5b507705624"
${CURL} -o /usr/local/bin/dind "https://raw.githubusercontent.com/moby/moby/${version}/hack/dind"
chmod +x /usr/local/bin/dind

# install jenkins-agent
# the same version as being used in the official agent image
docker_agent_version=$(basename "$(${CURL} -o /dev/null -w "%{url_effective}" https://github.com/jenkinsci/docker-agent/releases/latest)")
version=$(echo "${docker_agent_version}" | cut -d'-' -f1)
mkdir -p /usr/share/jenkins
chmod 0755 /usr/share/jenkins
${CURL} -o /usr/share/jenkins/agent.jar "https://repo.jenkins-ci.org/public/org/jenkins-ci/main/remoting/${version}/remoting-${version}.jar"
chmod +x /usr/share/jenkins/agent.jar
ln -sf /usr/share/jenkins/agent.jar /usr/share/jenkins/slave.jar

# install jenkins-agent wrapper from inbound-agent
version="${docker_agent_version}"
unset docker_agent_version
${CURL} -o /usr/local/bin/jenkins-agent "https://github.com/jenkinsci/docker-agent/raw/${version}/jenkins-agent"
chmod +x /usr/local/bin/jenkins-agent
ln -sf /usr/local/bin/jenkins-agent /usr/local/bin/jenkins-slave

## pip
# setup python and pip aliases
update-alternatives --install /usr/bin/python python /usr/bin/python3 1
update-alternatives --install /usr/bin/pip pip /usr/bin/pip3 1
# upgrade pip
pip install --no-cache-dir --upgrade pip
# install pip packages
pip install --no-cache-dir ansible

## npm
# upgrade npm
npm install -g npm@latest
# allow npm --global to run as non-root
mkdir "${NPM_PREFIX}"
npm config set prefix "${NPM_PREFIX}"
# install npm packages
npm install --global \
    semver \
    bats
# clean npm cache
npm cache clean --force

## miscellaneous
# install kind
version=$(basename "$(${CURL} -o /dev/null -w "%{url_effective}" https://github.com/kubernetes-sigs/kind/releases/latest)")
${CURL} -o /usr/local/bin/kind "https://github.com/kubernetes-sigs/kind/releases/download/${version}/kind-$(uname)-amd64"
chmod +x /usr/local/bin/kind

# install hadolint
version=$(basename "$(${CURL} -o /dev/null -w "%{url_effective}" https://github.com/hadolint/hadolint/releases/latest)")
${CURL} -o /usr/local/bin/hadolint "https://github.com/hadolint/hadolint/releases/download/${version}/hadolint-Linux-x86_64"
chmod +x /usr/local/bin/hadolint

# install helm 3
${CURL} https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash -

# install skopeo
# https://github.com/felipecrs/skopeo-bin/releases/download/v1.14.2/skopeo.linux-amd64
version="$(basename "$(${CURL} -o /dev/null -w "%{url_effective}" https://github.com/felipecrs/skopeo-bin/releases/latest)")"
${CURL} -o /usr/local/bin/skopeo "https://github.com/felipecrs/skopeo-bin/releases/download/${version}/skopeo.linux-amd64"
chmod +x /usr/local/bin/skopeo

# install retry
version=$(basename "$(${CURL} -o /dev/null -w "%{url_effective}" "https://github.com/kadwanev/retry/releases/latest")")
${CURL} "https://github.com/kadwanev/retry/releases/download/${version}/retry-${version}.tar.gz" |
    tar -C /usr/local/bin -xzf -

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
