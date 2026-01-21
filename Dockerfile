FROM quay.io/fedora/fedora-toolbox:43

RUN ARCH=$(uname -m) && \
    case "${ARCH}" in \
        "x86_64") \
            KUBECTL_ARCH="amd64" && \
            VIRTCTL_ARCH="amd64" && \
            TEKTON_ARCH="64bit" && \
            SOPS_ARCH="x86_64" && \
            MC_ARCH="amd64" && \
            GO_ARCH="amd64" && \
            GCLOUD_ARCH="x86" \
        ;; \
        "aarch64") \
            KUBECTL_ARCH="arm64" && \
            VIRTCTL_ARCH="arm64" && \
            TEKTON_ARCH="ARM64" && \
            SOPS_ARCH="aarch64" && \
            MC_ARCH="arm64" && \
            GO_ARCH="arm64" && \
            GCLOUD_ARCH="arm" \
        ;; \
        *) echo "Unsupported architecture: ${ARCH}" && exit 1 ;; \
    esac && \
    VIRTCTL_VERSION=$(curl https://storage.googleapis.com/kubevirt-prow/release/kubevirt/kubevirt/stable.txt) && \
    curl -L "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/${KUBECTL_ARCH}/kubectl" > /usr/bin/kubectl && \
    curl -L https://github.com/kubevirt/kubevirt/releases/download/${VIRTCTL_VERSION}/virtctl-${VIRTCTL_VERSION}-linux-${VIRTCTL_ARCH} > /usr/bin/virtctl && \
    curl -L https://dl.min.io/client/mc/release/linux-${MC_ARCH}/mc > /usr/bin/mc && \
    chmod +x /usr/bin/kubectl /usr/bin/virtctl /usr/bin/mc && \
    dnf install -y https://github.com/tektoncd/cli/releases/download/v0.41.0/tektoncd-cli-0.41.0_Linux-${TEKTON_ARCH}.rpm && \
    dnf install -y https://github.com/getsops/sops/releases/download/v3.10.2/sops-3.10.2-1.${SOPS_ARCH}.rpm && \
    curl https://go.dev/dl/go1.24.4.linux-${GO_ARCH}.tar.gz -L > /go.tar.gz && \
    tar xzf /go.tar.gz  && \
    curl https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-linux-${GCLOUD_ARCH}.tar.gz -L > /gcloud.tar.gz && \
    cd /var && \
    tar xzf /gcloud.tar.gz && \
    rm /gcloud.tar.gz /go.tar.gz

RUN sed -i '/tsflags=nodocs/d' /etc/dnf/dnf.conf
RUN dnf install -y neovim sshd tmux zsh yq tig rbw htop age pinentry gh fzf buildah patch make gcc podman npm nodejs jq npm nodejs zstd skopeo rust-analyzer python-pip helm binutils-gold cargo git-lfs libbpf-devel clang podman-docker tailscale

# Go tool installs - separate layer for better caching (slow under QEMU emulation)
RUN GOROOT=/go GOPATH=/opt/go /go/bin/go install golang.org/x/tools/gopls@latest && \
    GOROOT=/go GOPATH=/opt/go /go/bin/go install github.com/ankitpokhrel/jira-cli/cmd/jira@v1.6.0 && \
    GOROOT=/go GOPATH=/opt/go /go/bin/go install sigs.k8s.io/kind@v0.30.0

RUN mkdir -p /opt/.ssh && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config && \
    echo "AuthorizedKeysFile /opt/.ssh/authorized_keys" >> /etc/ssh/sshd_config && \
    ssh-keygen -A && \
    npm -g install mcp-hub@latest && \
    npm -g install yaml-language-server && \
    npm install -g @anthropic-ai/claude-code

COPY conf/pam-sshd /etc/pam.d/sshd

RUN touch /opt/.ssh/authorized_keys && \
    curl -L https://github.com/kylape.keys >> /opt/.ssh/authorized_keys && \
    mkdir -p /opt/.config && \
    git -C /opt/.config clone https://github.com/kylape/neovim-config.git nvim && \
    ln -s /opt/.config/nvim/vimrc.vim /opt/.vimrc && \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" && \
    git clone https://github.com/joshskidmore/zsh-fzf-history-search ~/.oh-my-zsh/plugins/zsh-fzf-history-search && \
    mkdir -p /opt/secrets && \
    mkdir -p /opt/.config/gh && mkdir -p /opt/.config/ripgrep && \
    mkdir -p /opt/.gnupg && chmod 700 /opt/.gnupg

COPY conf/tmux.conf /opt/.tmux.conf
COPY conf/zshrc /opt/.zshrc
COPY conf/gitconfig /opt/.gitconfig
COPY conf/gh.yaml /opt/.config/gh/config.yml
COPY conf/ripgrep /opt/.config/ripgrep/config
COPY conf/move-in /opt/move-in
COPY conf/gpg-agent.conf /opt/.gnupg/gpg-agent.conf
COPY secrets/* /opt/secrets
COPY bin/* /usr/bin

# Set HOME to /opt and configure for OpenShift compatibility
ENV HOME=/opt

# Set permissions for OpenShift (arbitrary UID with group 0)
RUN chown -R 1001:0 /opt && \
    chmod -R g+rwX /opt && \
    chmod g=u /etc/passwd

EXPOSE 22
CMD ["/bin/sh", "-c", "echo \"user:x:$(id -u):0::/opt:/bin/zsh\" >> /etc/passwd && /usr/bin/sshd -D"]
