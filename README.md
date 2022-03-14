# Jenkins Agent with Docker in Docker

[![CI](https://github.com/felipecrs/jenkins-agent-dind/workflows/ci/badge.svg?branch=master&event=push)](https://github.com/felipecrs/jenkins-agent-dind/actions?query=workflow%3Aci+branch%3Amaster+event%3Apush)
[![Docker Pulls](https://img.shields.io/docker/pulls/felipecrs/jenkins-agent-dind)](https://hub.docker.com/r/felipecrs/jenkins-agent-dind)
[![Docker Image Size](https://img.shields.io/docker/image-size/felipecrs/jenkins-agent-dind/latest)](https://hub.docker.com/r/felipecrs/jenkins-agent-dind)

A full fledged Docker in Docker image to act as a Jenkins Agent. Based on [buildpack-deps:focal](https://github.com/docker-library/buildpack-deps/blob/master/focal/Dockerfile), it is a mashup of [jenkins/inbound-agent](https://github.com/jenkinsci/docker-inbound-agent) with [docker:dind](https://github.com/docker-library/docker).

- Source code: <https://github.com/felipecrs/jenkins-agent-dind>
- Docker image: <https://hub.docker.com/r/felipecrs/jenkins-agent-dind>

## Features

- Based on **Ubuntu 20.04 Focal Fossa**: a more common OS to run your builds.
- From `buildpack-deps`: a image with many common dependencies installed, run your builds without hassle.
- It contains the latest release of `agent.jar`: even more up-to-date then jenkins/agent itself.
- Fully working Docker in Docker: run your `docker build` commands with no intervention and share of resources between the host.
- Act just as a Jenkins Agent out-of-the-box: run ephemeral build containers by using Docker Plugin (or Kubernetes Plugin) for Jenkins. Works as the official `jnlp`/`inbound-agent`.

## Usage

### Command line

Spin this agent in shell, if you want to play with it:

```sh
# Fetches the latest version
docker pull ghcr.io/felipecrs/jenkins-agent-dind
# -ti: allocates a pseudo-TTY in order to run bash
# --rm: removes the container after using it (don't forget to remove the volumes created by it)
# --privileged: needed for running Docker in Docker
docker run -ti --rm --privileged felipecrs/jenkins-agent-dind bash
```

### Agent Template in Docker Cloud configuration on Jenkins

![Sample Agent Template configuration](https://user-images.githubusercontent.com/29582865/106769145-66379180-661b-11eb-93e3-5a7742eb46c0.png)

### Kubernetes Plugin Pod Template

The following is the Pod definition that you can use as a Pod template with the Kubernetes Plugin. It contains [optimizations](https://github.com/kubernetes-sigs/kind/issues/303) to allow running KinD within the pod as well.

```yaml
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: jnlp
    image: ghcr.io/felipecrs/jenkins-agent-dind:latest
    imagePullPolicy: Always
    securityContext:
      privileged: true
    workingDir: /home/jenkins/agent
    volumeMounts:
      - mountPath: /home/jenkins/agent
        name: workspace-volume
      - mountPath: /lib/modules
        name: lib-modules
        readOnly: true
      - mountPath: /sys/fs/cgroup
        name: sys-fs-cgroup
  hostNetwork: false
  automountServiceAccountToken: false
  enableServiceLinks: false
  dnsPolicy: Default
  restartPolicy: Never
  terminationGracePeriodSeconds: 60
  volumes:
    - name: workspace-volume
      emptyDir: {}
    - name: lib-modules
      hostPath:
        path: /lib/modules
        type: Directory
    - name: sys-fs-cgroup
      hostPath:
        path: /sys/fs/cgroup
        type: Directory
```
