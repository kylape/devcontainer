#!/bin/sh
set -o errexit

KIND=kind

# 1. Create registry container unless it already exists
reg_name='kind-registry'
reg_port='5001'
if [ "$(podman inspect -f '{{.State.Running}}' "${reg_name}" 2>/dev/null || true)" != 'true' ]; then
  podman run \
    -d --restart=always -p "127.0.0.1:${reg_port}:5000" --network bridge --name "${reg_name}" \
    registry:2
fi

# 2. Create kind cluster with containerd registry config dir enabled
# TODO: kind will eventually enable this by default and this patch will
# be unnecessary.
#
# See:
# https://github.com/kubernetes-sigs/kind/issues/2875
# https://github.com/containerd/containerd/blob/main/docs/cri/config.md#registry-configuration
# See: https://github.com/containerd/containerd/blob/main/docs/hosts.md
cat <<EOF | $KIND create cluster --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
containerdConfigPatches:
- |-
  [plugins."io.containerd.grpc.v1.cri".registry]
    config_path = "/etc/containerd/certs.d"
kubeadmConfigPatches:
- |
  apiVersion: kubeadm.k8s.io/v1
  kind: ClusterConfiguration
  metadata:
    name: config
  kubernetesVersion: "v1.32.0"
  networking:
    serviceSubnet: $(sudo podman network inspect kind | jq -r '.[0].subnets[0].subnet')
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 32222
    hostPort: 2222
  extraMounts:
  - containerPath: /local
    hostPath: /tmp/kind
EOF

# 3. Add the registry config to the nodes
#
# This is necessary because localhost resolves to loopback addresses that are
# network-namespace local.
# In other words: localhost in the container is not localhost on the host.
#
# We want a consistent name that works from both ends, so we tell containerd to
# alias localhost:${reg_port} to the registry container when pulling images
REGISTRY_DIR="/etc/containerd/certs.d"
for node in $($KIND get nodes); do
  podman exec "${node}" mkdir -p "${REGISTRY_DIR}/localhost:${reg_port}"
  cat <<EOF | podman exec -i "${node}" cp /dev/stdin "${REGISTRY_DIR}/localhost:${reg_port}/hosts.toml"
[host."http://${reg_name}:5000"]
EOF
  # podman exec "${node}" mkdir -p "${REGISTRY_DIR}/quay.io"
  # cat <<EOF | podman exec -i "${node}" cp /dev/stdin "${REGISTRY_DIR}/quay.io/hosts.toml"
# [host."https://quay.io"]
# EOF
done

# 4. Connect the registry to the cluster network if not already connected
# This allows kind to bootstrap the network but ensures they're on the same network
if [ "$(podman inspect -f='{{json .NetworkSettings.Networks.kind}}' "${reg_name}")" = 'null' ]; then
  podman network connect "kind" "${reg_name}"
fi

# 5. Document the local registry
# https://github.com/kubernetes/enhancements/tree/master/keps/sig-cluster-lifecycle/generic/1755-communicating-a-local-registry
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "localhost:${reg_port}"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF
