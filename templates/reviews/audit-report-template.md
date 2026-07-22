# Audit Report: SPEC-XXX

**Auditor:** DeepSeek (auditor)
**Date:**
**Spec:** specs/draft/SPEC-XXX-<slug>/spec.md
**Tickets audited:** TICKET-XXX, TICKET-XXX
**Diff:** <commit range or PR ref>

## Summary

**VERDICT:** Pass / Pass with issues / Fail

- Blocking issues: N
- Non-blocking issues: N
- Missing tests suggested: N
- Test results: Match / Mismatch

---

## Test gap diff

The auditor ran `make verify` independently and compared results with Claude Code's
verification report.

| Test | Claude Code result | Auditor result | Verdict |
|---|---|---|---|
| `TestCreateUser` | ✅ | ✅ | match |
| `TestHandleEmptyPayload` | ⚠️ skipped | ❌ fails | **mismatch** |
| `TestExpiredKey` | ✅ | not found in suite | **missing** |

Mismatches and missing tests are blocking unless stated otherwise.

---

## Blocking issues

### B1: <short title>

- **File:** `path/to/file.go`
- **Line:** 42
- **Problem:** One-sentence description.
- **Fix:**
  ```diff
  - old code
  + new code
  ```

### B2: ...

---

## Non-blocking issues

### N1: <short title>

- **File:** `path/to/file.go`
- **Line:** 88
- **Problem:** What could go wrong.
- **Fix:** Edit instruction or diff.
- **Defer:** If not fixed now, create TICKET-XXX.

---

## Missing tests

### T1: <test name>

- **Scenario:** What edge case or acceptance criterion this tests.
- **Input:** `{ "key": "value" }`
- **Expected:** `200 OK` with body `{"status": "ok"}`
- **Target file:** `path/to/file_test.go`
- **Priority:** high / medium / low

---

## Actionable delta (for coding agent)

The coding agent must produce these changes to resolve all blocking issues:

1. `path/to/file.go:42` — wrap error with context
2. `path/to/file.go:88` — add nil guard
3. `path/to/new_test.go` — add test for empty payload
