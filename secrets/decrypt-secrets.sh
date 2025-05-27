#!/usr/bin/env bash

if [[ ! -f "secrets.enc.yaml" ]]; then
    echo secrets.yaml does not exist.
    exit 1
fi

if [[ ! -f "encrypted-age-key.txt" ]]; then
    echo secrets.yaml does not exist.
    exit 1
fi

cat > .sops.yaml << EOF
creation_rules: 
  - age: $(cat public-age-key.txt)
EOF

SOPS_AGE_KEY=$(age -d encrypted-age-key.txt | grep AGE-SECRET-KEY) sops -d secrets.enc.yaml > secrets.yaml

rm .sops.yaml
