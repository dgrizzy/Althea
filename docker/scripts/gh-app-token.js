#!/usr/bin/env node

const fs = require("fs");
const crypto = require("crypto");

function fail(msg) {
  process.stderr.write(`${msg}\n`);
  process.exit(1);
}

function readPrivateKey() {
  if (process.env.GITHUB_APP_PRIVATE_KEY && process.env.GITHUB_APP_PRIVATE_KEY.trim() !== "") {
    return process.env.GITHUB_APP_PRIVATE_KEY;
  }

  const keyPath = process.env.GITHUB_APP_PRIVATE_KEY_PATH;
  if (!keyPath) {
    fail("missing GITHUB_APP_PRIVATE_KEY_PATH");
  }

  try {
    return fs.readFileSync(keyPath, "utf8");
  } catch (err) {
    fail(`failed reading GitHub App private key: ${err.message}`);
  }
}

function buildJwt(appId, pem) {
  const now = Math.floor(Date.now() / 1000);
  const payload = {
    iat: now - 60,
    exp: now + 540,
    iss: appId,
  };
  const header = {
    alg: "RS256",
    typ: "JWT",
  };

  const encodedHeader = Buffer.from(JSON.stringify(header)).toString("base64url");
  const encodedPayload = Buffer.from(JSON.stringify(payload)).toString("base64url");
  const unsigned = `${encodedHeader}.${encodedPayload}`;
  const signature = crypto.createSign("RSA-SHA256").update(unsigned).sign(pem, "base64url");
  return `${unsigned}.${signature}`;
}

async function main() {
  const appId = process.env.GITHUB_APP_ID;
  const installationId = process.env.GITHUB_INSTALLATION_ID;

  if (!appId) {
    fail("missing GITHUB_APP_ID");
  }
  if (!installationId) {
    fail("missing GITHUB_INSTALLATION_ID");
  }

  const privateKeyPem = readPrivateKey();
  const jwt = buildJwt(appId, privateKeyPem);
  const url = `https://api.github.com/app/installations/${installationId}/access_tokens`;

  const resp = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${jwt}`,
      Accept: "application/vnd.github+json",
      "User-Agent": "openclaw-gh-app-token",
      "X-GitHub-Api-Version": "2022-11-28",
    },
  });

  const body = await resp.text();
  if (!resp.ok) {
    fail(`GitHub token request failed (${resp.status}): ${body}`);
  }

  let parsed;
  try {
    parsed = JSON.parse(body);
  } catch (err) {
    fail(`failed parsing GitHub token response: ${err.message}`);
  }

  if (!parsed.token) {
    fail("GitHub response missing token");
  }

  if (process.argv.includes("--json")) {
    process.stdout.write(
      `${JSON.stringify({
        token: parsed.token,
        expires_at: parsed.expires_at || null,
      })}\n`,
    );
    return;
  }

  process.stdout.write(`${parsed.token}\n`);
}

main().catch((err) => fail(err.message));
