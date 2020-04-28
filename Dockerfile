FROM buildpack-deps:bionic

SHELL ["/bin/bash", "-c"]
ARG DEBIANFRONTEND=noninteractive

ARG user=jenkins
ARG group=jenkins
ARG uid=1000
ARG gid=1000

RUN groupadd -g ${gid} ${group}
RUN useradd -c "Jenkins user" -d /home/${user} -u ${uid} -g ${gid} -m ${user} -s /bin/bash

RUN set -exo pipefail; \
    apt-get update; \
    apt-get install -yq software-properties-common; \
    wget -qO - https://adoptopenjdk.jfrog.io/adoptopenjdk/api/gpg/key/public | apt-key add -; \
    add-apt-repository -y https://adoptopenjdk.jfrog.io/adoptopenjdk/deb/; \
    add-apt-repository -y ppa:git-core/ppa; \
    add-apt-repository -y ppa:rmescandon/yq; \
    apt-get update; \
    apt-get install -yq \
    git \
    tree \
    jq \
    yq \
    # Because of jenkins/slave
    adoptopenjdk-8-hotspot \
    # Required to run Docker daemon in entrypoint
    supervisor \
    # Required to go back to jenkins user in entrypoint
    gosu \
    # Required to run Docker in Docker
    iptables \
    xz-utils \
    btrfs-progs

# Because of jenkins/slave
RUN curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | bash && \
    apt-get install -y git-lfs

RUN curl -fsSL https://get.docker.com | sh && \
    usermod --append --groups docker ${user}

RUN set -ex; \
    VERSION=$(curl -fsL https://api.github.com/repos/docker/compose/releases/latest | jq .name -r); \
    curl -fsSL "https://github.com/docker/compose/releases/download/${VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose; \
    chmod +x /usr/local/bin/docker-compose

RUN rm -rf /var/lib/apt/lists/*

# set up subuid/subgid so that "--userns-remap=default" works out-of-the-box
RUN set -x \
    && addgroup --system dockremap \
    && adduser --system --ingroup dockremap dockremap \
    && echo 'dockremap:165536:65536' >> /etc/subuid \
    && echo 'dockremap:165536:65536' >> /etc/subgid

RUN set -eux; \
    dind_commit=37498f009d8bf25fbb6199e8ccd34bed84f2874b; \
    dind_file=/usr/local/bin/dind; \
    wget -qO "$dind_file" "https://raw.githubusercontent.com/docker/docker/$dind_commit/hack/dind"; \
    chmod +x "$dind_file"

VOLUME /var/lib/docker

ARG AGENT_WORKDIR=/home/${user}/agent

RUN REMOTING_URL="https://repo.jenkins-ci.org/public/org/jenkins-ci/main/remoting" && \
    VERSION=$(curl -fsS ${REMOTING_URL}/maven-metadata.xml | grep "<latest>.*</latest>" | sed -e "s#\(.*\)\(<latest>\)\(.*\)\(</latest>\)\(.*\)#\3#g") && \
    curl --create-dirs -fsSLo /usr/share/jenkins/agent.jar ${REMOTING_URL}/${VERSION}/remoting-${VERSION}.jar \
    && chmod 755 /usr/share/jenkins \
    && chmod 644 /usr/share/jenkins/agent.jar \
    && ln -sf /usr/share/jenkins/agent.jar /usr/share/jenkins/slave.jar

USER ${user}
ENV AGENT_WORKDIR=${AGENT_WORKDIR}
RUN mkdir /home/${user}/.jenkins && mkdir -p ${AGENT_WORKDIR}

VOLUME /home/${user}/.jenkins
VOLUME ${AGENT_WORKDIR}
WORKDIR /home/${user}

ENV CI=true

USER root

# Node.js v12.x
RUN set -euxo pipefail; \
    curl -fsSL https://deb.nodesource.com/setup_12.x | bash -; \
    apt-get install -qq nodejs

# Install shellcheck
RUN set -euxo pipefail; \
    wget -q 'https://storage.googleapis.com/shellcheck/shellcheck-stable.linux.x86_64.tar.xz' -O - \
    | tar -xJf - --strip-components=1 -C /usr/local/bin shellcheck-stable/shellcheck; \
    chmod +x /usr/local/bin/shellcheck

# Install bats
RUN npm install -g bats

# Install Ansible
RUN set -ex; \
    apt-add-repository --yes --update ppa:ansible/ansible; \
    apt-get install -y ansible

# Install Helm
RUN set -exo pipefail; \
    curl -fsSL https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash

# Install kind
RUN set -ex; \
    curl -fsSLo /usr/local/bin/kind "https://kind.sigs.k8s.io/dl/v0.7.0/kind-$(uname)-amd64"; \
    chmod +x /usr/local/bin/kind

# Install kubectl
RUN set -exo pipefail; \
    curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -; \
    add-apt-repository --yes --update "deb https://apt.kubernetes.io/ kubernetes-xenial main"; \
    apt-get install -y kubectl

# s6-overlay
ADD https://github.com/just-containers/s6-overlay/releases/download/v1.22.1.0/s6-overlay-amd64.tar.gz /tmp/
RUN tar xzf /tmp/s6-overlay-amd64.tar.gz -C /
RUN set -ex; \
    mkdir -p /etc/services.d/dind; \
    printf '#!/usr/bin/execlineb -P\ns6-notifyoncheck -c "docker version"\n/usr/local/bin/dind dockerd' > /etc/services.d/dind/run; \
    echo '3' > /etc/services.d/dind/notification-fd; \
    printf '#!/usr/bin/execlineb -S0\ns6-svscanctl -t /var/run/s6/services' > /etc/services.d/dind/finish
ENV S6_CMD_WAIT_FOR_SERVICES=1
ENTRYPOINT [ "/init", "gosu", "jenkins" ]
CMD [ "bash" ]
