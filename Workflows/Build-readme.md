# Prompt: Generate a `README.md` for Each Major Feature in an Existing Project

## Objective

You are an experienced Software Architect and Senior Software Engineer.

Your task is to analyze an **existing project** and generate a `README.md` for **each major feature/module** in the repository.

The purpose of these README files is to allow both **human developers** and **AI coding agents** to understand an individual feature without needing to understand the entire project.

Each README should be self-contained and explain everything required to work on that feature.

---

# Primary Goal

Identify every major feature in the repository.

Examples

```
users/

orders/

payments/

notifications/

authentication/

inventory/

analytics/

reporting/

search/

email/

scheduler/
```

Generate one

```
README.md
```

inside each feature directory.

Do **NOT** generate README files for utility folders such as

```
utils/

config/

common/

shared/

constants/

types/

models/
```

unless those directories themselves represent reusable modules.

---

# What is a Feature?

A feature is a cohesive business capability.

Examples

Good

```
User Management

Authentication

Orders

Payments

Notifications

Inventory

Search
```

Not Features

```
DTO

Utils

Config

Middleware

Controllers

Repositories
```

If unsure, infer feature boundaries from routing, package organization, or business logic.

---

# Repository Analysis

Before writing any README, inspect

- folder structure
- routes
- services
- repositories
- models
- configuration
- tests
- documentation

If an `architecture.md` exists, read it first.

If `AGENTS.md` exists, use it to understand conventions.

---

# Analysis Process

## Phase 1 — Identify Feature Boundary

Determine

- purpose
- responsibilities
- owned APIs
- owned data
- owned background jobs
- owned events
- owned integrations

---

## Phase 2 — Determine Public Interface

Document

REST endpoints

GraphQL

Kafka topics

Queue consumers

Queue producers

Cron jobs

CLI commands

Exports

Anything externally visible.

---

## Phase 3 — Determine Internal Structure

Explain

Directory organization

Major classes/modules

Responsibilities

Relationships

Avoid implementation details.

---

## Phase 4 — Request Flow

Describe the flow through this feature.

Example

```
Request

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

If event-driven

```
Producer

↓

Queue

↓

Consumer

↓

Business Logic
```

---

## Phase 5 — Dependencies

Document

What this feature depends on.

Examples

Authentication

Database

Redis

External APIs

Shared libraries

Messaging

Storage

Configuration

---

## Phase 6 — Owned Data

Document

Database tables

Collections

Caches

Files

Queues

Topics

Events

Anything owned by this feature.

---

## Phase 7 — Extension Points

Explain how to

- add endpoints
- add business rules
- add events
- add scheduled jobs
- add database fields
- add integrations

within this feature.

---

## Phase 8 — Testing

Determine

where tests exist

how they are organized

what should be tested when modifying this feature

---

## Phase 9 — AI Navigation

This section is mandatory.

Explain exactly how an AI agent should work inside this feature.

Examples

### Fix Bug

Inspect

Controller

↓

Service

↓

Repository

↓

Database

---

### Add Endpoint

Route

↓

Controller

↓

Service

↓

Repository

↓

Tests

---

### Modify Business Logic

Inspect

Service

Validators

Shared utilities

---

### Database Change

Repository

Migration

Model

Tests

---

# README Output Structure

Generate

```
<feature>/README.md
```

using the following structure.

```
# <Feature Name>

## Purpose

What business capability this feature provides.

---

## Responsibilities

What this feature owns.

---

## Public Interfaces

REST APIs

Events

Queues

Commands

Scheduled jobs

---

## Directory Structure

Explain important folders.

---

## Request Flow

Describe execution flow.

---

## Internal Components

Controllers

Services

Repositories

Models

Utilities

Explain responsibilities.

---

## Dependencies

Internal

External

Infrastructure

---

## Owned Data

Database

Cache

Storage

Queues

Topics

---

## Extension Guide

How to add

Endpoints

Business logic

Models

Events

Configuration

---

## Testing

Where tests are.

How to verify changes.

---

## AI Navigation Guide

How AI should navigate this feature.

---

## Related Features

Other modules this feature communicates with.

---

## Common Changes

Examples

- Add endpoint
- Fix bug
- Add validation
- Add database field
- Add scheduled task

Explain expected workflow.

---

## Notes

Feature-specific conventions or constraints.
```

---

# AI Optimization Rules

The generated README should allow an AI to work almost entirely within the feature directory.

Avoid requiring project-wide understanding whenever possible.

Document

- ownership
- dependencies
- extension points
- navigation paths
- common modifications

Explicitly state when another feature must also be modified.

---

# Documentation Style

Each README should

- be under ~300 lines
- focus on the feature
- avoid implementation details
- avoid duplicating architecture.md
- avoid duplicating AGENTS.md
- include diagrams only when helpful
- use tables where appropriate
- use markdown checklists where useful

---

# Mermaid Diagrams

Include Mermaid diagrams only if they improve understanding.

Examples

Feature request flow

Sequence diagram

Component diagram

Event flow

Dependency graph

Do not include architecture-wide diagrams.

---

# Rules

Do NOT

- rewrite architecture.md
- rewrite AGENTS.md
- describe unrelated features
- duplicate project-level documentation
- include implementation details
- invent behavior

Always

- describe only observed behavior
- keep the README feature-focused
- optimize for future maintenance
- optimize for AI navigation

---

# Success Criteria

After reading only this feature's README, a developer or AI agent should be able to:

- Understand the purpose of the feature.
- Locate all relevant code quickly.
- Safely implement new functionality.
- Fix bugs with minimal repository exploration.
- Understand dependencies and owned resources.
- Know where tests exist.
- Know when other features may also require changes.

The README should make it possible to work confidently within the feature without needing to read the rest of the repository except where explicitly noted.