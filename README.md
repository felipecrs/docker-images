# Jenkins Agent with Docker in Docker

[![CI](https://github.com/felipecrs/jenkins-agent-dind/workflows/ci/badge.svg?branch=master&event=push)](https://github.com/felipecrs/jenkins-agent-dind/actions?query=workflow%3Aci+branch%3Amaster+event%3Apush)
[![Docker Image Size](https://ghcr-badge.egpl.dev/felipecrs/jenkins-agent-dind/size)](https://github.com/felipecrs/jenkins-agent-dind/pkgs/container/jenkins-agent-dind)

A full fledged Docker in Docker image to act as a Jenkins Agent. Based on `ubuntu`, it is a mashup of [`jenkins/inbound-agent`](https://github.com/jenkinsci/docker-inbound-agent) with [`docker:dind`](https://github.com/docker-library/docker).

- Docker image: [`ghcr.io/felipecrs/jenkins-agent-dind`](https://github.com/felipecrs/jenkins-agent-dind/pkgs/container/jenkins-agent-dind)

## Features

- Based on **Ubuntu 22.04 Jammy Jellyfish**: a more common OS to run your builds.
- Several common packages installed: run your builds without hassle.
- Fully working Docker in Docker: run your `docker build` commands isolated from the host Docker daemon.
- Act just as a Jenkins Agent out-of-the-box: run ephemeral build containers by using the Docker Plugin or Kubernetes Plugin on Jenkins. Works as the official `inbound-agent`.
- Includes [`pkgx`](https://pkgx.sh), a convenient package manager that allows you to easily install the necessary tools for your project. For example, you can use `pkgx install node@18` to install Node.js version 18.
- Facilitates debugging by providing an opt-in SSH server for your builds. Read more about it [here](#accessing-the-image-through-ssh).

## Usage

### Command line

Spin this agent in shell, if you want to play with it:

```sh
# -it: allows to interact with the container
# --rm: removes the container and its volumes after exiting
# --privileged: needed for running Docker in Docker
docker run -it --rm --privileged ghcr.io/felipecrs/jenkins-agent-dind bash
```

### Agent Template in Docker Cloud configuration on Jenkins

> [!WARNING]  
> The image tag in this screenshot is outdated. The updated tag is `ghcr.io/felipecrs/jenkins-agent-dind:latest`.

![Sample Agent Template configuration](https://user-images.githubusercontent.com/29582865/106769145-66379180-661b-11eb-93e3-5a7742eb46c0.png)

### Kubernetes Plugin Pod Template

The following is the Pod definition that you can use as a Pod template with the Kubernetes Plugin.

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

### As a Jenkinsfile docker agent

When running as a Jenkinsfile docker agent, Jenkins will run the container as the host user instead of the default `jenkins` user.

But this image comes with [`fixuid`](https://github.com/boxboat/fixuid), which will automatically fix the user and group IDs of the `jenkins` user that comes with the image to match the host user.

This ensures file permissions are correct when running as a Jenkinsfile docker agent, as well as ensures `docker` from within the container still works.

```groovy
pipeline {
  agent {
    docker {
      image 'ghcr.io/felipecrs/jenkins-agent-dind:latest'
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

### Accessing the image through SSH

The image comes with SSHD installed and configured, but it does not start by default. To enable it, you need to add the `SSHD_ENABLED=true` environment variable when running the container.

The SSHD server will run on port `22` and you can use the `jenkins` user to login, without any password.

#### Automatically expose SSH access for all builds

The image comes with a convenience script at `/ssh-command/get.sh` that will output the SSH command to connect to the container, which you can use to connect to the container through SSH. Example:

![Example of SSH command](https://user-images.githubusercontent.com/29582865/203834385-1fb78d1d-5725-4074-8308-83a7b0ec818b.png)

##### Using Kubernetes Plugin

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
      image: ghcr.io/felipecrs/jenkins-agent-dind:{{ $agentTag }}
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
pipeline {
  agent {
    docker {
      image 'felipecrs/fixdockergid:latest'
      args '--volume=/ssh-command:/ssh-command --volume=/var/run/docker.sock:/var/run/docker.sock --group-add=docker'
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

##### Using as a Jenkinsfile docker agent

```groovy
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
