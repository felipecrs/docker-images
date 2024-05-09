ARG JENKINS_VERSION
FROM jenkins/jenkins:${JENKINS_VERSION}-alpine-jdk21

RUN jenkins-plugin-cli --plugins \
    kubernetes \
    workflow-aggregator \
    git \
    configuration-as-code \
    job-dsl \
    docker-workflow \
    ansicolor \
    pipeline-graph-view
