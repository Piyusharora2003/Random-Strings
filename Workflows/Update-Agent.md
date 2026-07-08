# Prompt: Update an Existing `AGENTS.md`

## Objective

You are an experienced Software Architect and Senior Software Engineer performing a review of an existing repository.

The repository already contains an `AGENTS.md` file.

Your task is **NOT** to rewrite it.

Instead, compare the current repository against the existing `AGENTS.md` and generate an **AGENTS-update.md** file containing **only the required changes**.

The goal is to keep `AGENTS.md` synchronized with the repository while minimizing unnecessary rewrites.

---

# Primary Goal

Generate

```
AGENTS-update.md
```

that contains only the differences between the existing documentation and the current repository.

Do **NOT** regenerate the entire AGENTS.md.

Treat this as a pull request review for documentation.

---

# Inputs

Read the following first.

```
AGENTS.md
```

If available, also read

```
architecture.md
```

Feature README files

Module README files

Developer documentation

These documents represent the current documented state.

---

# Analysis Process

## Phase 1 — Understand Existing AGENTS.md

Determine

- documented workflows
- coding conventions
- repository navigation
- architectural constraints
- AI operating rules
- testing strategy
- documentation strategy
- modification strategy

Treat these as the expected repository conventions.

---

## Phase 2 — Analyze Repository

Inspect the repository.

Determine

- new modules
- renamed directories
- removed components
- architectural changes
- new technologies
- new workflows
- changed conventions
- new testing approach
- new deployment method
- new documentation
- new build process

---

## Phase 3 — Compare

Compare documentation with implementation.

Classify findings into

### Missing

Repository behavior exists but AGENTS.md does not describe it.

---

### Outdated

Repository changed but documentation did not.

---

### Incorrect

Documentation contradicts the repository.

---

### Deprecated

Documentation describes behavior that no longer exists.

---

### Improvement

Documentation is technically correct but could improve AI efficiency.

---

# Areas to Compare

## Repository Navigation

Directory structure

Feature organization

Shared modules

Utilities

Configuration

Infrastructure

---

## Development Workflow

Adding features

Bug fixing

Testing

Deployment

Database changes

Configuration changes

Documentation updates

---

## Coding Conventions

Naming

Formatting

Imports

Folder organization

Error handling

Logging

Validation

DTO usage

Repository pattern

Dependency injection

Layering

Only include conventions actually observed.

---

## Architectural Constraints

Determine whether constraints have changed.

Examples

Layered architecture

Hexagonal

DDD

CQRS

Dependency direction

Repository rules

Controller rules

Caching rules

Event handling

---

## AI Navigation Guide

Determine whether AI navigation instructions remain accurate.

Examples

Bug investigation path

Feature implementation order

Database modifications

Authentication flow

Logging flow

Performance investigation

Caching investigation

If new modules exist, recommend navigation updates.

---

## Modification Strategy

Determine whether AI editing guidance should change.

Examples

Preferred utilities

Existing abstractions

Shared libraries

Reusable helpers

New extension points

---

## Testing Strategy

Determine whether

- test framework changed
- new integration tests exist
- mocking strategy changed
- CI expectations changed
- required test coverage changed

---

## Documentation Strategy

Determine whether AI should update additional documents after changes.

Examples

Feature README

API documentation

Architecture

Environment documentation

Migration guide

---

## Common Tasks

Check whether new common tasks should be documented.

Examples

Add queue consumer

Add Kafka listener

Add GraphQL resolver

Add scheduled job

Add feature flag

Integrate third-party API

---

## Repository Checklist

Determine whether completion checklist should change.

Examples

Lint

Formatting

Security scan

Migration verification

API compatibility

Performance verification

Accessibility

Documentation

---

# AI Efficiency Review

Evaluate whether AGENTS.md could better reduce repository exploration.

Examples

Missing navigation hints

Missing dependency direction

Missing feature ownership

Missing module descriptions

Missing extension points

Missing common workflows

Recommend improvements.

---

# Output Format

Generate

```
AGENTS-update.md
```

using the following structure.

```
# AGENTS.md Update Report

## Summary

Overall assessment.

---

## Missing Documentation

New repository behavior that should be documented.

---

## Outdated Documentation

Existing sections requiring updates.

---

## Incorrect Documentation

Documentation that contradicts implementation.

---

## Deprecated Documentation

Documentation that should be removed.

---

## Repository Navigation Updates

Changes to navigation guidance.

---

## Workflow Updates

Changes to development workflows.

---

## Coding Convention Updates

Observed convention changes.

---

## Architectural Constraint Updates

Rules that have changed.

---

## AI Navigation Updates

Navigation improvements for AI agents.

---

## Modification Strategy Updates

Recommended editing behavior updates.

---

## Testing Strategy Updates

Testing documentation changes.

---

## Documentation Rule Updates

Additional documents AI should update.

---

## Common Task Updates

New development workflows.

---

## Repository Checklist Updates

Checklist additions or removals.

---

## Recommended Changes to AGENTS.md

Priority

High

Medium

Low

Include

- Section
- Reason
- Suggested update

---

## Overall Documentation Health

Choose one

- Up to date
- Minor updates required
- Moderate updates required
- Major revision recommended

Explain why.
```

---

# Rules

Do NOT

- rewrite AGENTS.md
- duplicate unchanged content
- recommend architectural redesigns unless requested
- invent repository conventions
- include implementation details

Always

- compare repository against AGENTS.md
- document only observed differences
- distinguish facts from recommendations
- optimize recommendations for AI coding agents

If a documented section is still accurate, omit it from the report.

---

# Style Requirements

The report should be

- concise
- actionable
- diff-oriented
- repository-specific
- easy to review during code review
- focused on maintaining synchronization

Use

- markdown headings
- checklists
- tables where useful
- priority labels
- short explanations

Avoid repeating existing documentation.

---

# Success Criteria

A maintainer should be able to update `AGENTS.md` using only this report without reanalyzing the repository.

After applying the report:

- `AGENTS.md` accurately reflects the current repository.
- AI agents receive updated navigation guidance.
- New workflows and conventions are documented.
- Outdated guidance is removed.
- Documentation remains concise and optimized for future development.