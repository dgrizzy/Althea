from __future__ import annotations

import hashlib
import hmac


SIGNATURE_PREFIX = "sha256="


def build_signature(secret: str, payload: bytes) -> str:
    digest = hmac.new(secret.encode("utf-8"), payload, hashlib.sha256).hexdigest()
    return f"{SIGNATURE_PREFIX}{digest}"


def verify_github_signature(secret: str, payload: bytes, signature_header: str | None) -> bool:
    if not signature_header or not signature_header.startswith(SIGNATURE_PREFIX):
        return False

    expected = build_signature(secret, payload)
    return hmac.compare_digest(expected, signature_header)
