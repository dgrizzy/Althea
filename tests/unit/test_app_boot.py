from app.main import app


def test_app_starts_without_public_routes() -> None:
    assert app.title == "Althea"
    assert all(route.path != "/healthz" for route in app.routes)
