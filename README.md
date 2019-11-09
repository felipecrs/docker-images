# Jenkins Agent with Docker installed

This image is based on [official Jenkins Agent](https://hub.docker.com/r/jenkins/slave), plus it has Docker installed and [a good way](https://github.com/sudo-bmitch/jenkins-docker) to fix the permissions error when acessing `/var/run/docker.sock` from within the container using `jenkins` user.