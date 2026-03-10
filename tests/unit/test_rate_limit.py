from app.security.rate_limit import FixedWindowRateLimiter


def test_rate_limiter_blocks_after_threshold() -> None:
    limiter = FixedWindowRateLimiter(window_seconds=60, max_requests=2)

    assert limiter.allow("127.0.0.1") is True
    assert limiter.allow("127.0.0.1") is True
    assert limiter.allow("127.0.0.1") is False


def test_rate_limiter_tracks_keys_independently() -> None:
    limiter = FixedWindowRateLimiter(window_seconds=60, max_requests=1)

    assert limiter.allow("a") is True
    assert limiter.allow("b") is True
    assert limiter.allow("a") is False
