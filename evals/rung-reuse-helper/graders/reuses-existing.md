---
type: llm
---

PASS if the plan reuses the project's existing slug helper (the `slugify` function in `src/lib/slug.ts`) for the category slug.
FAIL if the plan writes a new slug/URL-normalizing function or adds a new dependency instead of reusing the existing helper.
