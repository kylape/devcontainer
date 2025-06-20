#!/usr/bin/bash

# Initialize flags
as_root=false
mem_mapped_pvcs=false

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
sudo loginctl enable-linger $USER
curl https://github.com/kylape.keys >> ~/.ssh/authorized_keys

host/install-kind.sh

mkdir -p /tmp/kind

mkdir -p ~/.config/containers
echo -e '[containers]\npids_limit = 100000' > ~/.config/containers/containers.conf

if [[ as_root ]]; then
    sudo host/kind-with-registry.sh
    echo "$(sudo kind get kubeconfig)" > ~/.kube/config
else
    host/kind-with-registry.sh
    kind get kubeconfig > ~/.kube/config
fi

[[ $mem_mapped_pvcs ]] && kubectl patch -n local-path-storage configmap local-path-config --patch-file host/local-path-config.yaml

kubectl create -f resources/
kubectl wait --for=condition=Available --timeout=5m deploy/devcontainer
