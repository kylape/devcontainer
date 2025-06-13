FROM quay.io/klape/stackrox-builder:latest

RUN curl -L "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" > /usr/bin/kubectl && chmod +x /usr/bin/kubectl
RUN VERSION=$(curl https://storage.googleapis.com/kubevirt-prow/release/kubevirt/kubevirt/stable.txt) \
    curl -L https://github.com/kubevirt/kubevirt/releases/download/${VERSION}/virtctl-${VERSION}-linux-amd64 > /usr/bin/virtctl && \
    chmod +x /usr/bin/virtctl
RUN dnf install -y https://github.com/tektoncd/cli/releases/download/v0.41.0/tektoncd-cli-0.41.0_Linux-64bit.rpm && \
    dnf install -y https://github.com/getsops/sops/releases/download/v3.10.2/sops-3.10.2-1.x86_64.rpm
RUN sed -i '/tsflags=nodocs/d' /etc/dnf/dnf.conf
RUN dnf install -y neovim sshd tmux zsh yq tig procps-ng rbw htop age man-db pinentry gh fzf buildah patch file

RUN mkdir -p /root/.ssh && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config && \
    ssh-keygen -A && \
    npm -g install mcp-hub@latest && \
    npm -g install yaml-language-server

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
    mkdir -p /root/.config/gh && mkdir -p /root/.config/ripgrep

COPY conf/tmux.conf /root/.tmux.conf
COPY conf/zshrc /root/.zshrc
COPY conf/gitconfig /root/.gitconfig
COPY conf/gh.yaml /root/.config/gh/config.yml
COPY conf/ripgrep /root/.config/ripgrep/config
COPY secrets/* /root/secrets

EXPOSE 22
CMD ["/usr/bin/sshd", "-D"]
