#!/bin/bash

set -euxo pipefail

shopt -s inherit_errexit

readonly CURL="curl -fsSL"

# create non-root user
groupadd -g "${NON_ROOT_UID?}" "${NON_ROOT_USER?}"
useradd -l -c "Jenkins user" -d "${NON_ROOT_HOME?}" -u "${NON_ROOT_UID}" -g "${NON_ROOT_UID}" -m "${NON_ROOT_USER}" -s /bin/bash -p ""

# setup sudo
echo "${NON_ROOT_USER} ALL=(ALL) NOPASSWD:ALL" | tee "/etc/sudoers.d/${NON_ROOT_USER}"
# dismiss welcome message
sudo -u "${NON_ROOT_USER}" true

# setup docker
usermod -aG docker "${NON_ROOT_USER}"

# install fixdockergid
# renovate: datasource=github-releases depName=felipecrs/fixdockergid
FIXDOCKERGID_VERSION="0.7.1"
${CURL} "https://github.com/felipecrs/fixdockergid/raw/v${FIXDOCKERGID_VERSION}/install.sh" |
    FIXDOCKERGID_VERSION="${FIXDOCKERGID_VERSION}" USERNAME="${NON_ROOT_USER}" sh -

# oh-my-bash
cp -f /opt/oh-my-bash/share/oh-my-bash/bashrc "${NON_ROOT_HOME}/.bashrc"

# Set nano as default editor when running interactive shell
printf '\n%s\n' 'export EDITOR="nano"' | tee -a "${NON_ROOT_HOME}/.bashrc"

# cleanup
shopt -s nullglob dotglob
rm -rf /tmp/* /var/cache/* /var/lib/apt/lists/*
