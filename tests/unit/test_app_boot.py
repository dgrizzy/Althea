from fastapi.testclient import TestClient

from app.config import Settings
from app.main import create_app


def test_app_starts_with_health_route() -> None:
    app = create_app(Settings(ALLOWED_HOSTS="testserver,localhost,127.0.0.1"))
    assert app.title == "Althea"
    assert any(route.path == "/healthz" for route in app.routes)


def test_healthz_returns_status_and_security_headers() -> None:
    app = create_app(Settings(ALLOWED_HOSTS="testserver,localhost,127.0.0.1"))
    client = TestClient(app)

    response = client.get("/healthz")

    assert response.status_code == 200
    assert response.json() == {"status": "ok"}
    assert response.headers["x-content-type-options"] == "nosniff"
    assert response.headers["x-frame-options"] == "DENY"
    assert response.headers["referrer-policy"] == "no-referrer"
    assert response.headers["cache-control"] == "no-store"
    assert "default-src 'none'" in response.headers["content-security-policy"]
    assert "strict-transport-security" not in response.headers


def test_healthz_includes_hsts_when_enabled() -> None:
    app = create_app(Settings(ALLOWED_HOSTS="testserver,localhost,127.0.0.1", ENFORCE_HTTPS_HEADERS=True))
    client = TestClient(app)

    response = client.get("/healthz")

    assert response.status_code == 200
    assert response.headers["strict-transport-security"] == "max-age=31536000; includeSubDomains"


def test_unknown_host_is_rejected() -> None:
    app = create_app(Settings(ALLOWED_HOSTS="localhost,127.0.0.1"))
    client = TestClient(app)

    response = client.get("/healthz", headers={"host": "evil.example"})

    assert response.status_code == 400


def test_allowed_hosts_can_be_comma_separated() -> None:
    settings = Settings(ALLOWED_HOSTS="localhost, 127.0.0.1,example.internal")
    assert settings.allowed_hosts == ("localhost", "127.0.0.1", "example.internal")
