# Workflow: Bug Investigation & Fix

## Objective

This workflow guides an AI coding agent through investigating, fixing, validating, and documenting a bug while minimizing unnecessary repository exploration and preserving existing architecture.

The primary goal is to identify the root cause, implement the smallest correct fix, and ensure no regressions are introduced.

---

# Guiding Principles

- Understand before modifying.
- Fix the root cause, not just the symptom.
- Make the smallest possible change.
- Preserve existing architecture and coding patterns.
- Reuse existing utilities whenever possible.
- Avoid unrelated refactoring.
- Update documentation only if behavior has changed.

---

# Phase 1 — Understand the Problem

Gather as much information as possible before reading code.

Identify

- Expected behavior
- Actual behavior
- Error message
- Stack trace
- API endpoint
- Module affected
- Steps to reproduce
- Environment
- Recent changes (if available)

If information is missing, ask targeted clarification questions before continuing.

---

# Phase 2 — Locate the Affected Feature

Determine which business feature owns the bug.

Read only the following documentation in order:

1. Feature `README.md`
2. `AGENTS.md`
3. `architecture.md` (only if additional context is required)

Avoid scanning unrelated modules.

---

# Phase 3 — Build an Investigation Plan

Identify likely locations of the issue.

Possible layers include

- Route
- Controller
- Service
- Repository
- Database
- Validation
- Middleware
- Authentication
- Background Worker
- Scheduler
- External API
- Cache
- Queue
- Configuration

Document a short investigation plan before reading implementation files.

---

# Phase 4 — Trace the Execution Flow

Trace the execution path from entry point to failure.

Examples

```
HTTP Request

↓

Route

↓

Controller

↓

Service

↓

Repository

↓

Database
```

or

```
Queue

↓

Consumer

↓

Business Logic

↓

Repository
```

Inspect only the files involved in this execution path.

Do not inspect unrelated components.

---

# Phase 5 — Identify Root Cause

Determine

- Why the bug occurs
- Which component owns the problem
- Whether the issue is functional, architectural, or configuration-related

Classify the issue where possible

- Validation
- Business logic
- Database
- Concurrency
- Caching
- Authentication
- Authorization
- Serialization
- Deserialization
- Configuration
- Performance
- Networking
- Infrastructure
- External dependency
- Race condition
- Resource leak
- Null handling
- State management

If multiple causes exist, identify the primary root cause.

---

# Phase 6 — Evaluate the Impact

Before modifying code, determine

Affected modules

Affected APIs

Affected background jobs

Database impact

External integrations

Configuration impact

Potential regressions

Document all impacted areas.

---

# Phase 7 — Design the Fix

Prefer solutions that

- preserve existing architecture
- reuse existing abstractions
- minimize code changes
- avoid breaking APIs
- avoid introducing new dependencies

If multiple solutions exist

Compare

- complexity
- maintainability
- performance
- backward compatibility
- implementation effort

Select the simplest correct solution.

---

# Phase 8 — Implement

Modify only the required files.

Avoid

- formatting-only changes
- unrelated cleanup
- renaming unrelated variables
- moving files
- architectural refactoring

Keep commits logically grouped.

---

# Phase 9 — Verify

Verify

- original issue resolved
- no regression introduced
- edge cases still behave correctly
- logging remains correct
- validation remains correct
- configuration unaffected

Execute

Existing tests

Relevant integration tests

Manual verification (if applicable)

---

# Phase 10 — Documentation Review

Determine whether documentation should be updated.

Possible updates include

- Feature README
- architecture.md
- AGENTS.md
- API documentation
- Configuration documentation

Update documentation only if behavior or architecture changed.

Bug fixes alone typically do not require documentation changes.

---

# Phase 11 — Final Review

Before completing the task, verify

- Root cause addressed
- No unrelated files modified
- Existing architecture preserved
- Existing coding conventions followed
- Tests pass
- No unused imports
- No dead code introduced
- Logging remains consistent
- Error handling remains consistent

---

# Deliverables

Provide a concise report using the following format.

```
## Bug Summary

Describe the reported issue.

---

## Root Cause

Explain why the issue occurred.

---

## Investigation Path

List the execution path that was inspected.

---

## Files Modified

Explain why each file changed.

---

## Solution

Describe the implemented fix.

---

## Verification

Explain how the fix was validated.

---

## Regression Risk

Low / Medium / High

Explain why.

---

## Documentation Impact

State whether any documentation requires updating.

---

## Follow-up Recommendations

Optional improvements that were intentionally not implemented.
```

---

# AI Operating Rules

Always

- Read the feature README before inspecting code.
- Follow the execution flow instead of searching the entire repository.
- Investigate the smallest relevant module first.
- Explain the root cause before implementing a fix.
- Prefer existing utilities over creating new ones.
- Keep modifications localized.
- Preserve dependency direction.
- Preserve public interfaces unless explicitly requested.
- Validate assumptions using code rather than guessing.

Never

- Rewrite unrelated code.
- Introduce architectural changes without approval.
- Modify multiple features unless required.
- Add new libraries to fix a bug.
- Refactor while debugging unless explicitly requested.

---

# Exit Checklist

Complete all items before marking the task finished.

```
□ Root cause identified

□ Smallest possible fix implemented

□ Existing architecture preserved

□ Coding conventions followed

□ No unrelated files modified

□ Existing tests pass

□ Relevant manual verification completed

□ No new warnings introduced

□ Documentation reviewed

□ Final report prepared
```