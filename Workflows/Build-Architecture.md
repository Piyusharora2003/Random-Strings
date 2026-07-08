# Prompt: Generate `architecture-update.md` for an Existing Project

## Objective

You are an experienced Software Architect performing an **architectural review** of an existing software project.

The repository already contains an `architecture.md` file.

Your task is **NOT** to rewrite it.

Instead, analyze the current codebase and compare it against the existing architecture documentation to produce an **architecture-update.md** document that captures only the changes, missing documentation, outdated sections, and recommended improvements.

The purpose of this document is to allow maintainers to update the architecture incrementally without regenerating the entire document.

---

# Primary Goal

Generate a file named

```
architecture-update.md
```

that answers the following questions:

- What architectural changes have occurred?
- What parts of the documentation are now outdated?
- What sections should be added?
- What diagrams should be updated?
- What newly discovered components are undocumented?
- What should future maintainers change in architecture.md?

This document should contain **only the delta** between the current repository and the existing documentation.

---

# Inputs

Assume the repository already contains

```
architecture.md
```

Read it completely before analyzing the project.

Then inspect the repository and compare reality against documentation.

Never overwrite or restate unchanged content.

---

# Analysis Process

## Phase 1 — Read Existing Documentation

Read

```
architecture.md
```

Understand

- architecture
- modules
- request flow
- diagrams
- design decisions
- documented constraints

Treat this file as the current source of truth.

---

## Phase 2 — Analyze Repository

Inspect the repository.

Determine the current architecture.

Identify

- new folders
- renamed modules
- deleted components
- new integrations
- new services
- new APIs
- new databases
- new queues
- new workers
- new schedulers
- new infrastructure
- new feature modules

---

## Phase 3 — Compare

Compare documentation with implementation.

Classify every finding as one of

### New

Previously undocumented architecture.

---

### Changed

Architecture exists but documentation is outdated.

---

### Removed

Documented component no longer exists.

---

### Incorrect

Documentation contradicts implementation.

---

### Incomplete

Documentation exists but lacks important information.

---

### Recommendation

Documentation is technically correct but should be improved.

---

# Areas to Compare

## Repository Structure

New folders

Renamed packages

Deleted modules

New shared libraries

Feature organization changes

---

## Runtime Flow

Request flow

Event flow

Scheduler flow

Queue flow

Worker flow

Consumer flow

Background jobs

---

## Layers

Controllers

Services

Repositories

Use Cases

Adapters

Handlers

Utilities

Middleware

Interceptors

Filters

---

## Persistence

Database changes

ORM changes

Repository changes

Migration strategy

Caching changes

Read/Write separation

---

## External Integrations

New APIs

Redis

Kafka

RabbitMQ

SNS

SQS

Email

Storage

Authentication Providers

Monitoring

Tracing

Metrics

---

## Cross Cutting Concerns

Logging

Authentication

Authorization

Validation

Caching

Rate Limiting

Tracing

Metrics

Security

Exception Handling

Feature Flags

Retry Logic

---

## Feature Organization

New business modules

Removed features

Refactored features

Feature ownership changes

---

## Configuration

Environment variables

Profiles

Secrets

Config files

Build system

Runtime

Containerization

Deployment

---

## Architectural Decisions

Determine whether any major design decisions have changed.

Examples

MVC

Layered

DDD

Hexagonal

Vertical Slice

CQRS

Event Driven

Microservices

Modular Monolith

Document additions or changes.

---

## AI Navigation

Determine whether

AI navigation instructions remain accurate.

If not

recommend updates.

---

# Diagram Review

Review every architecture diagram.

Determine whether

- components have changed
- flows have changed
- modules have changed
- relationships have changed

For every outdated diagram provide

## Existing

Short description

## Recommended Update

Describe exactly what should change.

Do NOT regenerate the entire architecture diagram unless necessary.

---

# Output Format

Generate

```
architecture-update.md
```

using the following structure.

```
# Architecture Update Report

## Summary

Overall assessment

---

## New Components

List newly discovered architecture.

---

## Changed Components

Existing documentation that should be updated.

---

## Removed Components

Documentation that should be removed.

---

## Repository Structure Updates

Directory changes.

---

## Runtime Flow Updates

Updated execution paths.

---

## Layer Updates

Responsibilities that changed.

---

## Persistence Updates

Database/repository changes.

---

## Integration Updates

External systems.

---

## Cross-Cutting Updates

Logging

Security

Tracing

Validation

etc.

---

## Feature Updates

New features or modules.

---

## Configuration Updates

Environment

Deployment

Profiles

---

## Diagram Updates

Required Mermaid modifications.

---

## AI Navigation Updates

Changes required for AI coding agents.

---

## Recommended Changes to architecture.md

Priority

High

Medium

Low

Include

- Section
- Reason
- Suggested modification

---

## Overall Documentation Health

Choose one

- Up to date
- Minor updates required
- Moderate updates required
- Major rewrite recommended

Explain why.
```

---

# Rules

Do NOT

- Rewrite architecture.md
- Duplicate unchanged documentation
- Produce implementation details
- Include source code
- Guess undocumented behavior

Always

- Compare against existing documentation
- Focus on architectural changes
- Clearly distinguish observed facts from recommendations
- Use concise, actionable language

If a section in `architecture.md` is still accurate, omit it from the report.

---

# Success Criteria

A maintainer should be able to:

- Update `architecture.md` by following only this report.
- Understand exactly what changed in the architecture.
- Avoid rereading the entire repository.
- Keep documentation synchronized with implementation over time.

The report should function as an architectural "diff" between the documented architecture and the current codebase.