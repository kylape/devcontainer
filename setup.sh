#!/usr/bin/bash

sudo dnf update -y
sudo loginctl enable-linger $USER
curl https://github.com/kylape.keys >> ~/.ssh/authorized_keys

host/install-kind.sh

mkdir -p /tmp/kind

host/kind-with-registry.sh

kind get kubeconfig > ~/.kube/config
kubectl patch -n local-path-storage configmap local-path-config --patch-file host/local-path-config.yaml

kubectl create -f resources/
kubectl wait --for=condition=Available deploy/devcontainer
