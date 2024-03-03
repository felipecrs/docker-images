FROM ubuntu:22.04 AS base


# Build the init_as_root
FROM base AS init_as_root

# Install shc
RUN apt-get update; \
    apt-get install -y --no-install-recommends shc build-essential; \
    rm -rf /var/lib/apt/lists/*

RUN --mount=type=bind,source=scripts/init_as_root.sh,target=/init_as_root.sh \
    shc -S -r -f /init_as_root.sh -o /init_as_root; \
    chown root:root /init_as_root; \
    chmod 4755 /init_as_root


FROM scratch AS rootfs

COPY --from=init_as_root /init_as_root /
COPY rootfs /


FROM base

ENV NON_ROOT_USER="jenkins"
ARG NON_ROOT_UID="1000"
ARG NON_ROOT_HOME="/home/${NON_ROOT_USER}"

ENV PATH="${NON_ROOT_HOME}/.local/bin:${PATH}"
ENV JAVA_HOME="/usr/lib/jvm/temurin-11-jdk-amd64"
ENV AGENT_WORKDIR="${NON_ROOT_HOME}/agent"

# locale and encoding
ENV LANG="en_US.UTF-8"
ENV LANGUAGE="en_US:en"
ENV LC_ALL="en_US.UTF-8"
ENV TZ="Etc/UTC"

ENV CI="true"

RUN --mount=type=bind,source=scripts/prepare_image.sh,target=/prepare_image.sh \
    /prepare_image.sh

COPY --from=rootfs / /

# use non-root user with sudo when needed
USER "${NON_ROOT_USER}:${NON_ROOT_USER}"

WORKDIR "${AGENT_WORKDIR}"

VOLUME "${AGENT_WORKDIR}"

# Fails if cont-init and fix-attrs fails
ENV S6_BEHAVIOUR_IF_STAGE2_FAILS="2"
# Wait for services before running CMD
ENV S6_CMD_WAIT_FOR_SERVICES="1"
# Give 15s for services to start
ENV S6_CMD_WAIT_FOR_SERVICES_MAXTIME="15000"
# Give 15s for services to stop
ENV S6_SERVICES_GRACETIME="15000"
# Honor container env on CMD
ENV S6_KEEP_ENV="1"

ENTRYPOINT [ "/entrypoint.sh" ]
CMD [ "jenkins-agent" ]
