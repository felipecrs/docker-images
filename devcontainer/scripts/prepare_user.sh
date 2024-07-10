#!/bin/bash

set -euxo pipefail

shopt -s inherit_errexit

readonly CURL="curl -fsSL"

# remove user if exists (ubuntu:noble onwards)
if getent passwd ubuntu >/dev/null; then
    userdel -r ubuntu
fi

# create non-root user
groupadd -g "${USER_ID?}" "${USER?}"
useradd -l -d "${HOME?}" -u "${USER_ID}" -g "${USER_ID}" -m "${USER}" -s /bin/bash -p ""

# setup sudo
echo "${USER} ALL=(ALL) NOPASSWD:ALL" | tee "/etc/sudoers.d/${USER}"
# dismiss welcome message
sudo -u "${USER}" true

# setup docker
usermod -aG docker "${USER}"

# install fixdockergid
# renovate: datasource=github-releases depName=felipecrs/fixdockergid
FIXDOCKERGID_VERSION="0.7.1"
${CURL} "https://github.com/felipecrs/fixdockergid/raw/v${FIXDOCKERGID_VERSION}/install.sh" |
    FIXDOCKERGID_VERSION="${FIXDOCKERGID_VERSION}" USERNAME="${USER}" sh -

# oh-my-bash
cp -f /opt/oh-my-bash/share/oh-my-bash/bashrc "${HOME}/.bashrc"

# Set nano as default editor when running interactive shell
printf '\n%s\n' 'export EDITOR="nano"' | tee -a "${HOME}/.bashrc"

chown "${USER}:${USER}" "${HOME}/.bashrc"

# install volta stub (will be fully downloaded when it is used for the first time)
# renovate: datasource=github-releases depName=volta packageName=volta-cli/volta
VOLTA_VERSION="1.1.1"
sudo -u "${USER}" pkgx install "volta.sh@${VOLTA_VERSION}"

# cleanup
sudo -u "${USER}" rm -rf "${HOME}/.pkgx" "${HOME}/.cache/pkgx" "${HOME}/.local/share/pkgx"

shopt -s nullglob dotglob
rm -rf /tmp/* /var/cache/* /var/lib/apt/lists/*
