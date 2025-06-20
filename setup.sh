#!/usr/bin/bash

sudo dnf update -y
sudo loginctl enable-linger $USER
curl https://github.com/kylape.keys >> ~/.ssh/authorized_keys

host/install-kind.sh

mkdir -p /tmp/kind

mkdir -p ~/.config/containers
echo -e '[containers]\npids_limit = 100000' > ~/.config/containers/containers.conf

host/kind-with-registry.sh

kind get kubeconfig > ~/.kube/config
kubectl patch -n local-path-storage configmap local-path-config --patch-file host/local-path-config.yaml

kubectl create -f resources/
kubectl wait --for=condition=Available --timeout=5m deploy/devcontainer
