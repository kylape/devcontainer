#!/usr/bin/bash

# Initialize flags
as_root=""
mem_mapped_pvcs=""

# Parse command line arguments
while getopts "sm" opt; do
  case $opt in
    s)
      as_root=true
      ;;
    m)
      mem_mapped_pvcs=true
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done

# Shift away the parsed options
shift $((OPTIND-1))

# Default behavior if no options provided
sudo dnf update -y
sudo dnf install -y jq tmux iotop htop vim
sudo loginctl enable-linger $USER
sudo sysctl fs.inotify.max_user_watches=524288
sudo sysctl fs.inotify.max_user_instances=512
curl https://github.com/kylape.keys >> ~/.ssh/authorized_keys

host/install-kind.sh

sudo mkfs.btrfs /dev/nvme1n1
sudo mount /dev/nvme1n1 /root

sudo mkdir -p /root/kind
sudo mkdir -p /root/containers/storage

sudo tee /etc/containers/storage.conf > /dev/null << 'EOF'
[storage]
driver = "overlay"
graphroot = "/root/containers/storage"
runroot = "/run/containers/storage"
EOF

# Add the context rule for the new storage location
sudo semanage fcontext -a -t container_var_lib_t "/root/containers/storage(/.*)?"
sudo semanage fcontext -a -t container_file_t "/root/containers/storage/overlay-containers(/.*)?"
sudo restorecon -R /root/containers/storage

mkdir -p ~/.kube

if [[ as_root ]]; then
    sudo systemctl enable --now podman.socket
    sudo podman network create kind
    sudo mkdir -p /root/.config/containers
    sudo sh -c "echo -e '[containers]\npids_limit = 100000' > /root/.config/containers/containers.conf"
    sudo host/kind-with-registry.sh
    echo "$(sudo kind get kubeconfig)" > ~/.kube/config
else
    podman network create kind
    mkdir -p ~/.config/containers
    echo -e '[containers]\npids_limit = 100000' > ~/.config/containers/containers.conf
    host/kind-with-registry.sh
    kind get kubeconfig > ~/.kube/config
fi

[[ $mem_mapped_pvcs ]] && kubectl patch -n local-path-storage configmap local-path-config --patch-file host/local-path-config.yaml

kubectl create -f resources/
kubectl wait --for=condition=Available --timeout=5m deploy/devcontainer
