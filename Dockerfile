FROM buildpack-deps:focal

# set bash as the default interpreter for the build with:
# -e: exits on error, so we can use colon as line separator
# -u: throw error on variable unset
# -o pipefail: exits on first command failed in pipe
SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]

ENV USER=jenkins
ENV HOME="/home/${USER}"

# build helpers
ARG DEBIANFRONTEND="noninteractive"
ARG APT_GET="apt-get"
ARG APT_GET_INSTALL="${APT_GET} install -yq --no-install-recommends"
ARG SUDO_APT_GET="sudo ${APT_GET}"
ARG SUDO_APT_GET_INSTALL="sudo DEBIANFRONTEND=noninteractive ${APT_GET_INSTALL}"
ARG CLEAN_APT="rm -rf /var/lib/apt/lists/*"
ARG SUDO_CLEAN_APT="sudo ${CLEAN_APT}"
ARG CURL="curl -fsSL"
ARG NPM_GLOBAL_PATH="${HOME}/.npm-global"

ENV AGENT_WORKDIR="${HOME}/agent" \
    CI=true \
    PATH="${NPM_GLOBAL_PATH}/bin:${HOME}/.local/bin:${PATH}" \
    JAVA_HOME="/usr/lib/jvm/adoptopenjdk-8-hotspot-amd64" \
    # locale and encoding
    LANG="en_US.UTF-8" \
    LANGUAGE="en_US:en" \
    LC_ALL="en_US.UTF-8"

# create non-root user
RUN group=${USER}; \
    uid=1000; \
    gid=${uid}; \
    groupadd -g ${gid} ${group}; \
    useradd -c "Jenkins user" -d "${HOME}" -u ${uid} -g ${gid} -m ${USER} -s /bin/bash; \
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
    usermod -aG sudo ${USER}; \
    echo "${USER}  ALL=(ALL) NOPASSWD:ALL" | tee "/etc/sudoers.d/${USER}"; \
    # dismiss sudo welcome message \
    sudo -u "${USER}" sudo true

# use non-root user with sudo when needed
USER "${USER}"

VOLUME "${AGENT_WORKDIR}"

WORKDIR "${HOME}"

# assure jenkins-agent directories
RUN mkdir -p "${AGENT_WORKDIR}"; \
    ## apt \
    ${SUDO_APT_GET} update; \
    # upgrade system \
    ${SUDO_APT_GET} -yq upgrade; \
    # install add-apt-repository \
    ${SUDO_APT_GET_INSTALL} software-properties-common; \
    ## apt repositories \
    # adopt openjdk \
    ${CURL} https://adoptopenjdk.jfrog.io/adoptopenjdk/api/gpg/key/public | sudo apt-key add -; \
    sudo add-apt-repository --no-update -y https://adoptopenjdk.jfrog.io/adoptopenjdk/deb/; \
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
    # shc \
    sudo add-apt-repository --no-update -y ppa:neurobin/ppa; \
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
        adoptopenjdk-8-hotspot \
        nodejs \
        yarn \
        kubectl \
        jfrog-cli \
        shellcheck \
        maven \
        ant \
        ant-contrib \
        # required for the entrypoint \
        shc \
        # required for docker in docker \
        iptables \
        xz-utils \
        btrfs-progs \
        # network \
        net-tools \
        iputils-ping \
        traceroute \
        dnsutils; \
    # install docker 19.03 \
    ${CURL} https://releases.rancher.com/install-docker/19.03.sh | sudo sh; \
    ${SUDO_APT_GET} autoremove -yq; \
    ${SUDO_CLEAN_APT}; \
    # setup docker \
    sudo usermod -aG docker "${USER}"; \
    # setup docker volume \
    sudo mkdir -p /etc/docker; \
    jq -n --arg d "${AGENT_WORKDIR}/docker" '."data-root" = $d' | sudo tee /etc/docker/daemon.json; \
    # setup buildx \
    version=$(${CURL} https://api.github.com/repos/docker/buildx/releases/latest | jq .tag_name -er); \
    ${CURL} --create-dirs -o "$HOME/.docker/cli-plugins/docker-buildx" "https://github.com/docker/buildx/releases/download/${version}/buildx-${version}.$(uname -s)-amd64"; \
    chmod a+x "$HOME/.docker/cli-plugins/docker-buildx"; \
    docker buildx install; \
    # install docker-compose \
    version=$(${CURL} https://api.github.com/repos/docker/compose/releases/latest | jq .tag_name -er); \
    sudo ${CURL} -o /usr/local/bin/docker-compose "https://github.com/docker/compose/releases/download/${version}/docker-compose-$(uname -s)-$(uname -m)"; \
    sudo chmod +x /usr/local/bin/docker-compose; \
    ## dind \
    # set up subuid/subgid so that "--userns-remap=default" works out-of-the-box \
    sudo addgroup --system dockremap; \
    sudo adduser --system --ingroup dockremap dockremap; \
    echo 'dockremap:165536:65536' | sudo tee -a /etc/subuid; \
    echo 'dockremap:165536:65536' | sudo tee -a /etc/subgid; \
    # install dind hack \
    version=ed89041433a031cafc0a0f19cfe573c31688d377; \
    sudo ${CURL} -o /usr/local/bin/dind "https://raw.githubusercontent.com/docker/docker/${version}/hack/dind"; \
    sudo chmod +x /usr/local/bin/dind; \
    # install jenkins-agent \
    base_url="https://repo.jenkins-ci.org/public/org/jenkins-ci/main/remoting"; \
    version=$(curl -fsS ${base_url}/maven-metadata.xml | grep "<latest>.*</latest>" | sed -e "s#\(.*\)\(<latest>\)\(.*\)\(</latest>\)\(.*\)#\3#g"); \
    sudo curl --create-dirs -fsSLo /usr/share/jenkins/agent.jar "${base_url}/${version}/remoting-${version}.jar"; \
    sudo chmod 755 /usr/share/jenkins; \
    sudo chmod +x /usr/share/jenkins/agent.jar; \
    sudo ln -sf /usr/share/jenkins/agent.jar /usr/share/jenkins/slave.jar; \
    # install jenkins-agent wrapper from inbound-agent \
    version=$(${CURL} https://api.github.com/repos/jenkinsci/docker-inbound-agent/releases/latest | jq .name -er); \
    sudo ${CURL} -o /usr/local/bin/jenkins-agent "https://raw.githubusercontent.com/jenkinsci/docker-inbound-agent/${version}/jenkins-agent"; \
    sudo chmod +x /usr/local/bin/jenkins-agent; \
    sudo ln -sf /usr/local/bin/jenkins-agent /usr/local/bin/jenkins-slave; \
    ## pip \
    # upgrade pip \
    sudo python3 -m pip install --no-cache-dir --upgrade pip; \
    # setup python and pip aliases \
    sudo update-alternatives --install /usr/bin/python python /usr/bin/python3 1; \
    sudo update-alternatives --install /usr/bin/pip pip /usr/bin/pip3 1; \
    # install pip packages \
    pip install --user --no-cache-dir ansible; \
    ## npm \
    # upgrade npm \
    sudo npm install -g npm@latest; \
    # allow npm --global to run as non-root \
    mkdir "${NPM_GLOBAL_PATH}"; \
    npm config set prefix "${NPM_GLOBAL_PATH}"; \
    # install npm packages \
    npm install --global \
        semver \
        bats; \
    # clean npm cache \
    sudo npm cache clean --force; \
    npm cache clean --force; \
    ## miscellaneous \
    # install kind \
    version=$(${CURL} https://api.github.com/repos/kubernetes-sigs/kind/releases/latest | jq .name -er); \
    sudo ${CURL} -o /usr/local/bin/kind "https://github.com/kubernetes-sigs/kind/releases/download/${version}/kind-$(uname)-amd64"; \
    sudo chmod +x /usr/local/bin/kind; \
    # install helm 3 \
    ${CURL} https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | sudo -E bash -

COPY _entrypoint.sh entrypoint.sh /

# install s6-overlay
RUN ${CURL} -o /tmp/s6-overlay-installer https://github.com/just-containers/s6-overlay/releases/download/v2.2.0.1/s6-overlay-amd64-installer; \
    chmod +x /tmp/s6-overlay-installer; \
    sudo /tmp/s6-overlay-installer /; \
    rm -f /tmp/s6-overlay-installer; \
    # create dind dockerd service \
    sudo mkdir -p /etc/services.d/dind; \
    printf '%s\n' '#!/usr/bin/execlineb -P' 's6-notifyoncheck -c "docker version"' '/usr/local/bin/dind dockerd' | sudo tee /etc/services.d/dind/run; \
    printf '%s\n' '3'| sudo tee /etc/services.d/dind/notification-fd; \
    printf '%s\n' '#!/usr/bin/execlineb -S0' 's6-svscanctl -t /var/run/s6/services' | sudo tee /etc/services.d/dind/finish; \
    # setup entrypoint \
    sudo shc -S -r -f /_entrypoint.sh -o /_entrypoint; \
    sudo chown root:root /_entrypoint; \
    sudo chmod 4755 /_entrypoint; \
    sudo rm -f /_entrypoint.sh

ENTRYPOINT [ "/entrypoint.sh" ]
CMD [ "jenkins-agent" ]
