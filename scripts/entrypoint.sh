#!/usr/bin/env bash
# entrypoint.sh
# Retrieves secrets from GCP Secret Manager at container startup
# Exports them as environment variables for all processes in the container

set -e

echo "[entrypoint] Starting OpenClaw initialization..."

# Function to safely retrieve and export a secret
retrieve_secret() {
    local secret_name="$1"
    local env_var_name="$2"
    
    if [ -z "$secret_name" ] || [ -z "$env_var_name" ]; then
        echo "[entrypoint] ERROR: retrieve_secret requires secret_name and env_var_name"
        return 1
    fi
    
    echo "[entrypoint] Retrieving secret: $secret_name"
    
    # Try to retrieve from GCP Secret Manager
    if value=$(gcloud secrets versions access latest --secret="$secret_name" 2>/dev/null); then
        # Export as environment variable
        export "$env_var_name"="$value"
        echo "[entrypoint] ✓ Secret '$secret_name' loaded as $env_var_name"
        return 0
    else
        echo "[entrypoint] ⚠ Warning: Could not retrieve secret '$secret_name'"
        echo "[entrypoint]   Ensure:"
        echo "[entrypoint]   - Secret exists in GCP Secret Manager"
        echo "[entrypoint]   - Service account has 'secretmanager.secretAccessor' role"
        echo "[entrypoint]   - GOOGLE_CLOUD_PROJECT environment variable is set"
        return 1
    fi
}

# Retrieve secrets
# Add more retrieve_secret calls here as needed
retrieve_secret "amplify_github_pat" "AMPLIFY_GITHUB_PAT" || true

# Verify at least one secret was retrieved (optional, adjust as needed)
if [ -z "$AMPLIFY_GITHUB_PAT" ]; then
    echo "[entrypoint] ⚠ Warning: No GitHub PAT available. PR feedback executor will fail if used."
fi

echo "[entrypoint] Secret initialization complete."
echo "[entrypoint] Starting application..."

# Start the application with all secrets available as environment variables
exec "$@"
