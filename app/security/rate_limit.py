from __future__ import annotations

import threading
import time
from collections import deque


class FixedWindowRateLimiter:
    def __init__(self, window_seconds: int = 60, max_requests: int = 120, max_keys: int = 10000) -> None:
        self.window_seconds = window_seconds
        self.max_requests = max_requests
        self.max_keys = max_keys
        self._events: dict[str, deque[float]] = {}
        self._lock = threading.Lock()

    def _prune_global(self, now: float) -> None:
        empty_keys = [key for key, entries in self._events.items() if not entries or entries[-1] <= now - self.window_seconds]
        for key in empty_keys:
            self._events.pop(key, None)

        if len(self._events) <= self.max_keys:
            return

        # If too many keys are active, drop keys with oldest activity.
        ordered = sorted(self._events.items(), key=lambda item: item[1][-1] if item[1] else 0.0)
        for key, _ in ordered[: len(self._events) - self.max_keys]:
            self._events.pop(key, None)

    def allow(self, key: str) -> bool:
        now = time.time()
        with self._lock:
            self._prune_global(now)
            entries = self._events.setdefault(key, deque())

            cutoff = now - self.window_seconds
            while entries and entries[0] <= cutoff:
                entries.popleft()

            if len(entries) >= self.max_requests:
                return False

            entries.append(now)
            return True
