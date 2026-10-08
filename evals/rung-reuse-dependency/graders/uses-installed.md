---
type: llm
---

PASS if the plan uses a dependency or platform feature that is already available (the project's installed `dayjs`, for example with its relativeTime plugin, or the built-in `Intl.RelativeTimeFormat`).
FAIL if the plan adds a new date/time library (such as moment, date-fns, timeago) or hand-writes a relative-time formatter from scratch.
