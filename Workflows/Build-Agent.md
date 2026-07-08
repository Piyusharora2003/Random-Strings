# Prompt: Generate `AGENTS.md` for an Existing Project

## Objective

You are an experienced Software Architect and Senior Software Engineer.

Your goal is to generate an `AGENTS.md` file for an **already existing project**.

Unlike `architecture.md`, which explains **how the system is built**, `AGENTS.md` explains **how an AI coding agent should work inside this repository**.

The generated document should allow an AI coding assistant (Cline, Claude Code, Cursor, GitHub Copilot Agent, etc.) to become productive with minimal unnecessary repository exploration while maintaining consistency with the existing codebase.

This document should be optimized for AI agents first, while remaining understandable to human developers.

---

# Core Principle

This document is **not** documentation of the project.

It is documentation for **how an AI should interact with the project.**

The AI should finish reading this file and know:

- how to navigate the repository
- how to approach new tasks
- where different responsibilities belong
- coding conventions
- architectural constraints
- how to safely modify code
- what not to do

---

# Repository Analysis

Before writing this document, inspect the entire repository.

Determine:

- project structure
- architectural style
- major modules
- frameworks
- language
- build tools
- testing framework
- deployment model
- existing conventions

If an `architecture.md` file exists, read it first.

If feature README files exist, use them as additional context.

Never invent conventions that do not exist.

---

# Analysis Phases

## Phase 1 — Project Overview

Determine

- application type
- primary language
- frameworks
- package manager
- build tool
- deployment model

Summarize in a few sentences.

---

## Phase 2 — Repository Navigation

Explain the purpose of important directories.

Only include directories that are meaningful for development.

Example

```
src/controllers
Business entry points

src/services
Business logic

src/repositories
Persistence

config
Runtime configuration

tests
Unit and integration tests
```

Avoid listing every folder.

---

## Phase 3 — Development Workflow

Determine how developers currently work.

Examples

Adding an endpoint

Fixing a bug

Adding a service

Updating a model

Database migration

Configuration change

Document the expected order of changes.

---

## Phase 4 — Coding Conventions

Infer conventions from the repository.

Examples

Naming

Folder organization

Imports

Formatting

Dependency injection

Error handling

Logging

Validation

DTO usage

Repository pattern

Testing style

Only include conventions supported by the codebase.

---

## Phase 5 — Architectural Constraints

Document important rules.

Examples

Controllers never access database.

Repositories never call controllers.

Business logic belongs in services.

No SQL outside repositories.

No business logic inside routes.

No circular dependencies.

Use constructor injection.

Avoid static state.

Preserve dependency direction.

---

## Phase 6 — AI Navigation Guide

This is the most important section.

Document exactly where an AI should look for different tasks.

Examples

### Fixing an API bug

Inspect

Route

↓

Controller

↓

Service

↓

Repository

↓

Database

---

### Adding a field

Determine

DTO

↓

Validation

↓

Service

↓

Repository

↓

Migration

↓

Tests

---

### Debugging authentication

Inspect

Middleware

↓

Token validation

↓

Authorization

↓

Route guards

---

### Performance issue

Inspect

Database queries

↓

Caching

↓

External APIs

↓

Loops

↓

Memory allocations

---

### Logging issue

Inspect

Middleware

↓

Logger

↓

Global exception handler

---

Provide repository-specific guidance.

---

## Phase 7 — Modification Strategy

Document how AI should modify code.

Principles

- Make the smallest possible change.
- Preserve public interfaces unless required.
- Avoid unnecessary refactoring.
- Follow existing project patterns.
- Reuse existing utilities.
- Keep related changes together.
- Prefer consistency over personal preference.

---

## Phase 8 — Testing Strategy

Determine

Unit tests

Integration tests

E2E tests

Mocking

Fixtures

Coverage expectations

How tests are executed

What should be tested after changes

---

## Phase 9 — Documentation Strategy

Explain

When documentation should be updated.

Examples

New endpoint

New feature

New environment variable

Architecture change

Database change

Public API change

---

## Phase 10 — Safe Refactoring Rules

Document when refactoring is acceptable.

Examples

Allowed

- Remove duplication
- Improve naming
- Extract helper methods
- Simplify logic

Avoid

- Large rewrites
- Framework migration
- Folder restructuring
- Architectural changes
- API redesign

Unless explicitly requested.

---

# AI Behavior Rules

Include a dedicated section called

```
AI Operating Guidelines
```

Include rules similar to:

- Understand before editing.
- Search narrowly before searching globally.
- Read only the files needed.
- Reuse existing implementations.
- Follow established patterns.
- Never introduce new libraries without justification.
- Never change architecture unless requested.
- Preserve backwards compatibility.
- Prefer incremental changes.
- Ask for clarification if requirements are ambiguous.
- Explain significant architectural changes after implementation.

---

# Output Structure

Generate a single file

```
AGENTS.md
```

using the following sections.

```
# AGENTS.md

## Purpose

## Project Overview

## Repository Navigation

## Architecture Summary

## Development Workflow

## Coding Conventions

## Architectural Constraints

## AI Navigation Guide

## Modification Strategy

## Testing Strategy

## Documentation Rules

## Safe Refactoring Rules

## AI Operating Guidelines

## Common Tasks

## Repository Checklist
```

---

# Common Tasks Section

Generate repository-specific instructions for common work.

Examples

### Add API Endpoint

### Fix Existing Bug

### Add Database Table

### Update Existing Model

### Add Background Worker

### Add Scheduled Job

### Integrate External Service

### Modify Configuration

### Update Tests

Describe the expected workflow for each task.

---

# Repository Checklist

Generate a checklist AI agents should complete before finishing work.

Example

```
□ Project builds successfully

□ Tests pass

□ No unused imports

□ Logging preserved

□ Error handling consistent

□ Documentation updated

□ API compatibility maintained

□ Existing patterns followed

□ No unrelated files modified

□ Configuration unchanged unless required
```

---

# Style Requirements

The generated document should be

- concise
- actionable
- repository-specific
- optimized for AI agents
- easy for humans to review
- free of implementation details
- focused on developer workflow

Use

- markdown headings
- tables where appropriate
- checklists
- short paragraphs
- decision trees if useful

Avoid large walls of text.

---

# Rules

Do NOT

- describe implementation details
- duplicate README content
- rewrite architecture.md
- invent coding standards
- recommend new architecture unless explicitly requested

Always

- infer patterns from the existing repository
- prefer observed conventions over best practices
- optimize for reducing unnecessary repository exploration
- document how work should be performed rather than how the software works

---

# Success Criteria

After reading only `AGENTS.md`, an AI coding agent should be able to:

- Navigate directly to relevant parts of the codebase.
- Understand where different responsibilities belong.
- Follow the project's existing conventions.
- Perform targeted bug fixes.
- Implement new features consistently.
- Avoid unnecessary repository scanning.
- Make minimal, safe, maintainable changes.
- Know when supporting documentation should also be updated.
```