ARG BASE_IMAGE="base"

FROM mcr.microsoft.com/vscode/devcontainers/base:ubuntu-20.04 AS base

SHELL [ "/bin/bash", "-euxo", "pipefail", "-c" ]

ARG USER="vscode"
ARG USERNAME="${USER}"
ARG HOME="/home/${USER}"
USER ${USER}

ARG DEBIAN_FRONTEND="noninteractive"

RUN sudo apt-get update; \
    sudo apt-get install --no-install-recommends -y software-properties-common; \
    sudo add-apt-repository -y ppa:git-core/ppa; \
    sudo apt-get install --no-install-recommends -y build-essential git \
    # pyenv dependencies
    build-essential libssl-dev zlib1g-dev libbz2-dev \
    libreadline-dev libsqlite3-dev wget curl llvm libncurses5-dev libncursesw5-dev \
    xz-utils tk-dev libffi-dev liblzma-dev python-openssl git; \
    sudo rm -rf /var/lib/apt/lists/*;

# Install pyenv
ENV PYENV_ROOT="${HOME}/.pyenv"
ENV PATH="${PYENV_ROOT}/bin:${PATH}"
RUN bash -c "$(curl -fsSL https://github.com/pyenv/pyenv-installer/raw/master/bin/pyenv-installer)"; \
    printf '%s\n' 'eval "$(pyenv init -)"' | sudo tee -a /etc/bash.bashrc /etc/zsh/zshrc; \
    git clone --depth 1 https://github.com/momo-lab/xxenv-latest.git "$(pyenv root)/plugins/xxenv-latest"

# Install stuff using script-library's scripts

# script-library options
ARG SCRIPT_LIBRARY_VERSION=master
ARG SCRIPT_LIBRARY_URL=https://raw.githubusercontent.com/microsoft/vscode-dev-containers/${SCRIPT_LIBRARY_VERSION}/script-library

# Install docker cli, kubectl, helm and kind
RUN sudo bash -c "$(curl -fsSL "$SCRIPT_LIBRARY_URL/docker-debian.sh")" -- true "/var/run/docker-host.sock" "/var/run/docker.sock" automatic false; \
    sudo bash -c "$(curl -fsSL "$SCRIPT_LIBRARY_URL/kubectl-helm-debian.sh")"; \
    # Install kind
    KIND_URL="$(curl -fsSL https://api.github.com/repos/kubernetes-sigs/kind/releases/latest | jq -r '.assets[] | select(.name | contains("kind-linux-amd")) | .browser_download_url')"; \
    sudo curl -fsSL -o /usr/local/bin/kind "$KIND_URL"; \
    sudo chmod +x /usr/local/bin/kind; \
    # Clean up
    sudo apt-get autoremove -y && sudo apt-get clean -y && sudo rm -rf /var/lib/apt/lists/* /tmp/library-scripts/
ENTRYPOINT [ "/usr/local/share/docker-init.sh" ]
CMD [ "sleep", "infinity" ]

# Install nvm and yarn
# script-library's node options
ENV NVM_DIR="${HOME}/.nvm"
ENV NVM_SYMLINK_CURRENT="true" \
    PATH="${NVM_DIR}/current/bin:${PATH}"
RUN sudo bash -c "$(curl -fsSL "$SCRIPT_LIBRARY_URL/node-debian.sh")" -- "${NVM_DIR}" none; \
    # Clean up
    sudo apt-get autoremove -y && sudo apt-get clean -y && sudo rm -rf /var/lib/apt/lists/* /tmp/library-scripts/

# Install SDKMAN!
ENV SDKMAN_DIR="${HOME}/.sdkman"
ENV PATH="${SDKMAN_DIR}/bin:${SDKMAN_DIR}/candidates/java/current/bin:${PATH}"
RUN sudo bash -c "$(curl -fsSL "$SCRIPT_LIBRARY_URL/java-debian.sh")" -- none "${SDKMAN_DIR}"; \
    # Clean up
    sudo apt-get autoremove -y && sudo apt-get clean -y && sudo rm -rf /var/lib/apt/lists/* /tmp/library-scripts/

# https://github.com/microsoft/vscode-remote-release/issues/4281
# SHELL [ "/bin/bash", "-ic"]

FROM ${BASE_IMAGE} as github

RUN sudo bash -c "$(curl -fsSL "$SCRIPT_LIBRARY_URL/github-debian.sh")"; \
    # Clean up
    sudo apt-get autoremove -y && sudo apt-get clean -y && sudo rm -rf /var/lib/apt/lists/* /tmp/library-scripts/

FROM ${BASE_IMAGE} AS python

RUN pyenv latest install; \
    pyenv latest global

FROM ${BASE_IMAGE} AS node

RUN nvm install --lts
