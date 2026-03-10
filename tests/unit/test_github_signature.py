from app.security.github_signature import build_signature, verify_github_signature


def test_valid_signature_is_accepted() -> None:
    secret = "top-secret"
    payload = b'{"ok":true}'
    signature = build_signature(secret, payload)

    assert verify_github_signature(secret, payload, signature)


def test_invalid_signature_is_rejected() -> None:
    secret = "top-secret"
    payload = b'{"ok":true}'
    signature = "sha256=deadbeef"

    assert not verify_github_signature(secret, payload, signature)


def test_missing_signature_is_rejected() -> None:
    assert not verify_github_signature("x", b"{}", None)


def test_payload_tampering_is_rejected() -> None:
    secret = "top-secret"
    original_payload = b'{"status":"approved"}'
    tampered_payload = b'{"status":"denied"}'
    signature = build_signature(secret, original_payload)

    assert not verify_github_signature(secret, tampered_payload, signature)
