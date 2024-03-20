FROM jenkins/jenkins:2.440.1-lts-alpine

RUN jenkins-plugin-cli --plugins \
    kubernetes \
    workflow-aggregator \
    git \
    configuration-as-code \
    job-dsl \
    docker-workflow \
    ansicolor \
    pipeline-graph-view
