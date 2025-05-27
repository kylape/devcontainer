#!/usr/bin/env bash

if [[ ! -f "secrets.yaml" ]]; then
    echo secrets.yaml does not exist.
    exit 1
fi

if [[ ! -f "public-age-key.txt" ]]; then
    echo secrets.yaml does not exist.
    exit 1
fi

# Create .sops.yaml configuration
cat > .sops.yaml << EOF
creation_rules: 
  - age: $(cat public-age-key.txt)
EOF

# Encrypt the secrets file
SOPS_AGE_KEY=$(cat public-age-key.txt) sops -e secrets.yaml > secrets.enc.yaml

# Clean up plaintext secrets
rm secrets.yaml .sops.yaml
