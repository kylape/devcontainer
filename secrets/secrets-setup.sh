#!/usr/bin/env bash
# secrets-setup.sh - Decrypt and setup development secrets
# Place this in your devcontainer and run on login

set -euo pipefail

# Configuration
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENCRYPTED_KEY_FILE="${REPO_DIR}/encrypted-age-key.txt"
ENCRYPTED_SECRETS_FILE="${REPO_DIR}/secrets.enc.yaml"
MAX_RETRIES=3
RETRY_COUNT=0

cleanup() {
    # Clean up any temporary variables
    unset MASTER_PASSWORD 2>/dev/null || true
    unset age_key 2>/dev/null || true
}

function log() {
    echo "$1" >&2
}

# Set up cleanup trap
trap cleanup EXIT

check_dependencies() {
    local missing_deps=()
    
    command -v age >/dev/null 2>&1 || missing_deps+=("age")
    command -v sops >/dev/null 2>&1 || missing_deps+=("sops")
    command -v yq >/dev/null 2>&1 || missing_deps+=("yq")
    command -v kubectl >/dev/null 2>&1 || missing_deps+=("kubectl")
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        log "Missing required dependencies: ${missing_deps[*]}"
        exit 1
    fi
}

check_files() {
    if [ ! -f "$ENCRYPTED_KEY_FILE" ]; then
        log "Encrypted age key not found: $ENCRYPTED_KEY_FILE"
        exit 1
    fi
    
    if [ ! -f "$ENCRYPTED_SECRETS_FILE" ]; then
        log "Encrypted secrets file not found: $ENCRYPTED_SECRETS_FILE"
        exit 1
    fi
}

decrypt_secrets() {
    local decrypted_secrets
    
    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        # Try to decrypt the age key
        age_key=$(age -d "$ENCRYPTED_KEY_FILE" 2>/dev/null)
        if [[ "$age_key" == "" ]]; then
            RETRY_COUNT=$((RETRY_COUNT + 1))
            log "Invalid password. Attempt $RETRY_COUNT of $MAX_RETRIES"
            
            if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
                log "Maximum retry attempts reached. Exiting."
                exit 1
            fi
        else
            log "Password accepted, decrypting secrets..."
            break
        fi
    done
    
    # Decrypt secrets into variable (avoid writing to filesystem)
    if ! decrypted_secrets=$(SOPS_AGE_KEY=$age_key sops -d "$ENCRYPTED_SECRETS_FILE"); then
        log "Failed to decrypt secrets file"
        exit 1
    fi
    
    # Extract SSH private key
    local ssh_private_key=$(echo "$decrypted_secrets" | yq eval '.ssh.private_key' 2>/dev/null)
    if [[ "$ssh_private_key" != "" ]]; then
        log "SSH private key extracted"
    fi
    
    # Extract SSH public key
    local ssh_public_key=$(echo "$decrypted_secrets" | yq eval '.ssh.public_key' 2>/dev/null)
    if [[ "$ssh_public_key" != "" ]]; then
        log "SSH public key extracted"
    fi

    setup_ssh "$ssh_private_key" "$ssh_public_key"
    
    # Extract GPG private key
    local gpg_private_key=$(echo "$decrypted_secrets" | yq eval '.gpg.private_key' 2>/dev/null)
    if [[ "$gpg_private_key" != "" ]]; then
        log "GPG private key extracted"
    fi

    setup_gpg "$gpg_private_key"

    # Extract AWS credentisl
    local aws_secret_access_key=$(echo "$decrypted_secrets" | yq eval '.aws.secret_access_key' 2>/dev/null)
    if [[ "$aws_secret_access_key" != "" ]]; then
        log "AWS secret key extracted"
        echo "export AWS_SECRET_ACCESS_KEY=$aws_secret_access_key"
    fi

    local aws_access_key_id=$(echo "$decrypted_secrets" | yq eval '.aws.access_key_id' 2>/dev/null)
    if [[ "$aws_access_key_id" != "" ]]; then
        log "AWS key ID extracted"
        echo "export AWS_ACCESS_KEY_ID=$aws_access_key_id"
    fi

    local anthropic_api_key=$(echo "$decrypted_secrets" | yq eval '.anthropic.api_key' 2>/dev/null)
    if [[ "$anthropic_api_key" != "" ]]; then
        log "Anthropic API key extracted"
        echo "export ANTHROPIC_API_KEY=$anthropic_api_key"
    fi

    local github_api_key=$(echo "$decrypted_secrets" | yq eval '.github.api_key' 2>/dev/null)
    if [[ "$github_api_key" != "" ]]; then
        log "GitHub API key extracted"
        echo "export GH_TOKEN=$github_api_key"
    fi

    local dockerconfig=$(echo "$decrypted_secrets" | yq eval '.dockerconfig' 2>/dev/null)
    if [[ "$dockerconfig" != "" ]]; then
        log "Dockerconfig extracted"
        mkdir -p ~/.docker
        echo "$dockerconfig" > ~/.docker/config.json
        kubectl create -f - >/dev/null <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: klape-pull-secret
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: $(echo "$dockerconfig" | tr -d '\n' | base64 -w 0)
EOF
        kubectl create -f - >/dev/null <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: klape-opaque-dockerconfig
type: Opaque
data:
  config.json: $(echo "$dockerconfig" | tr -d '\n' | base64 -w 0)
EOF
    fi

    echo "$decrypted_secrets" | yq eval .gcloud.env | sed -e 's/: /=/' -e 's/^/export /'

    mkdir -p ~/.config
    echo "$decrypted_secrets" | yq eval .gcloud.config | base64 -d | zstd -d - | tar -C ~/.config -xf -
}

setup_ssh() {
    if [[ -z "$1" || -z "$2" ]]; then
        return
    fi

    local ssh_private_key="$1"
    local ssh_public_key="$2"
    
    # Start ssh-agent if not running
    if [ -z "${SSH_AUTH_SOCK:-}" ]; then
        log "SSH agent isn't running"
        return
    fi
    
    echo "$ssh_private_key" | ssh-add - && log "SSH key added to agent"
    
    # Add GitHub to known hosts if not present
    if [ ! -f ~/.ssh/known_hosts ] || ! grep -q "github.com" ~/.ssh/known_hosts; then
        ssh-keyscan github.com >> ~/.ssh/known_hosts 2>/dev/null
        log "Added GitHub to known hosts"
    fi
}

setup_gpg() {
    if [ -z "$1" ]; then
        return
    fi

    gpg_private_key="$1"
    
    # Get key ID from the key file
    local key_id=$(echo "$gpg_private_key" | gpg --show-keys --with-colons - 2>/dev/null | grep '^sec:' | cut -d: -f5 | head -1)
    
    # Check if key is already imported
    if [ -n "$key_id" ] && gpg --list-secret-keys "$key_id" >/dev/null 2>&1; then
        log "GPG key already imported"
    else
        # Import GPG key
        echo "$gpg_private_key" | gpg --batch --import - 2>/dev/null && log "GPG key imported"
    fi
}

check_agents() {
    local ssh_loaded=false
    local gpg_loaded=false
    
    # Check if SSH agent has keys
    # ssh-add -l returns:
    # - 0: keys are loaded
    # - 1: no keys loaded  
    # - 2: agent not running
    if [[ -n "${SSH_AUTH_SOCK:-}" && -n "$(ssh-add -l | grep SHA256)" ]]; then
        ssh_loaded=true
    fi
    
    # Check if GPG has secret keys
    # gpg --list-secret-keys returns non-zero if no secret keys exist
    if [[ -n "$(gpg --list-keys 2>/dev/null)" ]]; then
        gpg_loaded=true
    fi
    
    # Return 0 (success) if both agents have keys loaded
    [ "$ssh_loaded" = true ] && [ "$gpg_loaded" = true ]
}

main() {
    # Check if keys are already loaded in agents
    if check_agents; then
        log "All secrets already available in agents - no decryption needed"
        return 0
    fi
    
    log "Setting up development secrets..."
    
    check_dependencies
    check_files
    decrypt_secrets
    
    log "Secrets setup complete!"
}

# Only run if script is executed directly (not sourced)
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi
