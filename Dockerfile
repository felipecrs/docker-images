# renovate: datasource=github-releases depName=jenkinsci/docker-agent versioning=loose
ARG JENKINS_AGENT_VERSION="3206.vb_15dcf73f6a_9-7"


FROM ubuntu:noble-20250127 AS ubuntu

SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]

# Build the init_as_root
FROM ubuntu AS init-as-root

# hadolint ignore=DL3008
RUN apt-get update; \
    apt-get install -y --no-install-recommends shc build-essential; \
    rm -rf /var/lib/apt/lists/*

RUN --mount=type=bind,source=devcontainer/scripts/init_as_root.sh,target=/init_as_root.sh \
    shc -S -r -f /init_as_root.sh -o /init_as_root; \
    chown root:root /init_as_root; \
    chmod 4755 /init_as_root


FROM scratch AS devcontainer-rootfs

COPY --from=init-as-root /init_as_root /
COPY devcontainer/rootfs /


FROM ubuntu AS devcontainer-base

## default locale, encoding, and timezone
ENV LANG="en_US.UTF-8"
ENV LANGUAGE="en_US:en"
ENV LC_ALL="en_US.UTF-8"
ENV TZ="Etc/UTC"
## s6-overlay
# Fails the container if any service fails to start
ENV S6_BEHAVIOUR_IF_STAGE2_FAILS="2"
# Waits for all services to start before running CMD
ENV S6_CMD_WAIT_FOR_SERVICES="1"
# Honors the timeout-up for each service
ENV S6_CMD_WAIT_FOR_SERVICES_MAXTIME="0"
# Honors container's environment variables on CMD
ENV S6_KEEP_ENV="1"
# Applies services conditions to decide which services should start
ENV S6_STAGE2_HOOK="/apply_services_conditions.sh"

RUN --mount=type=bind,source=devcontainer/scripts/prepare_image.sh,target=/prepare_image.sh \
    /prepare_image.sh

COPY --from=devcontainer-rootfs / /

ENTRYPOINT [ "/entrypoint.sh" ]
CMD []


FROM devcontainer-base AS devcontainer-user

ARG USER="devcontainer"
ARG USER_ID="1000"
# Setting these as environment variables are very useful since they will still be present
# when running commands in the container with docker exec. For the eventual case where the
# image is ran as root, these vars will be corrected only when using docker run, but the
# drawback still pays off as running this image as root is a corner case.
ENV USER="${USER}"
ENV HOME="/home/${USER}"
ENV PATH="${HOME}/.volta/bin:${HOME}/.local/bin:${PATH}"

RUN --mount=type=bind,source=devcontainer/scripts/prepare_user.sh,target=/prepare_user.sh \
    /prepare_user.sh


FROM devcontainer-user AS devcontainer

USER "${USER}"

WORKDIR "${HOME}"

VOLUME [ "/var/lib/docker" ]


FROM devcontainer-base AS jenkins-agent-dind-user

ARG USER="jenkins"
ARG USER_ID="1000"
# Setting these as environment variables are very useful since they will still be present
# when running commands in the container with docker exec. For the eventual case where the
# image is ran as root, these vars will be corrected only when using docker run, but the
# drawback still pays off as running this image as root is a corner case.
ENV USER="${USER}"
ENV HOME="/home/${USER}"
ENV PATH="${HOME}/.volta/bin:${HOME}/.local/bin:${PATH}"

RUN --mount=type=bind,source=devcontainer/scripts/prepare_user.sh,target=/prepare_user.sh \
    /prepare_user.sh


FROM jenkins/inbound-agent:${JENKINS_AGENT_VERSION}-jdk21 AS jenkins-agent


FROM scratch AS jenkins-agent-dind-rootfs

COPY --from=jenkins-agent /usr/local/bin/jenkins-agent /usr/local/bin/jenkins-slave /usr/local/bin/
COPY --from=jenkins-agent /usr/share/jenkins /usr/share/jenkins
COPY --from=jenkins-agent /opt/java/openjdk /opt/java/openjdk
COPY jenkins-agent-dind/rootfs /


FROM jenkins-agent-dind-user AS jenkins-agent-dind

ENV AGENT_WORKDIR="${HOME}/agent"
# Keep java at the end of the PATH so that users can install their own if they want
ENV PATH="${PATH}:/opt/java/openjdk/bin"

COPY --from=jenkins-agent-dind-rootfs / /

RUN --mount=type=bind,source=jenkins-agent-dind/scripts/prepare_image.sh,target=/prepare_image.sh \
    /prepare_image.sh

USER "${USER}"

WORKDIR "${AGENT_WORKDIR}"

VOLUME ["${AGENT_WORKDIR}"]


# set default stage
FROM devcontainer
