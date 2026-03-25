# Cloud Run Deployment for Althea

**Purpose:** Deploy Althea on GCP Cloud Run with secure secret access via Secret Manager.

---

## Prerequisites

1. **GCP Project** with Cloud Run API enabled
2. **Service Account** for Cloud Run (e.g., `althea-cloudrun@project.iam.gserviceaccount.com`)
3. **Artifact Registry** repository (or Container Registry)
4. **Secret** created in GCP Secret Manager (`amplify_github_pat`)
5. **gcloud CLI** installed locally

---

## Setup Steps

### 1. Create/Configure Service Account

```bash
PROJECT_ID="your-gcp-project"
SERVICE_ACCOUNT_NAME="althea-cloudrun"

# Create service account
gcloud iam service-accounts create $SERVICE_ACCOUNT_NAME \
  --display-name="Althea Cloud Run service account" \
  --project=$PROJECT_ID

# Get the full email
SERVICE_ACCOUNT_EMAIL=$(gcloud iam service-accounts list \
  --filter="displayName:$SERVICE_ACCOUNT_NAME" \
  --format="value(email)" \
  --project=$PROJECT_ID)

echo "Service account: $SERVICE_ACCOUNT_EMAIL"
```

### 2. Grant Secret Manager Access

```bash
PROJECT_ID="your-gcp-project"
SERVICE_ACCOUNT_EMAIL="althea-cloudrun@${PROJECT_ID}.iam.gserviceaccount.com"

# Grant secretmanager.secretAccessor role
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
  --role="roles/secretmanager.secretAccessor" \
  --condition=None

# Verify
gcloud projects get-iam-policy $PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
  --format="table(bindings.role)"
```

### 3. Create Secret in Secret Manager

```bash
# Create the secret (one-time)
echo "ghp_your_github_pat..." | gcloud secrets create amplify_github_pat \
  --replication-policy="automatic" \
  --data-file=-

# Verify
gcloud secrets list | grep amplify_github_pat
```

### 4. Build and Push Docker Image

```bash
PROJECT_ID="your-gcp-project"
REGION="us-central1"
IMAGE_NAME="althea"

# Build with Cloud Build
gcloud builds submit . \
  --config=cloudbuild.yaml \
  --project=$PROJECT_ID \
  --substitutions="_IMAGE_NAME=${IMAGE_NAME},_REGION=${REGION}"

# OR build locally and push
docker build -f docker/openclaw.Dockerfile -t ${REGION}-docker.pkg.dev/${PROJECT_ID}/docker/${IMAGE_NAME}:latest .
docker push ${REGION}-docker.pkg.dev/${PROJECT_ID}/docker/${IMAGE_NAME}:latest
```

### 5. Deploy to Cloud Run

```bash
PROJECT_ID="your-gcp-project"
REGION="us-central1"
SERVICE_ACCOUNT_EMAIL="althea-cloudrun@${PROJECT_ID}.iam.gserviceaccount.com"
IMAGE_URL="${REGION}-docker.pkg.dev/${PROJECT_ID}/docker/althea:latest"

gcloud run deploy althea \
  --image=$IMAGE_URL \
  --service-account=$SERVICE_ACCOUNT_EMAIL \
  --region=$REGION \
  --platform=managed \
  --memory=4Gi \
  --cpu=2 \
  --timeout=3600 \
  --set-env-vars="GOOGLE_CLOUD_PROJECT=${PROJECT_ID}" \
  --allow-unauthenticated \
  --port=18789 \
  --project=$PROJECT_ID
```

### 6. Verify Deployment

```bash
# Check Cloud Run service
gcloud run services describe althea --region=us-central1 --project=$PROJECT_ID

# Check service account permissions
gcloud secrets get-iam-policy amplify_github_pat --project=$PROJECT_ID
```

---

## How It Works

```
1. Cloud Run starts container
   ├─ Uses service account: althea-cloudrun@project.iam.gserviceaccount.com
   ├─ ADC (Application Default Credentials) automatically configured
   └─ GOOGLE_CLOUD_PROJECT env var set

2. scripts/entrypoint.sh runs first
   ├─ gcloud auth uses ADC (no explicit auth needed)
   ├─ Retrieves amplify_github_pat from Secret Manager
   └─ Exports as AMPLIFY_GITHUB_PAT env var

3. openclaw gateway starts
   ├─ AMPLIFY_GITHUB_PAT available to all skills/subagents
   └─ Ready to handle requests
```

---

## Environment Variables

Set these in Cloud Run deployment:

```bash
GOOGLE_CLOUD_PROJECT=your-gcp-project-id
```

If you need to add more secrets in the future:

```bash
# Add more env vars to entrypoint.sh
# Add more retrieve_secret calls in scripts/entrypoint.sh
retrieve_secret "new_secret_name" "NEW_SECRET_VAR"

# Rebuild and redeploy
docker build -f docker/openclaw.Dockerfile -t ... .
gcloud run deploy althea --image=... --update-env-vars="NEW_SECRET_VAR=..."
```

---

## Troubleshooting

### "Error: gcloud: command not found"
- Dockerfile gcloud installation may have failed
- Check Cloud Build logs: `gcloud builds list`

### "Error: (gcloud.secrets.versions.access) Permission denied"
- Service account lacks `secretmanager.secretAccessor` role
- Run step 2 again to grant permissions
- Check: `gcloud secrets get-iam-policy amplify_github_pat`

### "AMPLIFY_GITHUB_PAT not found in entrypoint"
- Secret may not exist
- Check: `gcloud secrets list | grep amplify_github_pat`
- Check Cloud Run logs for startup errors

### "Port 18789 not responding"
- Increase Cloud Run memory/CPU
- Check Cloud Run logs: `gcloud run logs read althea`

---

## Updating the Service

When you update code/Dockerfile:

```bash
# Rebuild
docker build -f docker/openclaw.Dockerfile -t ${REGION}-docker.pkg.dev/${PROJECT_ID}/docker/althea:latest .

# Push
docker push ${REGION}-docker.pkg.dev/${PROJECT_ID}/docker/althea:latest

# Redeploy (Cloud Run uses latest tag automatically, or be explicit)
gcloud run deploy althea --image=${REGION}-docker.pkg.dev/${PROJECT_ID}/docker/althea:latest
```

---

## References

- [Cloud Run docs](https://cloud.google.com/run/docs)
- [Application Default Credentials](https://cloud.google.com/docs/authentication/application-default-credentials)
- [Secret Manager docs](https://cloud.google.com/secret-manager/docs)
- [gcloud auth documentation](https://cloud.google.com/sdk/gcloud/reference/auth)

