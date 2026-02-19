# Phase 1.14.4: Code Review & Cleanup

**Parent Goal:** Phase 1.14 End-to-End Testing & Exit Criteria
**Checklist:**
- [x] 1.14.1 Integration Tests
- [x] 1.14.2 E2E Flutter Test
- [x] 1.14.3 Documentation Update
- [x] 1.14.4 Code Review
- [ ] 1.14.5 Performance Testing
- [ ] 1.14.6 Final Exit Criteria Checklist

---

## What
Systematic cleanup of the codebase before declaring "Backend Complete".

## Why
Remove "TODOs", debug prints, and hardcoded secrets that slipped in.

## How
Use `ruff` (linter) and manual grep.

## Features
- **Linting:** Enforce valid Python syntax and style.
- **Security Scan:** Check for API keys in code.

## Files
- Modify: Entire codebase.

## Steps

1. **Run Linter**
   - `ruff check . --fix`

2. **Grep for Secrets**
   - `grep -r "sk-" .` (Check for OpenAI keys)
   - `grep -r "TODO" .` (Resolve or ticket them)

## Exit Criteria
- Linter passes with 0 errors.
- No secrets in source control.
