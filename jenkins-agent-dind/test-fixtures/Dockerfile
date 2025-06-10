ARG JENKINS_VERSION

FROM jenkins/jenkins:${JENKINS_VERSION}

ARG DEFAULT_PLUGINS
# renovate: datasource=jenkins-plugins depName=job-dsl
ARG JOB_DSL_VERSION="1.93"
# renovate: datasource=jenkins-plugins depName=docker-pipeline packageName=docker-workflow
ARG DOCKER_PIPELINE_VERSION="621.va_73f881d9232"
# renovate: datasource=jenkins-plugins depName=ansicolor
ARG ANSICOLOR_VERSION="1.0.6"

RUN jenkins-plugin-cli --plugins \
    ${DEFAULT_PLUGINS} \
    "job-dsl:${JOB_DSL_VERSION}" \
    "docker-workflow:${DOCKER_PIPELINE_VERSION}" \
    "ansicolor:${ANSICOLOR_VERSION}" \
    pipeline-graph-view \
    saferestart \
    dark-theme \
    locale \
    PrioritySorter:863.v4a_b_974a_5d042
