FROM quay.io/klape/stackrox-builder:latest

RUN curl -L "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" > /usr/bin/kubectl && chmod +x /usr/bin/kubectl
RUN VERSION=$(curl https://storage.googleapis.com/kubevirt-prow/release/kubevirt/kubevirt/stable.txt) \
    curl -L https://github.com/kubevirt/kubevirt/releases/download/${VERSION}/virtctl-${VERSION}-linux-amd64 > /usr/bin/virtctl && \
    chmod +x /usr/bin/virtctl
RUN dnf install -y https://github.com/tektoncd/cli/releases/download/v0.41.0/tektoncd-cli-0.41.0_Linux-64bit.rpm && \
    dnf install -y https://github.com/getsops/sops/releases/download/v3.10.2/sops-3.10.2-1.x86_64.rpm
RUN sed -i '/tsflags=nodocs/d' /etc/dnf/dnf.conf
RUN dnf install -y neovim sshd tmux zsh yq tig procps-ng rbw htop age man-db pinentry gh

RUN groupadd -g 1000 dev && \
    useradd -m -u 1000 -g 1000 -s /bin/zsh dev && \
    mkdir -p /home/dev/.ssh && \
    chown dev:dev /home/dev/.ssh && \
    chown -R dev:dev /home/dev && \
    chmod 700 /home/dev/.ssh && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config && \
    ssh-keygen -A && \
    npm -g install mcp-hub@latest

COPY conf/pam-sshd /etc/pam.d/sshd

USER dev
RUN touch /home/dev/.ssh/authorized_keys && \
    curl -L https://github.com/kylape.keys >> /home/dev/.ssh/authorized_keys && \
    mkdir -p ~/.config && \
    git -C ~/.config clone https://github.com/kylape/neovim-config.git nvim && \
    ln -s /home/dev/.config/nvim/vimrc.vim /home/dev/.vimrc && \
    nvim --headless -c 'Lazy install' -c 'quit' && \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" && \
    GOROOT=/go GOPATH=/home/dev/go /go/bin/go install golang.org/x/tools/gopls@latest && \
    mkdir -p /home/dev/secrets

COPY --chown=dev:dev conf/tmux.conf /home/dev/.tmux.conf
COPY --chown=dev:dev conf/zshrc /home/dev/.zshrc
COPY --chown=dev:dev conf/gitconfig /home/dev/.gitconfig
COPY --chown=dev:dev secrets/* /home/dev/secrets

USER root
EXPOSE 22
CMD ["/usr/bin/sshd", "-D"]
