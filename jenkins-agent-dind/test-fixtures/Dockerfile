ARG JENKINS_VERSION="lts-alpine-jdk21"

FROM jenkins/jenkins:${JENKINS_VERSION}

ARG DEFAULT_PLUGINS
# renovate: datasource=jenkins-plugins depName=job-dsl
ARG JOB_DSL_VERSION="3654.vdf58f53e2d15"
# renovate: datasource=jenkins-plugins depName=docker-pipeline packageName=docker-workflow
ARG DOCKER_PIPELINE_VERSION="634.vedc7242b_eda_7"
# renovate: datasource=jenkins-plugins depName=ansicolor
ARG ANSICOLOR_VERSION="536.v13fa_b_860c267"

RUN jenkins-plugin-cli --plugins \
    ${DEFAULT_PLUGINS} \
    "job-dsl:${JOB_DSL_VERSION}" \
    "docker-workflow:${DOCKER_PIPELINE_VERSION}" \
    "ansicolor:${ANSICOLOR_VERSION}" \
    pipeline-graph-view \
    saferestart \
    dark-theme \
    locale
