# GitHub App Setup (OpenClaw `gh` Access)

Use this when you want OpenClaw to act on a scoped set of GitHub repos without PATs.

If you want to run PAT-first, set `github_pat_secret_id` in Terraform (for example `github_pat`).
Startup will write PAT-derived `GH_TOKEN` into `/opt/althea/runtime/github.env`, and `gh` will use it immediately.

## 1) Create the GitHub App

In GitHub (`Settings` -> `Developer settings` -> `GitHub Apps` -> `New GitHub App`):

- App name: `Amplify Dev Bots`
- Homepage URL: your repo/org URL
- Webhook:
  - If you are not using webhook ingestion: disable App webhook.
  - If you need webhook ingestion later: keep enabled and configure URL/secret then.
- Callback URL / OAuth flow / Device flow: leave disabled.
- Where can this app be installed: `Only on this account`

Repository permissions (minimum for PR workflow):

- `Metadata`: Read-only (mandatory)
- `Contents`: Read and write
- `Pull requests`: Read and write
- `Issues`: Read and write (optional but recommended for issue comments/status)

Install the app on `Only select repositories`, then pick the short allowlist.

## 2) Capture the three required values

From GitHub App pages:

- `App ID`
- `Installation ID` (from the installation URL or API)
- Private key PEM (generate from App settings)

## 3) Store private key in Secret Manager

```bash
gcloud secrets versions add amplify-bots-github-app-private-key \
  --project amplify-bots \
  --data-file=-
```

Paste full PEM (`-----BEGIN...-----` to `-----END...-----`) and then `Ctrl-D`.

## 4) Set Terraform vars

Edit [terraform.tfvars](/Users/davidgriswold/Desktop/Althea/infra/terraform/terraform.tfvars):

- `github_app_id`
- `github_app_installation_id`
- `github_app_private_key_secret_id` (or keep empty to use default `amplify-bots-github-app-private-key`)

Then apply:

```bash
terraform -chdir=infra/terraform apply -var-file=terraform.tfvars
```

## 5) Validate on VM

Run:

```bash
gcloud compute ssh amplify-bots-vm --project amplify-bots --zone us-central1-a \
  --command 'cd /opt/althea/app && ./scripts/validate_github_app_runtime.sh'
```

Optional repo-scope check:

```bash
gcloud compute ssh amplify-bots-vm --project amplify-bots --zone us-central1-a \
  --command 'cd /opt/althea/app && ./scripts/validate_github_app_runtime.sh app-openclaw-gateway-1 dgrizzy/Amplify'
```

If repo check fails with 404/403, the app is installed but not allowed on that repo.
