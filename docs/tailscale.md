# Tailscale Pattern

This repo supports a standard Tailscale deployment pattern for GCP VM-based Althea/OpenClaw nodes.

## Goal

- Keep the published gateway port bound to loopback on the VM host.
- Reach OpenClaw UI over private Tailnet HTTPS.
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

After VM boots and joins tailnet, resolve active node/IP:

```bash
tailscale status
tailscale ip -4
sudo tailscale serve status
```

Preferred access is Tailscale Serve over HTTPS:

- `https://<tailnet-hostname>/`

For the current `amplify-bots-vm` deployment, Tailscale Serve proxies:

- `https://amplify-bots-vm-1-1.tail4f8fba.ts.net/`
- to `http://127.0.0.1:18789`

OpenClaw Control UI requires a secure browser context for device identity, so
plain `http://<tailscale-ip>:18789` is not a supported Control UI entrypoint.
Use the tokenized dashboard URL from:

```bash
sudo docker exec app-openclaw-gateway-1 openclaw dashboard --no-open
```

That prints a `#token=...` URL you can swap onto the HTTPS Tailscale Serve
origin.

## Operational notes

- Prefer tagged auth keys with expiry.
- Keep Telegram allowlist and exec approvals enabled.
- Keep public firewall scoped to the minimum required service ports.
