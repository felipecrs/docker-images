FROM mcr.microsoft.com/vscode/devcontainers/base:ubuntu-20.04 AS base

SHELL [ "/bin/bash", "-euxo", "pipefail", "-c" ]

ENV USER="vscode"
ARG USERNAME="${USER}"
ENV HOME="/home/${USER}"
ENV PATH="${HOME}/.local/bin:${PATH}"
USER "${USER}"
WORKDIR "${HOME}"
RUN sudo chsh "$USER" -s /usr/bin/zsh

ARG DEBIAN_FRONTEND="noninteractive"

RUN sudo apt-get update; \
    sudo apt-get install --no-install-recommends -y software-properties-common; \
    sudo add-apt-repository --no-update -y ppa:git-core/ppa; \
    sudo add-apt-repository --no-update -y ppa:deadsnakes/ppa; \
    sudo apt-get update; \
    sudo apt-get install --no-install-recommends -y build-essential git tree parallel \
    # pyenv dependencies \
    build-essential libssl-dev zlib1g-dev libbz2-dev \
    libreadline-dev libsqlite3-dev wget curl llvm libncurses5-dev libncursesw5-dev \
    xz-utils tk-dev libffi-dev liblzma-dev python-openssl git; \
    sudo rm -rf /var/lib/apt/lists/*;

# script-library options
ARG SCRIPT_LIBRARY_VERSION=HEAD
ARG SCRIPT_LIBRARY_URL=https://raw.githubusercontent.com/microsoft/vscode-dev-containers/${SCRIPT_LIBRARY_VERSION}/script-library

# Install docker cli, kubectl, helm and kind
RUN sudo bash -c "$(curl -fsSL "$SCRIPT_LIBRARY_URL/docker-debian.sh")" -- true "/var/run/docker-host.sock" "/var/run/docker.sock" automatic false; \
    sudo apt-get install -y docker-buildx-plugin; \
    sudo bash -c "$(curl -fsSL "$SCRIPT_LIBRARY_URL/kubectl-helm-debian.sh")"; \
    # Install kind \
    version=$(basename "$(curl -fsSL -o /dev/null -w "%{url_effective}" https://github.com/kubernetes-sigs/kind/releases/latest)"); \
    sudo curl -fsSL -o /usr/local/bin/kind "https://github.com/kubernetes-sigs/kind/releases/download/${version}/kind-linux-amd64"; \
    sudo chmod +x /usr/local/bin/kind; \
    # Install retry \
    version=$(basename "$(curl -fsSL -o /dev/null -w "%{url_effective}" "https://github.com/kadwanev/retry/releases/latest")"); \
    curl -fsSL "https://github.com/kadwanev/retry/releases/download/${version}/retry-${version}.tar.gz" | \
        sudo tar -C /usr/local/bin -xzf -; \
    # Install tini \
    version=$(basename "$(curl -fsSL -o /dev/null -w "%{url_effective}" https://github.com/krallin/tini/releases/latest)"); \
    sudo curl -fsSL -o /init "https://github.com/krallin/tini/releases/download/${version}/tini"; \
    sudo chmod +x /init; \
    # Clean up
    sudo apt-get autoremove -y && sudo apt-get clean -y && sudo rm -rf /var/lib/apt/lists/* /tmp/library-scripts/

# Install dond-shim (https://github.com/felipecrs/docker-on-docker-shim)
ARG DOCKER_PATH="/usr/bin/docker"
ARG DOND_SHIM_REVISION="HEAD"
RUN sudo mv -f "${DOCKER_PATH}" "${DOCKER_PATH}.orig" && \
    sudo curl -fsSL "https://github.com/felipecrs/docker-on-docker-shim/raw/${DOND_SHIM_REVISION}/dond" \
    --output "${DOCKER_PATH}" && \
    sudo chmod +x "${DOCKER_PATH}"

ENTRYPOINT [ "/init", "--", "/usr/local/share/docker-init.sh" ]
CMD [ "sleep", "infinity" ]

# Install pyenv
ENV PYENV_ROOT="${HOME}/.pyenv"
ENV PATH="${PYENV_ROOT}/bin:${PYENV_ROOT}/shims:${PATH}"
# hadolint ignore=SC2016
RUN bash -c "$(curl -fsSL https://github.com/pyenv/pyenv-installer/raw/master/bin/pyenv-installer)"; \
    printf '%s\n' 'eval "$(pyenv init -)"' | sudo tee -a /etc/bash.bashrc /etc/zsh/zshrc; \
    git clone --depth 1 https://github.com/momo-lab/xxenv-latest.git "$(pyenv root)/plugins/xxenv-latest"

# Install volta
ENV VOLTA_HOME="${HOME}/.volta"
ENV PATH="${VOLTA_HOME}/bin:${PATH}"
RUN bash -c "$(curl -fsSL https://get.volta.sh)" -- --skip-setup

# Install SDKMAN!
ENV SDKMAN_DIR="/opt/sdkman"
ENV PATH="${SDKMAN_DIR}/bin:${SDKMAN_DIR}/candidates/java/current/bin:${PATH}"
RUN sudo bash -c "$(curl -fsSL "$SCRIPT_LIBRARY_URL/java-debian.sh")" -- none "${SDKMAN_DIR}"; \
    # Clean up
    sudo apt-get autoremove -y && sudo apt-get clean -y && sudo rm -rf /var/lib/apt/lists/* /tmp/library-scripts/

# https://github.com/microsoft/vscode-remote-release/issues/4281
# SHELL [ "/bin/bash", "-ic"]

FROM base as github

ARG GITHUB_CLI_FEATURE_REVISION="7e6dd4b07089855b491da02ea66666505ebda541"
RUN sudo bash -c "$(curl -fsSL "https://raw.githubusercontent.com/devcontainers/features/${GITHUB_CLI_FEATURE_REVISION}/src/github-cli/install.sh")"; \
    # Clean up \
    sudo apt-get autoremove -y && sudo apt-get clean -y && sudo rm -rf /var/lib/apt/lists/* /tmp/library-scripts/

FROM base AS python

RUN pyenv latest install; \
    pyenv latest global

FROM base AS node

RUN volta install node; \
    volta install npm; \
    volta install yarn
