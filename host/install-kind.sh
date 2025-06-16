#!/usr/bin/bash

# For AMD64 / x86_64
if [ $(uname -m) = x86_64 ]; then
    curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.29.0/kind-linux-amd64
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
fi

# For ARM64
if [ $(uname -m) = aarch64 ]; then 
    curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.29.0/kind-linux-arm64
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/arm64/kubectl"
fi

chmod +x ./kind
chmod +x ./kubectl
sudo mv ./kind /usr/local/bin/kind
sudo mv ./kubectl /usr/local/bin/kubectl
