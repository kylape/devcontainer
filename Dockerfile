FROM quay.io/fedora/fedora-toolbox:43

RUN ARCH=$(uname -m) && \
    case "${ARCH}" in \
        "x86_64") \
            KUBECTL_ARCH="amd64" && \
            VIRTCTL_ARCH="amd64" && \
            TEKTON_ARCH="64bit" && \
            SOPS_ARCH="x86_64" && \
            MC_ARCH="amd64" && \
            GO_ARCH="amd64" \
        ;; \
        "aarch64") \
            KUBECTL_ARCH="arm64" && \
            VIRTCTL_ARCH="arm64" && \
            TEKTON_ARCH="ARM64" && \
            SOPS_ARCH="aarch64" && \
            MC_ARCH="arm64" && \
            GO_ARCH="arm64" \
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
    tar xzf /go.tar.gz 

RUN sed -i '/tsflags=nodocs/d' /etc/dnf/dnf.conf
RUN dnf install -y neovim sshd tmux zsh yq tig rbw htop age pinentry gh fzf buildah patch make gcc podman npm nodejs jq npm nodejs zstd skopeo rust-analyzer python-pip helm

RUN mkdir -p /root/.ssh && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config && \
    ssh-keygen -A && \
    npm -g install mcp-hub@latest && \
    npm -g install yaml-language-server && \
    npm install -g @anthropic-ai/claude-code

COPY conf/pam-sshd /etc/pam.d/sshd

RUN touch /root/.ssh/authorized_keys && \
    curl -L https://github.com/kylape.keys >> /root/.ssh/authorized_keys && \
    mkdir -p /root/.config && \
    git -C /root/.config clone https://github.com/kylape/neovim-config.git nvim && \
    ln -s /root/.config/nvim/vimrc.vim /root/.vimrc && \
    nvim --headless -c 'lua require("lazy").update({wait = true}); vim.cmd("quit")' && \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" && \
    git clone https://github.com/joshskidmore/zsh-fzf-history-search ~/.oh-my-zsh/plugins/zsh-fzf-history-search && \
    GOROOT=/go GOPATH=/root/go /go/bin/go install golang.org/x/tools/gopls@latest && \
    mkdir -p /root/secrets && \
    mkdir -p /root/.config/gh && mkdir -p /root/.config/ripgrep && \
    mkdir -p /root/.gnupg && chmod 700 /root/.gnupg

COPY conf/tmux.conf /root/.tmux.conf
COPY conf/zshrc /root/.zshrc
COPY conf/gitconfig /root/.gitconfig
COPY conf/gh.yaml /root/.config/gh/config.yml
COPY conf/ripgrep /root/.config/ripgrep/config
COPY conf/move-in /root/move-in
COPY conf/gpg-agent.conf /root/.gnupg/gpg-agent.conf
COPY secrets/* /root/secrets

EXPOSE 22
CMD ["/usr/bin/sshd", "-D"]
