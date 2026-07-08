# Prompt: Update an Existing Feature `README.md`

## Objective

You are an experienced Software Architect and Senior Software Engineer performing a documentation review of an existing project.

The repository already contains a `README.md` for this feature.

Your task is **NOT** to rewrite the README.

Instead, compare the current implementation of the feature against the existing documentation and generate a **README-update.md** containing **only the required updates**.

The purpose of this report is to keep feature documentation synchronized with implementation while minimizing unnecessary rewrites.

---

# Primary Goal

Generate

```
README-update.md
```

that contains only the differences between the current implementation and the existing feature README.

This document should function similarly to a code review or changelog.

It should answer

- What has changed?
- What is undocumented?
- What documentation is now incorrect?
- What sections should be updated?
- What new APIs, events, or extension points exist?
- What obsolete documentation should be removed?

---

# Inputs

Assume the feature already contains

```
<feature>/README.md
```

Read it completely before analyzing the feature.

If available, also read

```
architecture.md

AGENTS.md
```

to understand the intended architecture and conventions.

---

# Analysis Process

## Phase 1 — Read Existing Documentation

Understand

- feature purpose
- documented APIs
- request flow
- responsibilities
- dependencies
- owned data
- testing guidance
- AI navigation guidance
- extension points

Treat this as the expected documentation.

---

## Phase 2 — Analyze Feature

Inspect every relevant part of the feature.

Examples

Routes

Controllers

Services

Repositories

Models

Validators

Background jobs

Configuration

Tests

Integrations

Events

---

## Phase 3 — Compare

Compare documentation against implementation.

Classify findings into

### Missing

Feature behavior exists but is undocumented.

---

### Changed

Implementation changed.

Documentation did not.

---

### Incorrect

Documentation contradicts the implementation.

---

### Deprecated

Documentation describes functionality that no longer exists.

---

### Improvement

Documentation is technically correct but can better support developers and AI agents.

---

# Areas to Compare

## Purpose

Has the business responsibility changed?

---

## Public Interfaces

Compare

REST endpoints

GraphQL

Events

Kafka

RabbitMQ

Queues

Scheduled jobs

CLI commands

Background workers

Identify

Added

Removed

Modified

Deprecated

---

## Directory Structure

Detect

new folders

new modules

renamed packages

new shared utilities

refactoring

---

## Internal Components

Compare

Controllers

Services

Repositories

Validators

Utilities

Handlers

Factories

Adapters

Document newly introduced responsibilities.

---

## Request Flow

Has execution flow changed?

Examples

New middleware

New validation

Caching

Events

Queues

Workers

Background processing

Retries

Circuit breakers

---

## Dependencies

Compare

Internal modules

External services

Infrastructure

Caching

Storage

Messaging

Authentication

Monitoring

---

## Owned Data

Compare

Database tables

Collections

Cache keys

Files

Storage

Topics

Queues

Events

Schemas

---

## Extension Guide

Determine whether instructions for adding

Endpoints

Models

Business rules

Events

Jobs

Configuration

remain accurate.

---

## Testing

Compare

Test structure

Coverage

Framework

Fixtures

Mocking

Integration tests

New testing requirements

---

## AI Navigation Guide

Review

Bug fixing workflow

Feature implementation workflow

Database changes

Validation

Authentication

Configuration

Performance investigation

Determine whether navigation should be updated.

---

## Related Features

Determine whether new dependencies or integrations exist.

---

## Common Changes

Check whether workflows such as

Add endpoint

Add validation

Modify repository

Database migration

Scheduler

Consumer

Producer

need updates.

---

# AI Efficiency Review

Evaluate whether the README still enables an AI coding agent to work primarily within this feature.

Recommend improvements if

- navigation is incomplete
- ownership is unclear
- dependencies are undocumented
- extension points are missing
- common workflows are absent

---

# Output Format

Generate

```
README-update.md
```

using the following structure.

```
# Feature README Update Report

## Summary

Overall assessment.

---

## Missing Documentation

New functionality not documented.

---

## Changed Documentation

Existing sections requiring updates.

---

## Incorrect Documentation

Documentation contradicting implementation.

---

## Deprecated Documentation

Documentation that should be removed.

---

## Public Interface Updates

API

Events

Queues

Workers

Scheduled Jobs

---

## Internal Structure Updates

Directory

Components

Responsibilities

---

## Request Flow Updates

Execution flow changes.

---

## Dependency Updates

Internal

External

Infrastructure

---

## Data Ownership Updates

Database

Cache

Storage

Queues

Topics

---

## Extension Guide Updates

Recommended additions.

---

## Testing Updates

Testing guidance changes.

---

## AI Navigation Updates

Navigation improvements for AI agents.

---

## Related Feature Updates

Dependency changes.

---

## Common Task Updates

Workflow improvements.

---

## Recommended README Changes

Priority

High

Medium

Low

For each recommendation include

- Section
- Reason
- Suggested modification

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

- regenerate the README
- duplicate unchanged content
- recommend architectural redesigns unless explicitly requested
- invent undocumented behavior
- include implementation details

Always

- compare against the existing README
- report only observed differences
- distinguish facts from recommendations
- optimize for maintainability
- optimize for AI coding agents

If a section remains accurate, omit it from the report.

---

# Style Requirements

The report should be

- concise
- diff-oriented
- actionable
- repository-specific
- suitable for pull request review
- optimized for incremental documentation maintenance

Use

- markdown headings
- checklists
- tables where appropriate
- priority labels
- short explanations

Avoid large prose sections and unnecessary repetition.

---

# Success Criteria

A maintainer should be able to update the feature's `README.md` using only this report.

After applying the report

- the README accurately reflects the feature implementation
- developers can understand the latest feature behavior
- AI agents receive updated navigation guidance
- new APIs and extension points are documented
- obsolete documentation is removed
- feature documentation remains concise and synchronized with the codebase