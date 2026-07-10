# Errors

## [ERR-20260710-001] literal-safe-ripgrep

**Logged**: 2026-07-10T13:06:07Z
**Priority**: low
**Status**: resolved
**Area**: docs

### Summary

A validation search used Markdown backticks inside a double-quoted shell command, causing zsh command substitution and a parse error.

### Error

```text
zsh:1: parse error near `done'
zsh:1: parse error in command substitution
```

### Context

- The command attempted to search `CODEX_LOOP.md` for stale phrases with `rg`.
- The search pattern contained a Markdown fragment wrapped in backticks inside a double-quoted zsh argument.
- No repository data was changed by the failed command.

### Suggested Fix

Pass literal search patterns through single-quoted shell arguments, remove backticks from the pattern, or supply multiple `rg -e` arguments without shell interpolation.

### Metadata

- Reproducible: yes
- Related Files: CODEX_LOOP.md
- See Also: none

### Resolution

- **Resolved**: 2026-07-10T13:06:07Z
- **Commit/PR**: current documentation delivery commit
- **Notes**: Subsequent validation commands use literal-safe quoting without backtick interpolation.

---

## [ERR-20260710-003] git-diff-no-index-exit-code

**Logged**: 2026-07-10T13:38:13Z
**Priority**: low
**Status**: resolved
**Area**: docs

### Summary

The final whitespace gate treated `git diff --no-index` exit status 1 (“files differ”) as a validation failure even though `--check` reported no whitespace error.

### Error

```text
Combined validation command exited 1 with no whitespace diagnostics.
```

### Context

- `CODEX_LOOP.md` and `.learnings/ERRORS.md` are new untracked files, so comparison with `/dev/null` is expected to report differences.
- For `git diff --no-index`, status 1 means a diff exists; status greater than 1 indicates an execution error.
- The documents themselves passed the check and no mutation was caused by the command.

### Suggested Fix

Capture each no-index exit code and accept 0 or 1 while still rejecting status greater than 1 and any `--check` diagnostic.

### Metadata

- Reproducible: yes
- Related Files: CODEX_LOOP.md, .learnings/ERRORS.md
- See Also: ERR-20260710-001, ERR-20260710-002

### Resolution

- **Resolved**: 2026-07-10T13:38:13Z
- **Commit/PR**: current documentation delivery commit
- **Notes**: The corrected final gate handles documented `--no-index` status semantics explicitly.

---

## [ERR-20260710-002] tool-call-javascript-syntax

**Logged**: 2026-07-10T13:06:42Z
**Priority**: low
**Status**: resolved
**Area**: docs

### Summary

A follow-up validation tool call contained a mismatched quote in the JavaScript options object and failed before running the read-only command.

### Error

```text
SyntaxError: Invalid or unexpected token
```

### Context

- The intended operation was a read-only `rg` search in `CODEX_LOOP.md`.
- `max_output_tokens` was accidentally written with an unmatched quote.
- The command never executed and no repository data changed.

### Suggested Fix

Keep tool-call objects minimal and syntax-check property quoting before submission.

### Metadata

- Reproducible: yes
- Related Files: CODEX_LOOP.md
- See Also: ERR-20260710-001

### Resolution

- **Resolved**: 2026-07-10T13:06:42Z
- **Commit/PR**: current documentation delivery commit
- **Notes**: The corrected call uses a valid JavaScript object and literal-safe shell patterns.

---
