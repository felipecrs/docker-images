FROM buildpack-deps:focal

SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]

ENV USER=jenkins
ARG group=jenkins
ARG uid=1000
ARG gid=1000

ENV HOME="/home/${USER}"
ENV AGENT_WORKDIR="${HOME}/agent" \
    CI=true

RUN groupadd -g ${gid} ${group}; \
    useradd -c "Jenkins user" -d "${HOME}" -u ${uid} -g ${gid} -m ${USER} -s /bin/bash

ARG DEBIANFRONTEND=noninteractive

## Set up sudo
RUN apt-get update; \
    apt-get install -yq sudo; \
    rm -rf /var/lib/apt/lists/*; \
    usermod -aG sudo ${USER}; \
    echo "${USER}  ALL=(ALL) NOPASSWD:ALL" | tee "/etc/sudoers.d/${USER}"; \
    sudo -u "${USER}" sudo true # Dismiss sudo welcome message

USER "${USER}"

RUN mkdir -p "${AGENT_WORKDIR}"; \
    mkdir -p "${HOME}/.jenkins"

VOLUME "${AGENT_WORKDIR}" "${HOME}/.jenkins" "/var/lib/docker"

WORKDIR "${HOME}"

RUN sudo apt-get update; \
    sudo apt-get -y upgrade; \
    sudo apt-get install -yq software-properties-common; \
    curl -fsSL https://adoptopenjdk.jfrog.io/adoptopenjdk/api/gpg/key/public | sudo apt-key add -; \
    sudo add-apt-repository --no-update -y https://adoptopenjdk.jfrog.io/adoptopenjdk/deb/; \
    sudo add-apt-repository --no-update -y ppa:git-core/ppa; \
    sudo add-apt-repository --no-update -y ppa:rmescandon/yq; \
    sudo add-apt-repository --update -y ppa:neurobin/ppa; \
    sudo apt-get install -yq \
    locales \
    git \
    tree \
    jq \
    yq \
    parallel \
    rsync \
    python3-pip \
    # Required by the entrypoint
    shc \
    # Because of jenkins/agent
    adoptopenjdk-8-hotspot \
    # Required to run Docker in Docker
    iptables \
    xz-utils \
    btrfs-progs; \
    # Setup python aliases
    sudo update-alternatives --install /usr/bin/python python /usr/bin/python3 1; \
    sudo update-alternatives --install /usr/bin/pip pip /usr/bin/pip3 1; \
    # Upgrade pip
    pip install --user --upgrade --no-cache-dir pip; \
    # Fix locale
    sudo sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen; \
    sudo locale-gen; \
    # Cleanup
    sudo rm -rf /var/lib/apt/lists/*

# For npm and pip
ENV PATH="${HOME}/.npm-global/bin:${HOME}/.local/bin:${PATH}" \
    JAVA_HOME="/usr/lib/jvm/adoptopenjdk-8-hotspot-amd64" \
    # Locale
    LANG="en_US.UTF-8" \
    LANGUAGE="en_US:en" \
    LC_ALL="en_US.UTF-8"

# Because of jenkins/agent
RUN sudo bash -c "$(curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh)" \
    apt-get install -y git-lfs; \
    sudo rm -rf /var/lib/apt/lists/*

# Docker v19.03 because of https://github.com/containerd/containerd/issues/4837
RUN sudo sh -c "$(curl -fsSL https://releases.rancher.com/install-docker/19.03.sh)"; \
    sudo usermod -aG docker "${USER}"; \
    # Enable buildx
    mkdir -p "$HOME/.docker"; \
    echo '{"experimental": "enabled"}' > "$HOME/.docker/config.json"; \
    docker buildx install; \
    sudo rm -rf /var/lib/apt/lists/*

RUN version=$(curl -fsSL https://api.github.com/repos/docker/compose/releases/latest | jq .name -er); \
    sudo curl -fsSLo /usr/local/bin/docker-compose "https://github.com/docker/compose/releases/download/${version}/docker-compose-$(uname -s)-$(uname -m)"; \
    sudo chmod +x /usr/local/bin/docker-compose

# set up subuid/subgid so that "--userns-remap=default" works out-of-the-box
RUN sudo addgroup --system dockremap; \
    sudo adduser --system --ingroup dockremap dockremap; \
    echo 'dockremap:165536:65536' | sudo tee -a /etc/subuid; \
    echo 'dockremap:165536:65536' | sudo tee -a /etc/subgid

RUN version=ed89041433a031cafc0a0f19cfe573c31688d377; \
    sudo curl -fsSLo /usr/local/bin/dind "https://raw.githubusercontent.com/docker/docker/${version}/hack/dind"; \
    sudo chmod +x /usr/local/bin/dind

RUN base_url="https://repo.jenkins-ci.org/public/org/jenkins-ci/main/remoting"; \
    version=$(curl -fsS ${base_url}/maven-metadata.xml | grep "<latest>.*</latest>" | sed -e "s#\(.*\)\(<latest>\)\(.*\)\(</latest>\)\(.*\)#\3#g"); \
    sudo curl --create-dirs -fsSLo /usr/share/jenkins/agent.jar ${base_url}/${version}/remoting-${version}.jar; \
    sudo chmod 755 /usr/share/jenkins; \
    sudo chmod +x /usr/share/jenkins/agent.jar; \
    sudo ln -sf /usr/share/jenkins/agent.jar /usr/share/jenkins/slave.jar; \
    # jenkins inbound/jnlp agent wrapper
    version=$(curl -fsSL https://api.github.com/repos/jenkinsci/docker-inbound-agent/releases/latest | jq .name -er); \
    sudo curl -fsSLo /usr/local/bin/jenkins-agent https://raw.githubusercontent.com/jenkinsci/docker-inbound-agent/${version}/jenkins-agent; \
    sudo chmod +x /usr/local/bin/jenkins-agent; \
    sudo ln -sf /usr/local/bin/jenkins-agent /usr/local/bin/jenkins-slave

# Node.js v14.x
RUN sudo bash -c "$(curl -fsSL https://deb.nodesource.com/setup_14.x)"; \
    sudo apt-get install -yq nodejs; \
    mkdir "${HOME}/.npm-global"; \
    npm config set prefix "${HOME}/.npm-global"; \
    npm install -g npm@latest; \ 
    sudo rm -rf /var/lib/apt/lists/*

# Install bats
RUN npm install -g bats

# Install shellcheck
RUN curl -fsSL 'https://storage.googleapis.com/shellcheck/shellcheck-stable.linux.x86_64.tar.xz' \
    | sudo tar -xJf - --strip-components=1 -C /usr/local/bin shellcheck-stable/shellcheck; \
    sudo chmod +x /usr/local/bin/shellcheck

# Install Ansible
RUN pip install --user --no-cache-dir ansible

# Install Helm
RUN sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3)"

# Install kind
RUN version=$(curl -fsSL https://api.github.com/repos/kubernetes-sigs/kind/releases/latest | jq .name -er); \
    sudo curl -fsSLo /usr/local/bin/kind https://github.com/kubernetes-sigs/kind/releases/download/${version}/kind-$(uname)-amd64; \
    sudo chmod +x /usr/local/bin/kind

# Install kubectl
RUN curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -; \
    sudo add-apt-repository --yes --update "deb https://apt.kubernetes.io/ kubernetes-xenial main"; \
    sudo apt-get install -yq kubectl; \
    sudo rm -rf /var/lib/apt/lists/*

# s6-overlay
RUN curl -fsSLo /tmp/s6-overlay-installer https://github.com/just-containers/s6-overlay/releases/download/v2.2.0.1/s6-overlay-amd64-installer; \
    chmod +x /tmp/s6-overlay-installer; \
    sudo /tmp/s6-overlay-installer /; \
    rm -f /tmp/s6-overlay-installer; \
    # Create Docker in Docker service
    sudo mkdir -p /etc/services.d/dind; \
    printf '%s\n' '#!/usr/bin/execlineb -P' 's6-notifyoncheck -c "docker version"' '/usr/local/bin/dind dockerd' | sudo tee /etc/services.d/dind/run; \
    printf '%s\n' '3'| sudo tee /etc/services.d/dind/notification-fd; \
    printf '%s\n' '#!/usr/bin/execlineb -S0' 's6-svscanctl -t /var/run/s6/services' | sudo tee /etc/services.d/dind/finish

COPY _entrypoint.sh entrypoint.sh /
RUN sudo shc -S -r -f /_entrypoint.sh -o /_entrypoint; \
    sudo chown root:root /_entrypoint; \
    sudo chmod 4755 /_entrypoint; \
    sudo rm -f /_entrypoint.sh

ENTRYPOINT [ "/entrypoint.sh" ]
CMD [ "jenkins-agent" ]
