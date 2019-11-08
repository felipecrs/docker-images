# https://hub.docker.com/r/jenkins/slave/dockerfile
FROM jenkins/slave

USER root

# https://github.com/tianon/gosu/blob/master/INSTALL.md
RUN set -eux; \
	apt-get update; \
	apt-get install -y gosu; \
	rm -rf /var/lib/apt/lists/*; \
# verify that the binary works
	gosu nobody true

# https://github.com/jenkinsci/jnlp-agents/blob/master/docker/Dockerfile
ARG DOCKER_VERSION=19.03.4
ARG DOCKER_COMPOSE_VERSION=1.24.1
RUN curl -fsSL https://download.docker.com/linux/static/stable/`uname -m`/docker-$DOCKER_VERSION.tgz | tar --strip-components=1 -xz -C /usr/local/bin docker/docker
RUN curl -fsSL https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_VERSION/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose && chmod +x /usr/local/bin/docker-compose
# https://docs.docker.com/install/linux/linux-postinstall/
RUN groupadd docker; \
    usermod -aG docker jenkins
# Fix mkdir error
# RUN chown -R 777 /home/jenkins

# https://github.com/sudo-bmitch/jenkins-docker/blob/master/Dockerfile
# entrypoint is used to update docker gid and revert back to jenkins user
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
