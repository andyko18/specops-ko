---
type: llm
---

PASS if the response uses a standard-library or already-available mechanism (for example `functools.lru_cache` / `functools.cache`) and does not introduce a hand-written cache class, a TTL manager, or an interface/factory abstraction.
FAIL if the response designs a custom cache class or adds a new dependency for this.
