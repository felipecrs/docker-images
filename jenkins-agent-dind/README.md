# Jenkins Agent with Docker in Docker

[![CI](https://github.com/felipecrs/docker-images/workflows/ci/badge.svg?branch=master&event=push)](https://github.com/felipecrs/docker-images/actions?query=workflow%3Aci+branch%3Amaster+event%3Apush)
[![Docker Image Size](https://ghcr-badge.egpl.dev/felipecrs/jenkins-agent-dind/size)](https://github.com/felipecrs/docker-images/pkgs/container/jenkins-agent-dind)

A Docker in Docker image to provide fully ephemeral Jenkins agents.

- Image tags: [`ghcr.io/felipecrs/jenkins-agent-dind`](https://github.com/felipecrs/docker-images/pkgs/container/jenkins-agent-dind)

> [!IMPORTANT]
> This image used to be uploaded to Docker Hub as `felipecrs/jenkins-agent` but it no longer is. Please update to the new tag `ghcr.io/felipecrs/jenkins-agent-dind`.

## Features

- **Based on Ubuntu 24.04 Noble Numbat**: a more common distribution to run your workload on.
- Fully functional **Docker in Docker**: run `docker` commands isolated from the host Docker daemon.
- Also supports **Docker on Docker**: you can choose to share the host's Docker daemon to avoid the overhead of running a nested Docker daemon.
- Works as a Jenkins Agent out-of-the-box: run ephemeral build containers by using the Docker Plugin or Kubernetes Plugin on Jenkins. Works as the official [`jenkins/inbound-agent`](https://github.com/jenkinsci/docker-agent/blob/master/README_inbound-agent.md).
- Several common packages installed: run your generic workflow without needing to install additional packages.
- Bundles [**`pkgx`**](https://pkgx.sh), a convenient package manager that allows you to **easily and quickly install the necessary tools for your project**. Example: `pkgx install node@18 npm@10`.
- Facilitates debugging by providing an **opt-in SSH server** for your builds. Read more about it [here](#accessing-the-container-through-ssh).
- Can also be used as a [**devcontainer**](https://containers.dev/), ensuring **both your development environment and your CI/CD environment are the same**. Read more about it [here](#devcontainer).

## Usage

### Command line

Spin this image in your terminal, if you want to play with it:

```sh
# -it: allows to interact with the container
# --rm: removes the container and its volumes after exiting
# --privileged: needed for running Docker in Docker
docker run -it --rm --privileged ghcr.io/felipecrs/jenkins-agent-dind
```

Alternatively, you can use the Docker on Docker mode:

```sh
# --volume: shares the host's Docker socket with the container
# --network=host: allows to access ports from other containers running on the host
docker run -it --rm --volume=/var/run/docker.sock:/var/run/docker.sock --network=host \
  ghcr.io/felipecrs/jenkins-agent-dind
```

### Agent template with the [Docker Plugin](https://plugins.jenkins.io/docker-plugin/) on Jenkins

<details>
  <summary>Click here to show</summary>

> [!WARNING]
> The image tag in this screenshot is outdated. The updated tag is `ghcr.io/felipecrs/jenkins-agent-dind`.

![Sample Agent Template configuration](https://user-images.githubusercontent.com/29582865/106769145-66379180-661b-11eb-93e3-5a7742eb46c0.png)

</details>

### Pod template with the [Kubernetes Plugin](https://plugins.jenkins.io/kubernetes/) on Jenkins

<details>
  <summary>Click here to show</summary>

The following is the Pod definition that you can use as a Pod template with the Kubernetes Plugin.

```yaml
apiVersion: v1
kind: Pod
spec:
  containers:
    - name: jnlp
      image: ghcr.io/felipecrs/jenkins-agent-dind
      imagePullPolicy: Always
      securityContext:
        privileged: true
      workingDir: /home/jenkins/agent
      volumeMounts:
        - mountPath: /home/jenkins/agent
          name: workspace-volume
      terminationMessagePolicy: FallbackToLogsOnError
  hostNetwork: false
  automountServiceAccountToken: false
  enableServiceLinks: false
  dnsPolicy: Default
  restartPolicy: Never
  terminationGracePeriodSeconds: 30
  volumes:
    - name: workspace-volume
      emptyDir: {}
```

</details>

### Jenkinsfile docker agent

<details>
  <summary>Click here to show</summary>

When running as a `Jenkinsfile` docker agent, Jenkins will run the container as the host user instead of the default `jenkins` user.

This image comes with [`fixuid`](https://github.com/boxboat/fixuid), which will automatically fix the user and group IDs of the `jenkins` user that comes with the image to match the host user.

[`fixdockergid`](https://github.com/felipecrs/fixdockergid) is also included, which will fix the group ID of the `docker` group to match the host's `docker` group ID when running in Docker on Docker mode.

This ensures file permissions are correct when running as a `Jenkinsfile` docker agent, as well as ensures `docker` from within the container still works.

To run in Docker in Docker mode (recommended if your outter Jenkins agents are static):

```groovy
// Jenkinsfile
pipeline {
  agent {
    docker {
      image 'ghcr.io/felipecrs/jenkins-agent-dind'
      alwaysPull true
      // --group-add=docker: is needed when using docker exec to run commands,
      // which is what Jenkins does when running as a Jenkinsfile docker agent
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

Alternatively, you can use the Docker on Docker mode (recommended if your outter Jenkins agents are already ephemeral):

```groovy
// Jenkinsfile
pipeline {
  agent {
    docker {
      image 'ghcr.io/felipecrs/jenkins-agent-dind'
      alwaysPull true
      args '--volume=/var/run/docker.sock:/var/run/docker.sock --group-add=docker --network=host'
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

### Accessing the container through SSH

<details>
  <summary>Click here to show</summary>

This image comes with a SSH server installed and configured, but it comes disabled by default.

To enable it, you need to add the `SSHD_ENABLED=true` environment variable when running the container.

The SSHD server will run on port `22` and you can use the `jenkins` user to login, without any password.

The image also comes with a convenience script at `/ssh-command/get.sh` that will output the SSH command to connect to the container, which you can use to connect to the container through SSH. Example:

```sh
docker run --rm -it --privileged \
  -e SSHD_ENABLED=true \
  -e NODE_NAME=$(hostname -I | awk '{ print $1 }') \
  -e SSHD_PORT=2222 \
  -p 2222:22 \
  ghcr.io/felipecrs/jenkins-agent-dind \
  /ssh-command/get.sh
```

![Example of SSH command](https://user-images.githubusercontent.com/29582865/203834385-1fb78d1d-5725-4074-8308-83a7b0ec818b.png)

</details>

### Automatically expose SSH access for all builds with the Kubernetes Plugin

<details>
  <summary>Click here to show</summary>

You can use a Kubernetes Pod Template to automatically expose SSH access for all builds.

First you'll need to have [`dynamic-hostports`](https://github.com/felipecrs/dynamic-hostports-k8s) installed in your cluster. You can install it with the following command:

```sh
kubectl apply -f https://github.com/felipecrs/dynamic-hostports-k8s/raw/master/deploy.yaml
```

Then you can use the following Pod Template:

```yaml
apiVersion: v1
kind: Pod
metadata:
  labels:
    dynamic-hostports: "22"
spec:
  containers:
    - name: jnlp
      image: ghcr.io/felipecrs/jenkins-agent-dind
      imagePullPolicy: Always
      env:
        - name: SSHD_ENABLED
          value: "true"
      ports:
        - containerPort: 22
      securityContext:
        privileged: true
      workingDir: /home/jenkins/agent
      volumeMounts:
        - mountPath: /home/jenkins/agent
          name: workspace-volume
        - name: podinfo
          mountPath: /ssh-command/podinfo
          readonly: true
      terminationMessagePolicy: FallbackToLogsOnError
  hostNetwork: false
  automountServiceAccountToken: false
  enableServiceLinks: false
  restartPolicy: Never
  terminationGracePeriodSeconds: 30
  volumes:
    - name: workspace-volume
      emptyDir: {}
    - name: podinfo
      downwardAPI:
        items:
          - path: "sshd-port"
            fieldRef:
              fieldPath: metadata.annotations['dynamic-hostports.k8s/22']
          - path: "node-fqdn"
            fieldRef:
              fieldPath: metadata.annotations['dynamic-hostports.k8s/node-fqdn']
```

And here is an example of a Jenkinsfile:

```groovy
// Jenkinsfile
pipeline {
  agent any
  options {
    ansiColor('xterm')
  }
  stages {
    stage ('Get SSH command') {
      steps {
        sh '/ssh-command/get.sh'
      }
    }
  }
}
```

It also works if you use a nested Docker agent:

```groovy
// Jenkinsfile
pipeline {
  agent {
    docker {
      image 'ghcr.io/felipecrs/jenkins-agent-dind'
      alwaysPull true
      args '--volume=/ssh-command:/ssh-command --volume=/var/run/docker.sock:/var/run/docker.sock --group-add=docker --network=host'
    }
  }
  options {
    ansiColor('xterm')
  }
  stages {
    stage ('Get SSH command') {
      steps {
        sh '/ssh-command/get.sh'
      }
    }
  }
}
```

</details>

### Automatically expose SSH access for all builds as a Jenkinsfile docker agent

<details>
  <summary>Click here to show</summary>

```groovy
// Jenkinsfile

// Generate an "unique" port for SSHD
env.SSHD_PORT = new Random(env.BUILD_TAG.hashCode()).nextInt(23000 - 22000) + 22000

pipeline {
  agent {
    agent {
      docker {
        image 'ghcr.io/felipecrs/jenkins-agent-dind:latest'
        args "--privileged --group-add=docker --env=SSHD_ENABLED=true --publish=${env.SSHD_PORT}:22"
      }
    }
  }
  options {
    ansiColor('xterm')
  }
  stages {
    stage ('Get SSH command') {
      steps {
        sh '/ssh-command/get.sh'
      }
    }
  }
}
```

</details>

### Devcontainer

It is a good practice to run your development environment in a container, so you can have a consistent environment across your team.

It is even better if you can run the same container in your CI/CD pipeline, so you can be sure that your build will behave the same way as your development environment.

While this image functions as a devcontainer, I recommend you take a look at my [devcontainer](../devcontainer) image, which is a subset of this image specifically tailored to be used as a devcontainer and can also be used as a [Jenkinsfile Dockerfile agent](../devcontainer#jenkinsfile-dockerfile-agent).
