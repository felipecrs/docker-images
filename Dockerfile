FROM circleci/buildpack-deps:bionic-dind

USER root

RUN apt-get update && \
    apt-get install -y software-properties-common

RUN add-apt-repository -y ppa:git-core/ppa && \
  apt-get update && \
  apt-get install -y git

RUN curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | bash && \
  apt-get install -y git-lfs

RUN apt-get update && apt-get install -y openjdk-8-jdk

RUN apt-get update && apt-get install -y supervisor

RUN rm -rf /var/lib/apt/lists/*

ARG VERSION=3.35
ARG user=jenkins
ARG group=jenkins
ARG uid=1000
ARG gid=1000

RUN groupadd -g ${gid} ${group}
RUN useradd -c "Jenkins user" -d /home/${user} -u ${uid} -g ${gid} -m ${user}
RUN usermod --append --groups docker ${user}
RUN echo 'jenkins ALL=NOPASSWD: ALL' >> /etc/sudoers.d/50-jenkins

LABEL Description="This is a base image, which provides the Jenkins agent executable (agent.jar)" Vendor="Jenkins project" Version="${VERSION}"

ARG AGENT_WORKDIR=/home/${user}/agent

RUN curl --create-dirs -fsSLo /usr/share/jenkins/agent.jar https://repo.jenkins-ci.org/public/org/jenkins-ci/main/remoting/${VERSION}/remoting-${VERSION}.jar \
  && chmod 755 /usr/share/jenkins \
  && chmod 644 /usr/share/jenkins/agent.jar \
  && ln -sf /usr/share/jenkins/agent.jar /usr/share/jenkins/slave.jar

USER ${user}
ENV AGENT_WORKDIR=${AGENT_WORKDIR}
RUN mkdir /home/${user}/.jenkins && mkdir -p ${AGENT_WORKDIR}

VOLUME /home/${user}/.jenkins
VOLUME ${AGENT_WORKDIR}
WORKDIR /home/${user}

COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY entrypoint.sh entrypoint.sh
ENTRYPOINT [ "./entrypoint.sh" ]
CMD [ "/bin/bash" ]
