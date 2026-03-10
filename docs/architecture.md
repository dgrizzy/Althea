# Architecture

- GitHub Issues and Project are the source of truth.
- GitHub webhooks are the event source.
- Althea validates webhook signatures, rate limits requests, and rejects replayed delivery IDs.
- Althea normalizes issue payloads and calls OpenClaw native `/hooks/agent`.
- GitHub issue labels/comments track lifecycle and status.
