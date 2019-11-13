# Jenkins Agent with Docker installed

A full fledged image to act as a Jenkins Agent. It is based on buildpack-deps:bionic, and it is a mashup of jenkins/slave with docker:dind.

## Features

- Based on Ubuntu 18.04 Bionic: a more common OS to run your builds.
- From buildpack-deps: a image with many common dependencies installed, run your builds without hassle.
- It contains the latest release of `agent.jar`: even more up-to-date then jenkins/slave itself.
- Fully working Docker in Docker: run your `docker build` commands with no intervention and share of resources between the host.
- Act just as a Jenkins Slave out-of-the-box: run ephemeral build containers by using Docker Plugin for Jenkins.

## Usage

### Command line

Spin this agent in shell, if you want to play with it:

```sh
# Fetches the latest version
docker pull felipecassiors/jenkins-agent-docker:dind
# --privilged: needed for running Docker in Docker
# --rm: besides removing the container when stopped, also removes the dangling volumes created by it
# -ti: allocates a pseudo-TTY in order to run the default command, wich is bash
docker run --privileged --rm -ti --name jenkins-agent-dind felipecassiors/jenkins-agent-docker:dind
```

### Agent Template in Docker Cloud configuration on Jenkins

[Sample Agent Template configuration](docs/jenkins-agent-template-sample.png)
