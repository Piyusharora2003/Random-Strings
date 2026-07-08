# Workflow: Pull Request Review

## Purpose

This workflow performs a comprehensive review of a Pull Request (PR) using one or more engineering review skills supplied by the user.

The workflow is responsible for:

- Fetching and understanding the PR
- Determining the scope of changes
- Loading the requested review skill(s)
- Reviewing the implementation
- Producing a structured Markdown review report

This workflow **does not define coding standards**. Those are provided by the selected Skill(s).

---

# Inputs

Required

- Pull Request URL

Optional

- Skill(s) to use
- Areas of focus
- Files to exclude
- Severity threshold

Example

```
Review PR

PR:
https://github.com/org/project/pull/123

Skills:
- Spring Boot Review
- Security Review

Focus:
- Maintainability
- Performance
```

---

# Expected Output

Generate

```
pr-review-report.md
```

containing

- Executive Summary
- Positive Findings
- Issues
- Recommendations
- Overall Verdict

---

# Workflow

## Phase 1 — Validate Inputs

Verify

- PR URL is valid
- Repository is accessible
- Required permissions exist

If access fails

Stop and explain why.

---

## Phase 2 — Load Review Skill(s)

Load every requested review skill.

Examples

- Spring Boot Review
- Java Review
- TypeScript Review
- Security Review
- Performance Review
- API Review

If no skill is provided

Use the repository's default review skill.

If no default exists

Use the General Engineering Review Skill.

---

## Phase 3 — Understand the PR

Collect

- PR title
- Description
- Linked issue (if available)
- Files changed
- Number of commits
- Author
- Review comments (optional)

Determine

- Feature
- Bug Fix
- Refactoring
- Hotfix
- Documentation
- Infrastructure
- Configuration
- Test-only change

---

## Phase 4 — Understand the Context

Read only the documentation necessary to review the modified area.

Priority

1. Feature README
2. AGENTS.md
3. architecture.md

Avoid reading unrelated modules.

---

## Phase 5 — Analyze File Changes

For every modified file determine

- Purpose
- Layer
- Feature ownership
- Dependencies

Group files by feature.

Example

```
Authentication

- AuthController
- AuthService
- JwtProvider

Orders

- OrderRepository
- OrderValidator
```

---

## Phase 6 — Build the Review Plan

Before reviewing code

Determine

- Which skills apply
- Which architectural layers changed
- Which integrations are affected
- Which files deserve deeper inspection

Prioritize

- Business logic
- Security
- Concurrency
- Public APIs
- Persistence
- Configuration

---

## Phase 7 — Review the Code

Apply every loaded skill.

Evaluate

### Correctness

- Functional correctness
- Edge cases
- Null handling
- Error handling

---

### Design

- SOLID
- OOP
- Encapsulation
- Abstraction
- Cohesion
- Coupling
- Composition vs inheritance

---

### Architecture

- Layer responsibilities
- Dependency direction
- Separation of concerns
- Existing project conventions
- Feature boundaries

---

### Maintainability

- Naming
- Readability
- Duplication
- Complexity
- Dead code
- Magic values
- Reusability

---

### Performance

- Algorithmic complexity
- Memory usage
- Database queries
- N+1 problems
- Blocking operations
- Caching
- Object creation

---

### Concurrency

Where applicable

Review

- Thread safety
- Synchronization
- Race conditions
- Locks
- Async execution
- Resource management

---

### Security

Review

- Authentication
- Authorization
- Input validation
- Injection risks
- Sensitive logging
- Secrets
- File handling

---

### API Design

Review

- REST conventions
- Status codes
- DTOs
- Validation
- Backward compatibility

---

### Database

Review

- Transactions
- Index usage
- Repository usage
- Query efficiency
- Data consistency

---

### Logging

Review

- Meaningful logs
- Error logs
- Sensitive data exposure
- Traceability

---

### Testing

Review

- Test coverage
- Missing tests
- Edge cases
- Negative scenarios

---

### Documentation

Determine whether

- README
- architecture.md
- AGENTS.md

should be updated.

---

## Phase 8 — Classify Findings

Assign every issue

Severity

- Critical
- High
- Medium
- Low
- Suggestion

Category

Examples

- Architecture
- Maintainability
- Performance
- Security
- Testing
- Validation
- API
- Naming
- Logging
- Documentation

---

## Phase 9 — Validate Findings

Before reporting

Ensure

- Issue is supported by evidence
- Recommendation follows repository conventions
- No false positives
- Existing project patterns considered

Never recommend changes solely based on personal preference.

---

## Phase 10 — Generate Review Report

Generate

```
pr-review-report.md
```

---

# Report Structure

```
# Pull Request Review

## Executive Summary

Overall assessment.

---

## Positive Observations

Highlight well-designed parts of the PR.

---

## Critical Issues

List blocking issues.

---

## High Priority Issues

List important issues.

---

## Medium Priority Issues

List maintainability concerns.

---

## Low Priority Issues

Minor improvements.

---

## Suggestions

Optional improvements.

---

## Documentation Impact

Determine whether

- Feature README
- architecture.md
- AGENTS.md

require updates.

---

## Testing Review

Assess test quality.

---

## Overall Verdict

Choose one

✅ Approve

⚠️ Approve with Comments

❌ Request Changes

Explain why.
```

---

# Review Guidelines

Always

- Review using repository conventions.
- Apply all selected skills.
- Respect existing architecture.
- Prefer consistency over idealism.
- Explain why an issue exists.
- Suggest practical improvements.

Never

- Request unnecessary refactoring.
- Recommend architectural redesign unless required.
- Block a PR for stylistic preferences.
- Duplicate comments.
- Comment on generated code unless necessary.

---

# AI Operating Rules

- Understand the feature before reviewing implementation.
- Review by feature, not by file order.
- Compare against existing project patterns.
- Prioritize correctness over style.
- Prioritize architecture over formatting.
- Prefer objective findings.
- Quote evidence whenever possible.
- Keep comments actionable.
- Avoid speculative recommendations.

---

# Exit Checklist

```
□ PR successfully analyzed

□ Requested skill(s) applied

□ Repository conventions respected

□ Architecture reviewed

□ SOLID/OOP reviewed

□ Performance reviewed

□ Security reviewed

□ Testing reviewed

□ Documentation reviewed

□ Findings classified by severity

□ False positives minimized

□ Markdown review report generated
```