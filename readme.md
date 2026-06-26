# Devcontainer

This is a hand-grown dev container, primarily for my own personal use as a hobby (for now).

## Project Requirements

These are the requirements I care about right now:

* Able to easily deploy to Kubernetes, primarily Openshift
* Configure my personal Neovim setup
* Dynamically load in any secrets needed for sofware development (GPG and SSH keys, etc)
* Secrets should not be stored as k8s `Secrets` if it can be avoided
* Devcontainer should be able to be spun up fresh on a daily basis
* Development caches (go mod, go build, npm modules, etc) should be easily populated without having to re-run builds from scratch
* Ability to log in to devcontainer from a tablet (e.g. iPad)

## Technical Choices

Given the above requirements, here's what this project looks like:

* Container image based off of [Stackrox builder image](https://github.com/kylape/stackrox-tekton/blob/main/Dockerfile)
* SSH running in-container.  `kubectl exec` does not work easily on tablets.
* S3/MinIO as a cache
* SOPS/age for managing secrets
* Ability to utilize k8s service account token for issuing `kubectl` commands out-of-the-box

## Why?

Similar to requirements, this is why I think a devcontainer would be a nice way to develop:

* Portability: I can have a consistent environment across any device
* Auditability: I have a clear log of any package or config added to the container image
* More shareable: I can easily share my devcontainers code repo to other devs to show what my development environment is like.  I can also add a dev's public SSH key and let them log in to my environment.
* Cloud network: Remote Kubernetes clusters are typically in data centers that are closer to other network resources like Go packages or caching layers
* Local nework: Ability to directly contact other kube resources without port forwards

## Security

Security is a more nuanced topic that deserves its own section.
Here are a few security advantages of devcontainers of local development on a workstation:

* Ephemeral data: If something shouldn't be persisted (e.g. some token for an internal tool), the ephemeral nature of containers makes it much more likely to be deleted.
* Transparency: It's easy to install some package on a laptop and forget about it for years.  This is of course possible with containers as well, but it's at least written down on a Dockerfile or in some config file in a git repo at least.
* Intentionality: Devcontainers force users to think consiously about security.  How do secrets get applied to a devcontainer, for example?  This can end up in a more robust solution for managing personal secrets.

Of course the obvious downsides are:

* Sensitive data are in the cloud as opposed to on a physical machine in close proximity to the user
* While inentionality is great, overlooked security gaps have a greater impact on devcontainers than local development

## Deployment

This devcontainer can run in two modes: standalone Podman or Kubernetes.

### Podman (Standalone)

**Recommended for local development with KinD:**

```bash
# Create a shared network for devcontainer and KinD clusters
podman network create dev-net

# Run devcontainer on the shared network
podman run -d --name devcontainer \
  --network dev-net \
  -p 2222:22 \
  -v /home/$USER/devdata:/opt/workspace:Z \
  -v /run/user/$(id -u)/podman/podman.sock:/run/podman/podman.sock:Z \
  --cap-add=SYS_CHROOT \
  ghcr.io/kylape/devcontainer:latest
```

This provides:
* Podman access via the mounted socket — create/manage containers on the host
* Shared network with KinD clusters — containers can communicate directly
* SSH access on host port 2222

Access the container via `podman exec -it devcontainer zsh` or `ssh -p 2222 localhost`.

**Host setup for rootless podman + KinD:**

```bash
# Enable the podman socket
systemctl --user enable --now podman.socket

# Configure log driver to avoid KinD timeout issues
mkdir -p ~/.config/containers
cat >> ~/.config/containers/containers.conf <<EOF
[containers]
log_driver = "k8s-file"
EOF
```

**Creating KinD clusters** (from host or inside devcontainer):

```bash
export KIND_EXPERIMENTAL_PROVIDER=podman
kind create cluster --name dev

# Connect KinD control plane to the shared network
podman network connect dev-net dev-control-plane

# The cluster is now accessible from devcontainer via container name
# e.g., kubectl will work using the kubeconfig that references the container IP
```

**Minimal deployment** (no host integration):

```bash
podman run -d --name devcontainer -p 2222:22 \
  -v /home/$USER/devdata:/opt/workspace:Z \
  --cap-add=SYS_CHROOT \
  ghcr.io/kylape/devcontainer:latest
```

### Kubernetes (KinD or OpenShift)

Deploy using the manifests in `resources/`:

```bash
kubectl create -f resources/
kubectl wait --for=condition=Available --timeout=5m deploy/devcontainer
```

For OpenShift, use `resources/openshift/` instead.

See `CLAUDE.md` for additional build and deployment commands.
