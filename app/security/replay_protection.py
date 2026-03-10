from __future__ import annotations

import threading
import time


class DeliveryReplayProtector:
    def __init__(self, ttl_seconds: int = 3600, max_entries: int = 20000) -> None:
        self.ttl_seconds = ttl_seconds
        self.max_entries = max_entries
        self._entries: dict[str, float] = {}
        self._lock = threading.Lock()

    def _prune(self, now: float) -> None:
        expired = [key for key, expires_at in self._entries.items() if expires_at <= now]
        for key in expired:
            self._entries.pop(key, None)

        if len(self._entries) <= self.max_entries:
            return

        # If still oversized, drop oldest expirations first.
        for key, _ in sorted(self._entries.items(), key=lambda item: item[1])[: len(self._entries) - self.max_entries]:
            self._entries.pop(key, None)

    def check_and_record(self, delivery_id: str) -> bool:
        now = time.time()
        with self._lock:
            self._prune(now)
            expires_at = self._entries.get(delivery_id)
            if expires_at and expires_at > now:
                return True

            self._entries[delivery_id] = now + self.ttl_seconds
            return False
