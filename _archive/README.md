# Loolib Archive

This directory holds Lua modules that are still kept in the workspace for reference,
but are not part of the production `loolib.toc` runtime surface.

Rules:

- Nothing under `_archive/` may be referenced from `loolib.toc`.
- Nothing under `_archive/` should be imported by shipped Loothing code.
- If a module is revived, move it back into the main tree and add it to the
  runtime load order intentionally.
