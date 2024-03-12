FROM ubuntu:jammy-20240227 AS ubuntu


# Build the init_as_root
FROM ubuntu AS init_as_root

SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]

# hadolint ignore=DL3008
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


FROM ubuntu AS base

## default locale, encoding, and timezone
ENV LANG="en_US.UTF-8"
ENV LANGUAGE="en_US:en"
ENV LC_ALL="en_US.UTF-8"
ENV TZ="Etc/UTC"
## s6-overlay
# Fails the container if any service fails to start
ENV S6_BEHAVIOUR_IF_STAGE2_FAILS="2"
# Waits for all services to start before running CMD
ENV S6_CMD_WAIT_FOR_SERVICES="1"
# Honors the timeout-up for each service
ENV S6_CMD_WAIT_FOR_SERVICES_MAXTIME="0"
# Honors container's environment variables on CMD
ENV S6_KEEP_ENV="1"
# Applies services conditions to decide which services should start
ENV S6_STAGE2_HOOK="/apply_services_conditions.sh"

RUN --mount=type=bind,source=scripts/prepare_image.sh,target=/prepare_image.sh \
    /prepare_image.sh

COPY --from=rootfs / /

ENTRYPOINT [ "/entrypoint.sh" ]
CMD []


FROM base AS non-root-user

ARG NON_ROOT_USER="devcontainer"
ENV NON_ROOT_USER="${NON_ROOT_USER}"
ARG NON_ROOT_UID="1000"
ENV NON_ROOT_HOME="/home/${NON_ROOT_USER}"
ENV PATH="${NON_ROOT_HOME}/.local/bin:${PATH}"

RUN --mount=type=bind,source=scripts/prepare_non_root_user.sh,target=/prepare_non_root_user.sh \
    /prepare_non_root_user.sh


FROM non-root-user

USER "${NON_ROOT_USER}"

WORKDIR "${NON_ROOT_HOME}"

VOLUME [ "/var/lib/docker" ]

LABEL devcontainer.metadata='{"overrideCommand":false}'
