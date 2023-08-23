FROM buildpack-deps:focal AS base

# set bash as the default interpreter for the build with:
# -e: exits on error, so we can use colon as line separator
# -u: throw error on variable unset
# -o pipefail: exits on first command failed in pipe
SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]


FROM ghcr.io/felipecrs/skopeo-bin:latest AS skopeo-bin

# Build the init_as_root
FROM base AS init_as_root

# Install shc
RUN apt-get update; \
    apt-get install -y shc; \
    rm -rf /var/lib/apt/lists/*

COPY init_as_root.sh /
RUN shc -S -r -f /init_as_root.sh -o /init_as_root; \
    chown root:root /init_as_root; \
    chmod 4755 /init_as_root


FROM scratch AS rootfs

COPY --from=init_as_root /init_as_root /
COPY rootfs /
COPY --from=skopeo-bin / /usr/local/bin/


FROM base

ENV NON_ROOT_USER=jenkins
ARG HOME="/home/${NON_ROOT_USER}"

# build helpers
ARG DEBIANFRONTEND="noninteractive"
ARG APT_GET="apt-get"
ARG APT_GET_INSTALL="${APT_GET} install -yq --no-install-recommends"
ARG SUDO_APT_GET="sudo ${APT_GET}"
ARG SUDO_APT_GET_INSTALL="sudo DEBIANFRONTEND=noninteractive ${APT_GET_INSTALL}"
ARG CLEAN_DATA="rm -rf /tmp/* /var/cache/* /usr/share/doc/* /usr/share/man/* /var/lib/apt/lists/*"
ARG CURL="curl -fsSL"
ARG NPM_PREFIX="${HOME}/.npm"

ENV AGENT_WORKDIR="${HOME}/agent" \
    CI=true \
    PATH="${NPM_PREFIX}/bin:${HOME}/.local/bin:${PATH}" \
    JAVA_HOME="/usr/lib/jvm/temurin-11-jdk-amd64" \
    # locale and encoding \
    LANG="en_US.UTF-8" \
    LANGUAGE="en_US:en" \
    LC_ALL="en_US.UTF-8" \
    # from jenkins/docker-agent \
    TZ="Etc/UTC" \
    ## Entrypoint related \
    # Fails if cont-init and fix-attrs fails \
    S6_BEHAVIOUR_IF_STAGE2_FAILS=2 \
    # Wait for dind before running CMD \
    S6_CMD_WAIT_FOR_SERVICES=1

# create non-root user
RUN group="${NON_ROOT_USER}"; \
    uid="1000"; \
    gid="${uid}"; \
    groupadd -g "${gid}" "${group}"; \
    useradd -l -c "Jenkins user" -d "${HOME}" -u "${uid}" -g "${gid}" -m "${NON_ROOT_USER}" -s /bin/bash -p ""; \
    # install sudo and locales\
    ${APT_GET} update; \
    ${APT_GET_INSTALL} \
        sudo \
        locales; \
    # clean not needed data \
    ${CLEAN_DATA}; \
    # setup locale \
    sudo sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen; \
    sudo locale-gen; \
    # setup sudo \
    usermod -aG sudo "${NON_ROOT_USER}"; \
    echo "${NON_ROOT_USER}  ALL=(ALL) NOPASSWD:ALL" | tee "/etc/sudoers.d/${NON_ROOT_USER}"; \
    # dismiss sudo welcome message \
    sudo -u "${NON_ROOT_USER}" sudo true


# use non-root user with sudo when needed
USER "${NON_ROOT_USER}:${NON_ROOT_USER}"

WORKDIR "${AGENT_WORKDIR}"

VOLUME "${AGENT_WORKDIR}"

RUN \
    # ensure jenkins-agent directory exists \
    mkdir -p "${AGENT_WORKDIR}"; \
    ## apt \
    ${SUDO_APT_GET} update; \
    # upgrade system \
    ${SUDO_APT_GET} -yq upgrade; \
    # install add-apt-repository \
    ${SUDO_APT_GET_INSTALL} software-properties-common; \
    ## apt repositories \
    # adoptium openjdk \
    ${CURL} https://packages.adoptium.net/artifactory/api/gpg/key/public | sudo apt-key add -; \
    sudo add-apt-repository --no-update -y "https://packages.adoptium.net/artifactory/deb"; \
    # jdk installation expects this folder but we deleted during cleanup; \
    sudo mkdir -p /usr/share/man/man1; \
    # kubernetes \
    ${CURL} https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -; \
    sudo add-apt-repository --no-update -y "deb https://apt.kubernetes.io/ kubernetes-xenial main"; \
    # yarn \
    ${CURL} https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -; \
    sudo add-apt-repository --no-update -y "deb https://dl.yarnpkg.com/debian/ stable main"; \
    # jfrog \
    ${CURL} https://releases.jfrog.io/artifactory/api/gpg/key/public | sudo apt-key add -; \
    sudo add-apt-repository --no-update -y "deb https://releases.jfrog.io/artifactory/jfrog-debs xenial contrib"; \
    # git \
    sudo add-apt-repository --no-update -y ppa:git-core/ppa; \
    # yq \
    sudo add-apt-repository --no-update -y ppa:rmescandon/yq; \
    # git-lfs \
    ${CURL} https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | sudo -E bash -; \
    # nodejs \
    ${CURL} https://deb.nodesource.com/setup_lts.x | sudo -E bash -; \
    # docker \
    sudo install -m 0755 -d /etc/apt/keyrings; \
    ${CURL} https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg; \
    sudo chmod a+r /etc/apt/keyrings/docker.gpg; \
    echo \
        "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        "$(. /etc/os-release && echo "${VERSION_CODENAME}")" stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list; \
    # install apt packages \
    ${SUDO_APT_GET} update; \
    ${SUDO_APT_GET_INSTALL} \
        git \
        git-lfs \
        tree \
        jq \
        yq \
        parallel \
        rsync \
        sshpass \
        python3-pip \
        temurin-11-jdk=11.0.19.0.0+7 \
        nodejs \
        yarn \
        kubectl \
        jfrog-cli \
        jfrog-cli-v2-jf \
        shellcheck \
        maven \
        ant \
        ant-contrib \
        zip \
        unzip \
        time \
        # from jenkins/docker-agent \
        openssh-client \
        patch \
        tzdata \
        netbase \
        less \
        fontconfig \
        ca-certificates \
        # required for docker in docker \
        iptables \
        xz-utils \
        btrfs-progs \
        # network \
        net-tools \
        iputils-ping \
        traceroute \
        dnsutils \
        netcat \
        openssh-server \
        # docker pre-requisites \
        ca-certificates \
        curl \
        gnupg \
        # docker \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin; \
    ${SUDO_APT_GET} autoremove -yq; \
    sudo ${CLEAN_DATA}; \
    # setup docker \
    sudo usermod -aG docker "${NON_ROOT_USER}"; \
    ## setup docker-switch (docker-compose v1 compatibility) \
    version=$(basename "$(${CURL} -o /dev/null -w "%{url_effective}" https://github.com/docker/compose-switch/releases/latest)"); \
    sudo ${CURL} --create-dirs -o "/usr/local/bin/docker-compose" "https://github.com/docker/compose-switch/releases/download/${version}/docker-compose-$(uname -s)-amd64"; \
    sudo chmod +x /usr/local/bin/docker-compose; \
    ## dind \
    # set up subuid/subgid so that "--userns-remap=default" works out-of-the-box \
    sudo addgroup --system dockremap; \
    sudo adduser --system --ingroup dockremap dockremap; \
    echo 'dockremap:165536:65536' | sudo tee -a /etc/subuid; \
    echo 'dockremap:165536:65536' | sudo tee -a /etc/subgid; \
    # install dind hack \
    # https://github.com/moby/moby/commits/master/hack/dind \
    version="d58df1fc6c866447ce2cd129af10e5b507705624"; \
    sudo ${CURL} -o /usr/local/bin/dind "https://raw.githubusercontent.com/moby/moby/${version}/hack/dind"; \
    sudo chmod +x /usr/local/bin/dind; \
    # install jenkins-agent \
    # the same version as being used in the official agent image \
    version=$(basename "$(${CURL} -o /dev/null -w "%{url_effective}" https://github.com/jenkinsci/docker-agent/releases/latest)" |  cut -d'-' -f1) ; \
    sudo curl --create-dirs -fsSLo /usr/share/jenkins/agent.jar "https://repo.jenkins-ci.org/public/org/jenkins-ci/main/remoting/${version}/remoting-${version}.jar"; \
    sudo chmod 755 /usr/share/jenkins; \
    sudo chmod +x /usr/share/jenkins/agent.jar; \
    sudo ln -sf /usr/share/jenkins/agent.jar /usr/share/jenkins/slave.jar; \
    # install jenkins-agent wrapper from inbound-agent \
    version=$(basename "$(${CURL} -o /dev/null -w "%{url_effective}" https://github.com/jenkinsci/docker-inbound-agent/releases/latest)"); \
    sudo ${CURL} -o /usr/local/bin/jenkins-agent "https://raw.githubusercontent.com/jenkinsci/docker-inbound-agent/${version}/jenkins-agent"; \
    sudo chmod +x /usr/local/bin/jenkins-agent; \
    sudo ln -sf /usr/local/bin/jenkins-agent /usr/local/bin/jenkins-slave; \
    ## pip \
    # setup python and pip aliases \
    sudo update-alternatives --install /usr/bin/python python /usr/bin/python3 1; \
    sudo update-alternatives --install /usr/bin/pip pip /usr/bin/pip3 1; \
    # upgrade pip \
    sudo pip install --no-cache-dir --upgrade pip; \
    # install pip packages \
    sudo pip install --no-cache-dir ansible; \
    ## npm \
    # upgrade npm \
    sudo npm install -g npm@latest; \
    # allow npm --global to run as non-root \
    mkdir "${NPM_PREFIX}"; \
    npm config set prefix "${NPM_PREFIX}"; \
    # install npm packages \
    sudo npm install --global \
        semver \
        bats; \
    # clean npm cache \
    sudo npm cache clean --force; \
    ## miscellaneous \
    # install kind \
    version=$(basename "$(${CURL} -o /dev/null -w "%{url_effective}" https://github.com/kubernetes-sigs/kind/releases/latest)"); \
    sudo ${CURL} -o /usr/local/bin/kind "https://github.com/kubernetes-sigs/kind/releases/download/${version}/kind-$(uname)-amd64"; \
    sudo chmod +x /usr/local/bin/kind; \
    # install hadolint \
    version=$(basename "$(${CURL} -o /dev/null -w "%{url_effective}" https://github.com/hadolint/hadolint/releases/latest)"); \
    sudo ${CURL} -o /usr/local/bin/hadolint "https://github.com/hadolint/hadolint/releases/download/${version}/hadolint-Linux-x86_64"; \
    sudo chmod +x /usr/local/bin/hadolint; \
    # install helm 3 \
    ${CURL} https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | sudo -E bash -; \
    # install s6-overlay \
    ${CURL} -o /tmp/s6-overlay-installer https://github.com/just-containers/s6-overlay/releases/download/v2.2.0.1/s6-overlay-amd64-installer; \
    chmod +x /tmp/s6-overlay-installer; \
    sudo /tmp/s6-overlay-installer /; \
    rm -f /tmp/s6-overlay-installer; \
    # fix sshd not starting \
    sudo mkdir -p /run/sshd; \
    # install fixuid \
    # https://github.com/boxboat/fixuid/releases \
    version="0.6.0" ; \
    curl -fsSL "https://github.com/boxboat/fixuid/releases/download/v${version}/fixuid-${version}-linux-amd64.tar.gz" | sudo tar -C /usr/local/bin -xzf -; \
    sudo chown root:root /usr/local/bin/fixuid;\
    sudo chmod 4755 /usr/local/bin/fixuid; \
    sudo mkdir -p /etc/fixuid; \
    printf '%s\n' "user: ${NON_ROOT_USER}" "group: ${NON_ROOT_USER}" "paths:" "  - /" "  - ${AGENT_WORKDIR}" | sudo tee /etc/fixuid/config.yml

COPY --from=rootfs / /

ENTRYPOINT [ "/entrypoint.sh" ]
CMD [ "jenkins-agent" ]
