# Tailscale Pattern

This repo supports a standard Tailscale deployment pattern for GCP VM-based Althea/OpenClaw nodes.

## Goal

- Keep OpenClaw on loopback only.
- Reach OpenClaw UI/API over private Tailnet access.
- Reuse the same pattern for future single-VM agent deployments.

## Terraform settings

In `infra/terraform/terraform.tfvars`:

- `enable_tailscale = true`
- `tailscale_hostname = "amplify-bots-vm"`
- `tailscale_advertise_tags = ["tag:amplify-bots"]`
- `tailscale_ssh = true`
- `tailscale_accept_routes = false`

## Auth key

Terraform creates secret container `${name_prefix}-tailscale-auth-key`.

Set the auth key as latest secret version:

```bash
gcloud secrets versions add <name_prefix>-tailscale-auth-key \
  --data-file=- <<'EOFKEY'
tskey-xxxxxxxxxxxxxxxx
EOFKEY
```

VM startup script fetches this secret using its service account and runs `tailscale up`.

## Access pattern

After VM boots and joins tailnet:

```bash
ssh <vm-tailnet-name> -L 18789:127.0.0.1:18789
```

Then access OpenClaw locally at `http://127.0.0.1:18789`.

## Operational notes

- Prefer tagged auth keys with expiry.
- Keep Telegram allowlist and exec approvals enabled.
- Keep public firewall scoped to the minimum required service ports.
