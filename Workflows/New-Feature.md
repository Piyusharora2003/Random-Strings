# Workflow: New Feature Development

## Objective

This workflow guides an AI coding agent through implementing a new feature while ensuring consistency with the existing architecture, coding standards, and repository conventions.

The goal is **not only to implement the feature**, but also to ensure it integrates naturally into the existing system, minimizes unnecessary changes, and keeps project documentation synchronized.

---

# Guiding Principles

- Understand the existing architecture before writing code.
- Reuse existing patterns whenever possible.
- Prefer extending existing modules over creating new abstractions.
- Keep changes localized to the owning feature.
- Preserve backward compatibility unless explicitly requested.
- Implement incrementally.
- Keep documentation synchronized with implementation.

---

# Phase 1 — Understand the Requirement

Read the feature request carefully.

Determine

- Business objective
- Functional requirements
- Non-functional requirements
- Expected API behavior
- Data requirements
- Error scenarios
- Validation rules
- Performance expectations
- Security requirements
- Acceptance criteria

If anything is ambiguous, ask clarifying questions before proceeding.

---

# Phase 2 — Identify the Owning Feature

Determine which business feature owns this functionality.

Read documentation in the following order.

1. Feature `README.md`
2. `AGENTS.md`
3. `architecture.md` (only if additional architectural context is required)

Avoid reading unrelated features.

If the feature spans multiple modules, document the expected ownership boundaries before implementation.

---

# Phase 3 — Analyze Existing Implementation

Search for similar implementations.

Look for

- Existing endpoints
- Similar business logic
- Existing validators
- Existing DTOs
- Existing repositories
- Existing scheduled jobs
- Existing queue consumers
- Existing integrations
- Shared utilities
- Existing tests

Reuse existing patterns wherever possible.

---

# Phase 4 — Create an Implementation Plan

Produce an implementation plan before modifying code.

The plan should include

## Functional Changes

What functionality will be added?

---

## Components to Modify

Examples

- Routes
- Controllers
- Services
- Repositories
- Models
- DTOs
- Validators
- Middleware
- Background Workers
- Scheduled Jobs
- Configuration

---

## Database Changes

If required

- Tables
- Collections
- Migrations
- Indexes
- Constraints

---

## API Changes

Document

- New endpoints
- Request schema
- Response schema
- Error responses

---

## External Dependencies

Identify

- APIs
- Queues
- Storage
- Cache
- Authentication
- Infrastructure

---

## Documentation Changes

Identify

- Feature README
- architecture.md
- AGENTS.md
- API documentation

---

Wait for approval if the project workflow requires it.

---

# Phase 5 — Design the Solution

Before coding

Evaluate

- Existing architecture
- Existing design patterns
- Reusable abstractions
- Extension points
- Potential regressions

Prefer

- Extension
- Composition
- Existing abstractions

Avoid

- New frameworks
- New architectural patterns
- Duplicate implementations

---

# Phase 6 — Implement Incrementally

Implement in logical order.

Typical sequence

```
Model

↓

Repository

↓

Service

↓

Validation

↓

Controller

↓

Route

↓

Tests
```

For event-driven systems

```
Schema

↓

Producer

↓

Consumer

↓

Business Logic

↓

Tests
```

For scheduled jobs

```
Configuration

↓

Scheduler

↓

Business Logic

↓

Tests
```

Keep commits logically grouped.

---

# Phase 7 — Verify Integration

Verify that the feature integrates correctly.

Check

- Existing APIs
- Existing workflows
- Authentication
- Authorization
- Validation
- Logging
- Metrics
- Tracing
- Caching
- Error handling
- Transactions
- Configuration

Ensure existing behavior is unaffected.

---

# Phase 8 — Testing

Execute

Unit Tests

Integration Tests

Feature-specific Tests

Manual Verification (if applicable)

Verify

- Happy path
- Invalid input
- Edge cases
- Failure scenarios
- Authorization
- Performance expectations

---

# Phase 9 — Documentation Review

Determine which documentation requires updates.

Examples

Feature README

New API

New configuration

Database schema

architecture.md

AGENTS.md

Environment variables

Migration guide

Only update documentation affected by the feature.

---

# Phase 10 — Final Review

Perform a final review before completion.

Verify

- Existing architecture preserved
- Existing coding conventions followed
- Public APIs remain compatible
- New functionality is isolated
- Logging is consistent
- Error handling is consistent
- Tests pass
- Documentation updated
- No unrelated files modified

---

# Deliverables

Provide a concise implementation summary.

```
## Feature Summary

Describe the implemented feature.

---

## Design Decisions

Explain important implementation choices.

---

## Files Added

Explain purpose of each file.

---

## Files Modified

Explain why each file changed.

---

## Database Changes

List schema changes.

---

## API Changes

Document new or modified endpoints.

---

## Configuration Changes

List new configuration.

---

## Documentation Updates

List updated documentation.

---

## Testing Performed

Summarize verification.

---

## Known Limitations

Document intentionally deferred work.

---

## Future Enhancements

Optional improvements not included.
```

---

# AI Operating Rules

Always

- Read the feature README before reading implementation files.
- Follow the existing architecture.
- Search locally before globally.
- Reuse existing implementations whenever possible.
- Extend existing modules instead of creating parallel ones.
- Keep implementation localized.
- Preserve dependency direction.
- Keep commits focused.
- Update affected documentation before completion.

Never

- Refactor unrelated code.
- Introduce architectural changes without approval.
- Add unnecessary dependencies.
- Create duplicate abstractions.
- Modify unrelated features.
- Break backward compatibility without explicit approval.

---

# Exit Checklist

Complete every item before finishing.

```
□ Requirements understood

□ Owning feature identified

□ Existing patterns reused

□ Implementation plan completed

□ Smallest necessary changes made

□ Tests written or updated

□ Existing tests pass

□ Logging verified

□ Error handling verified

□ Documentation updated

□ No unrelated files modified

□ Public APIs remain compatible

□ Configuration reviewed

□ Final implementation report prepared
```

---

# Expected Repository Update Order

When implementing a feature, update artifacts in the following order if applicable.

```
1. Code

↓

2. Tests

↓

3. Feature README

↓

4. architecture.md (only if architecture changed)

↓

5. AGENTS.md (only if development workflow changed)
```

This order ensures that documentation reflects the final implementation rather than intermediate design decisions.

---

# Success Criteria

A feature implementation is considered complete when

- The requested functionality is fully implemented.
- The implementation follows existing project patterns.
- No unnecessary architectural changes were introduced.
- Tests validate the new behavior.
- Documentation is synchronized.
- Another developer or AI agent can understand and extend the feature without additional repository exploration.