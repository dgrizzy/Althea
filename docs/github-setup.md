# GitHub Setup

1. Create `amplify-bots-queue` repository.
2. Add labels:
   - `althea:queued`
   - `althea:triaged`
   - `althea:running`
   - `althea:blocked`
   - `althea:review`
   - `althea:done`
   - `althea:error`
3. Configure webhook to `POST /webhooks/github`.
4. Set webhook secret to match `GITHUB_WEBHOOK_SECRET`.
5. Install GitHub App with minimum permissions for issues/metadata.
6. Set `ALLOWED_REPOS=<org>/amplify-bots-queue` in Althea runtime env.
7. New issues dispatch immediately on `issues.opened`; no approval label is required.
