# Architecture

- OpenClaw (self-hosted) is the execution runtime.
- Telegram ("Claw Bot") is the command and approval interface.
- Althea app runtime is intentionally minimal (`/healthz` only).
- Terraform in this repo manages VM/network/secrets/bootstrap concerns.
