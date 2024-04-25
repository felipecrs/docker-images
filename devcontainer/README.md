# Devcontainer

[![CI](https://github.com/felipecrs/docker-images/workflows/ci/badge.svg?branch=master&event=push)](https://github.com/felipecrs/docker-images/actions?query=workflow%3Aci+branch%3Amaster+event%3Apush)
[![Docker Image Size](https://ghcr-badge.egpl.dev/felipecrs/devcontainer/size)](https://github.com/felipecrs/docker-images/pkgs/container/devcontainer)

A multi-purpose Docker on Docker or Docker in Docker image to be used as a Devcontainer.

- Image tags: [`ghcr.io/felipecrs/devcontainer`](https://github.com/felipecrs/docker-images/pkgs/container/devcontainer)

> [!IMPORTANT]
> This image used to be uploaded to Docker Hub as `felipecrs/devcontainer` but it no longer is. Please update to the new tag `ghcr.io/felipecrs/devcontainer`.

## Features

- **Based on Ubuntu 24.04 Noble Numbat**: a more common distribution to run your development environment on.
- Fully functional **Docker on Docker**: shares the host's Docker daemon to avoid the overhead of running a nested Docker daemon. Comes with the [docker-on-docker-shim](https://github.com/felipecrs/docker-on-docker-shim) to provide a seamless experience.
- Also supports **Docker in Docker**: you can choose not to share the host's Docker daemon, and therefore run `docker` from within the devcontainer in a fully isolated manner.
- Several common packages installed: the common tools frequently needed are already baked in.
- Bundles [**`pkgx`**](https://pkgx.sh), a convenient package manager that allows you to **easily and quickly install the necessary tools for your project**. Example: `pkgx install node@18 npm@10`.
- Facilitates sharing access to your devcontainer by providing an **opt-in SSH server**. Read more about it [here](#accessing-the-devcontainer-through-ssh).
- Can also be used as a Jenkins dockerfile agent, ensuring **both your development and CI/CD environment are the same**. Read more about it [here](#jenkinsfile-dockerfile-agent).

## Usage

### Command line

Spin this image in your terminal, if you want to play with it:

```sh
# --rm: removes the container and its volumes after exiting
# -it: allows to interact with the container
# --volume: shares the host's Docker socket with the container
# --network=host: allows to access ports from other containers running on the host
docker run --rm -it --volume=/var/run/docker.sock:/var/run/docker.sock --network=host \
  ghcr.io/felipecrs/devcontainer
```

Alternatively, you can try the Docker in Docker mode:

```sh
# --privileged: needed for running Docker in Docker
docker run -it --rm --privileged ghcr.io/felipecrs/devcontainer
```

### Devcontainer in Visual Studio Code

The main purpose of this image is to be used as a [Devcontainer in Visual Studio Code](https://code.visualstudio.com/docs/devcontainers/containers), or in [GitHub Codespaces](https://github.com/features/codespaces).

It is a good practice to run your development environment in a container, so you can have a consistent environment across your team.

Considering you have a `.devcontainer/Dockerfile` like this:

```dockerfile
# .devcontainer/Dockerfile
FROM ghcr.io/felipecrs/devcontainer

# Install your project's dependencies
RUN pkgx install nodejs.org@20 npmjs.com@10 \
    && node --version \
    && npm --version
```

To use it as a **Docker on Docker** devcontainer:

```jsonc
// .devcontainer/devcontainer.json
{
  "build": {
    "dockerfile": "Dockerfile"
  },
  "overrideCommand": false,
  "mounts": [
    "source=/var/run/docker.sock,target=/var/run/docker.sock,type=bind"
  ],
  "runArgs": ["--network=host"]
}
```

Or, to use it as a **Docker in Docker** devcontainer:

```jsonc
// .devcontainer/devcontainer.json
{
  "build": {
    "dockerfile": "Dockerfile"
  },
  "overrideCommand": false,
  "privileged": true
}
```

### Jenkinsfile dockerfile agent

<details>
  <summary>Click here to show</summary>

When running as a `Jenkinsfile` docker agent, Jenkins will run the container as the host user instead of the default `devcontainer` user.

This image comes with [`fixuid`](https://github.com/boxboat/fixuid), which will automatically fix the user and group IDs of the `devcontainer` user that comes with the image to match the host user.

[`fixdockergid`](https://github.com/felipecrs/fixdockergid) is also included, which will fix the group ID of the `docker` group to match the host's `docker` group ID.

This ensures file permissions are correct when running as a `Jenkinsfile` dockerfile agent, as well as ensures `docker` from within the container still works in docker on docker mode.

Considering you have a `.devcontainer/Dockerfile` like this:

```dockerfile
# .devcontainer/Dockerfile
FROM ghcr.io/felipecrs/devcontainer

# Install your project's dependencies
RUN pkgx install openjdk.org@21 maven.apache.org@3 \
    && java --version \
    && mvn --version
```

To run it in Jenkins through Docker on Docker mode (recommended if your Jenkins provides [ephemeral Docker in Docker agents](../jenkins-agent-dind)):

```groovy
// Jenkinsfile
pipeline {
  agent {
    dockerfile {
      dir '.devcontainer'
      // --group-add=docker: is needed when using docker exec to run commands,
      // which is what Jenkins does when running as a Jenkinsfile docker agent
      args '--volume=/var/run/docker.sock:/var/run/docker.sock --network=host --group-add=docker'
    }
  }
  stages {
    stage('Verify docker works') {
      steps {
        sh 'docker version'
      }
    }
  }
}
```

Alternatively, you can use the Docker in Docker mode (recommended in case your Jenkins provides static agents):

```groovy
// Jenkinsfile
pipeline {
  agent {
    dockerfile {
      dir '.devcontainer'
      args '--privileged --group-add=docker'
    }
  }
  stages {
    stage('Verify docker works') {
      steps {
        sh 'docker version'
      }
    }
  }
}
```

</details>

### Accessing the devcontainer through SSH

<details>
  <summary>Click here to show</summary>

This image comes with a SSH server installed and configured, but it comes disabled by default.

To enable it, you need to add the `SSHD_ENABLED=true` environment variable when running the container.

The SSHD server will run on port `22` and you can use the `devcontainer` user to login, without any password.

The image also comes with a convenience script at `/ssh-command/get.sh` that will output the SSH command to connect to the container, which you can use to connect to the container through SSH. Example:

```sh
docker run --rm -it --privileged \
  -e SSHD_ENABLED=true \
  -e NODE_NAME=$(hostname -I | awk '{ print $1 }') \
  -e SSHD_PORT=2222 \
  -p 2222:22 \
  ghcr.io/felipecrs/devcontainer \
  /ssh-command/get.sh
```

![Example of SSH command](https://user-images.githubusercontent.com/29582865/203834385-1fb78d1d-5725-4074-8308-83a7b0ec818b.png)

</details>
