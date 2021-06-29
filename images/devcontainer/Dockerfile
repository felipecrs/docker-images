FROM mcr.microsoft.com/vscode/devcontainers/base:ubuntu-20.04 AS base

SHELL [ "/bin/bash", "-euxo", "pipefail", "-c" ]

ENV USER="vscode"
ARG USERNAME="${USER}"
ENV HOME="/home/${USER}"
USER "${USER}"
WORKDIR "${HOME}"
RUN sudo chsh "$USER" -s /usr/bin/zsh

ARG DEBIAN_FRONTEND="noninteractive"

RUN sudo apt-get update; \
    sudo apt-get install --no-install-recommends -y software-properties-common; \
    sudo add-apt-repository -y ppa:git-core/ppa; \
    sudo apt-get install --no-install-recommends -y build-essential git \
    # pyenv dependencies \
    build-essential libssl-dev zlib1g-dev libbz2-dev \
    libreadline-dev libsqlite3-dev wget curl llvm libncurses5-dev libncursesw5-dev \
    xz-utils tk-dev libffi-dev liblzma-dev python-openssl git; \
    sudo rm -rf /var/lib/apt/lists/*;

# script-library options
ARG SCRIPT_LIBRARY_VERSION=master
ARG SCRIPT_LIBRARY_URL=https://raw.githubusercontent.com/microsoft/vscode-dev-containers/${SCRIPT_LIBRARY_VERSION}/script-library

# Install docker cli, kubectl, helm and kind
RUN sudo bash -c "$(curl -fsSL "$SCRIPT_LIBRARY_URL/docker-debian.sh")" -- true "/var/run/docker-host.sock" "/var/run/docker.sock" automatic false; \
    # Add docker-host group \
    sudo groupadd docker-host; \
    sudo usermod -aG docker-host "$USERNAME"; \
    sudo bash -c "$(curl -fsSL "$SCRIPT_LIBRARY_URL/kubectl-helm-debian.sh")"; \
    # Install kind \
    KIND_URL="$(curl -fsSL https://api.github.com/repos/kubernetes-sigs/kind/releases/latest | jq -er '.assets[] | select(.name | contains("kind-linux-amd")) | .browser_download_url')"; \
    sudo curl -fsSL -o /usr/local/bin/kind "$KIND_URL"; \
    sudo chmod +x /usr/local/bin/kind; \
    # Install tini \
    version=$(curl -fsSL https://api.github.com/repos/krallin/tini/releases/latest | jq .tag_name -er); \
    sudo curl -fsSL -o /init "https://github.com/krallin/tini/releases/download/${version}/tini"; \
    sudo chmod +x /init; \
    # Clean up
    sudo apt-get autoremove -y && sudo apt-get clean -y && sudo rm -rf /var/lib/apt/lists/* /tmp/library-scripts/
COPY ./scripts/localpath /usr/local/bin/
ENTRYPOINT [ "/init", "--", "/usr/local/share/docker-init.sh" ]
CMD [ "sleep", "infinity" ]

# Install pyenv
ENV PYENV_ROOT="${HOME}/.pyenv"
ENV PATH="${PYENV_ROOT}/bin:${PYENV_ROOT}/shims:${PATH}"
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

RUN sudo bash -c "$(curl -fsSL "$SCRIPT_LIBRARY_URL/github-debian.sh")"; \
    # Clean up \
    sudo apt-get autoremove -y && sudo apt-get clean -y && sudo rm -rf /var/lib/apt/lists/* /tmp/library-scripts/

FROM base AS python

RUN pyenv latest install; \
    pyenv latest global

FROM base AS node

RUN volta install node; \
    volta install npm; \
    volta install yarn
