# renovate: datasource=github-releases depName=jenkinsci/docker-agent versioning=loose
ARG JENKINS_AGENT_VERSION="3206.vb_15dcf73f6a_9-6"


FROM jenkins/inbound-agent:${JENKINS_AGENT_VERSION}-jdk17 AS jenkins-agent


FROM scratch AS rootfs

COPY --from=jenkins-agent /usr/local/bin/jenkins-agent /usr/local/bin/jenkins-slave /usr/local/bin/
COPY --from=jenkins-agent /usr/share/jenkins /usr/share/jenkins
COPY --from=jenkins-agent /opt/java/openjdk /opt/java/openjdk
COPY rootfs /


# hadolint ignore=DL3006
FROM devcontainer-jenkins-agent-dind

ENV AGENT_WORKDIR="${NON_ROOT_HOME}/agent"
ENV PATH="${PATH}:/opt/java/openjdk/bin"

COPY --from=rootfs / /

RUN --mount=type=bind,source=scripts/prepare_image.sh,target=/prepare_image.sh \
    /prepare_image.sh

USER "${NON_ROOT_USER}"

WORKDIR "${AGENT_WORKDIR}"

VOLUME ["${AGENT_WORKDIR}"]
