# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a personal devcontainer project designed to run in Kubernetes (primarily OpenShift). It provides a containerized development environment with SSH access, secret management via SOPS/age, and cloud-based development tooling.

Key characteristics:
- Container-based development environment running in Kubernetes
- SSH server for remote access (including from tablets)
- SOPS/age for encrypted secret management
- MinIO/S3 for development cache storage
- Ephemeral by design - can be spun up fresh daily

## Development Commands

### Container Management
```bash
# Build container image
make build-image

# Push to remote registry (quay.io)
make push-image

# Push to local registry and redeploy
make push-image-local
make build-push-redeploy  # Builds, pushes locally, and recreates pods
```

### Host Setup (EC2/VM)
```bash
# Basic setup on new VM
./setup.sh

# Setup with root privileges
./setup.sh -s

# Setup with memory-mapped PVCs
./setup.sh -m

# Deploy to remote host
./run-setup.sh <keyfile> <hostname>
```

### Kubernetes Operations
```bash
# Deploy all resources
kubectl create -f resources/

# Wait for deployment to be ready
kubectl wait --for=condition=Available --timeout=5m deploy/devcontainer

# Delete and recreate devcontainer pods
kubectl delete pod -l app=devcontainer
```

## Architecture

### Container Structure
- Base: Fedora Toolbox 43
- Development tools: Neovim, tmux, zsh, Go, Node.js, Rust
- Kubernetes tools: kubectl, virtctl, tekton CLI
- Container tools: podman, buildah, skopeo
- Secret management: SOPS, age, rbw

### Deployment Architecture
- KinD cluster for local Kubernetes development
- Container registry (localhost:5001) for local image storage
- DevContainer deployed as Kubernetes deployment with:
  - SSH server exposed via NodePort (port 2222)
  - Persistent volumes for data storage
  - Service account with admin privileges
  - Memory-mapped PVCs for performance

### Secret Management
- Secrets encrypted with SOPS/age
- GPG agent configured for longer passphrase caching
- SSH keys loaded from encrypted storage
- Secrets mounted in `/root/secrets/` directory

### Networking
- SSH proxy jump configuration through EC2 host
- Dynamic port forwarding (SOCKS proxy on port 8080)
- Direct access to Kubernetes cluster resources

## File Structure

- `Dockerfile` - Main container definition
- `Makefile` - Build and deployment commands
- `setup.sh` - Host initialization script
- `run-setup.sh` - Remote deployment script
- `conf/` - Configuration files (tmux, zsh, git, etc.)
- `resources/` - Kubernetes manifests
- `secrets/` - Encrypted secret files
- `host/` - Host setup scripts and configs