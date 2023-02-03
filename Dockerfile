FROM buildpack-deps:focal AS base

# set bash as the default interpreter for the build with:
# -e: exits on error, so we can use colon as line separator
# -u: throw error on variable unset
# -o pipefail: exits on first command failed in pipe
SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]


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


# Build skopeo from source because of https://github.com/containers/skopeo/issues/1648
FROM golang:1.18 AS skopeo

WORKDIR /usr/src/skopeo

ARG SKOPEO_VERSION="1.8.0"
RUN curl -fsSL "https://github.com/containers/skopeo/archive/v${SKOPEO_VERSION}.tar.gz" \
  | tar -xzf - --strip-components=1

RUN CGO_ENABLED=0 DISABLE_DOCS=1 make BUILDTAGS=containers_image_openpgp GO_DYN_FLAGS=

RUN ./bin/skopeo --version


FROM scratch AS rootfs

COPY --from=init_as_root /init_as_root /
COPY rootfs /
COPY --from=skopeo /usr/src/skopeo/bin/skopeo /usr/local/bin/
COPY --from=skopeo /usr/src/skopeo/default-policy.json /etc/containers/policy.json


FROM base

ENV NON_ROOT_USER=jenkins
ARG HOME="/home/${NON_ROOT_USER}"

# build helpers
ARG DEBIANFRONTEND="noninteractive"
ARG APT_GET="apt-get"
ARG APT_GET_INSTALL="${APT_GET} install -yq --no-install-recommends"
ARG SUDO_APT_GET="sudo ${APT_GET}"
ARG SUDO_APT_GET_INSTALL="sudo DEBIANFRONTEND=noninteractive ${APT_GET_INSTALL}"
ARG CLEAN_APT="rm -rf /var/lib/apt/lists/*"
ARG SUDO_CLEAN_APT="sudo ${CLEAN_APT}"
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
    ## Entrypoint related \
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
    # clean apt cache \
    ${CLEAN_APT}; \
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
    # install apt packages \
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
        temurin-11-jdk \
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
        openssh-server; \
    # install docker \
    ${CURL} https://get.docker.com | sudo sh; \
    ${SUDO_APT_GET} autoremove -yq; \
    ${SUDO_CLEAN_APT}; \
    # setup docker \
    sudo usermod -aG docker "${NON_ROOT_USER}"; \
    # setup buildx \
    version=$(basename "$(${CURL} -o /dev/null -w "%{url_effective}" https://github.com/docker/buildx/releases/latest)"); \
    ${CURL} --create-dirs -o "${HOME}/.docker/cli-plugins/docker-buildx" "https://github.com/docker/buildx/releases/download/${version}/buildx-${version}.$(uname -s)-amd64"; \
    chmod a+x "${HOME}/.docker/cli-plugins/docker-buildx"; \
    docker buildx install; \
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
    version="1f32e3c95d72a29b3eaacba156ed675dba976cb5"; \
    sudo ${CURL} -o /usr/local/bin/dind "https://raw.githubusercontent.com/moby/moby/${version}/hack/dind"; \
    sudo chmod +x /usr/local/bin/dind; \
    # install jenkins-agent \
    base_url="https://repo.jenkins-ci.org/public/org/jenkins-ci/main/remoting"; \
    version=$(curl -fsS ${base_url}/maven-metadata.xml | grep "<latest>.*</latest>" | sed -e "s#\(.*\)\(<latest>\)\(.*\)\(</latest>\)\(.*\)#\3#g"); \
    sudo curl --create-dirs -fsSLo /usr/share/jenkins/agent.jar "${base_url}/${version}/remoting-${version}.jar"; \
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
    curl -fsSL https://github.com/boxboat/fixuid/releases/download/v0.5.1/fixuid-0.5.1-linux-amd64.tar.gz | sudo tar -C /usr/local/bin -xzf -; \
    sudo chown root:root /usr/local/bin/fixuid;\
    sudo chmod 4755 /usr/local/bin/fixuid; \
    sudo mkdir -p /etc/fixuid; \
    printf '%s\n' "user: ${NON_ROOT_USER}" "group: ${NON_ROOT_USER}" "paths:" "  - /" "  - ${AGENT_WORKDIR}" | sudo tee /etc/fixuid/config.yml

COPY --from=rootfs / /

ENTRYPOINT [ "/entrypoint.sh" ]
CMD [ "jenkins-agent" ]
