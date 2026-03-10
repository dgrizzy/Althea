from app.security.replay_protection import DeliveryReplayProtector


def test_replay_guard_blocks_duplicate_delivery() -> None:
    protector = DeliveryReplayProtector(ttl_seconds=3600, max_entries=100)

    first = protector.check_and_record("delivery-1")
    second = protector.check_and_record("delivery-1")

    assert first is False
    assert second is True
