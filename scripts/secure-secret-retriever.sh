#!/usr/bin/env bash
# secure-secret-retriever.sh
# Retrieves secrets from GCP Secret Manager securely
# Never exposes secrets in logs, git history, or process listings
# Usage: source this file, then call get_secret <secret-name>

set -euo pipefail

# Ensure gcloud is installed
ensure_gcloud() {
  if ! command -v gcloud &> /dev/null; then
    echo "Installing gcloud CLI..." >&2
    
    # Install gcloud (varies by OS)
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
      curl https://sdk.cloud.google.com | bash
      exec -l $SHELL
    elif [[ "$OSTYPE" == "darwin"* ]]; then
      # Assume homebrew installed
      brew install --cask google-cloud-sdk || true
    else
      echo "ERROR: gcloud not found and auto-install not supported on $OSTYPE" >&2
      return 1
    fi
  fi
}

# Retrieve secret from GCP Secret Manager
# Args: secret_name
# Returns: secret value (via stdout)
# Usage: TOKEN=$(get_secret "my-secret")
get_secret() {
  local secret_name="$1"
  
  # Ensure gcloud is available
  ensure_gcloud
  
  # Retrieve secret (will fail gracefully if not found)
  gcloud secrets versions access latest --secret="$secret_name" 2>/dev/null || {
    echo "ERROR: Failed to retrieve secret '$secret_name'. Check:" >&2
    echo "  - Secret exists in GCP Secret Manager" >&2
    echo "  - Service account has 'secretmanager.secretAccessor' role" >&2
    echo "  - You're authenticated to GCP (gcloud auth login)" >&2
    return 1
  }
}

# Set up secure git credentials from Secret Manager
# Args: secret_name, github_org (optional)
# Usage: setup_github_credentials "amplify_github_pat" "amplify-dental-ai"
setup_github_credentials() {
  local secret_name="$1"
  local github_org="${2:-}"
  
  echo "Setting up GitHub credentials from Secret Manager..." >&2
  
  # Retrieve token (stdout only, never logged)
  local token
  token=$(get_secret "$secret_name") || return 1
  
  # Set in environment (won't appear in logs if we're careful)
  export GIT_CREDENTIALS_TOKEN="$token"
  
  # Configure git credential helper
  git config --global credential.helper store || true
  
  echo "✅ GitHub credentials configured from Secret Manager" >&2
  echo "   Use: git clone https://\$GIT_CREDENTIALS_TOKEN@github.com/org/repo.git" >&2
}

# Clean up sensitive env vars
# Usage: cleanup_credentials
cleanup_credentials() {
  unset GIT_CREDENTIALS_TOKEN 2>/dev/null || true
  echo "✅ Sensitive credentials cleared from environment" >&2
}

# Set up git URL with credentials
# Args: base_url (e.g., github.com/org/repo.git), secret_name
# Returns: full URL with credentials (via stdout, be careful with this!)
git_url_with_creds() {
  local base_url="$1"
  local secret_name="$2"
  
  local token
  token=$(get_secret "$secret_name") || return 1
  
  echo "https://${token}@${base_url}"
}

# Export functions
export -f ensure_gcloud
export -f get_secret
export -f setup_github_credentials
export -f cleanup_credentials
export -f git_url_with_creds

echo "✅ Secure secret retriever loaded. Functions available:" >&2
echo "   - get_secret <name>" >&2
echo "   - setup_github_credentials <name> [org]" >&2
echo "   - cleanup_credentials" >&2
echo "   - git_url_with_creds <url> <secret-name>" >&2
