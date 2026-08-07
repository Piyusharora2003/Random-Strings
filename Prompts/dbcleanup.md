Prompt: Generate an Implementation Plan

You are a senior Java architect and Spring Boot 4 engineer. Your task is not to generate code immediately. Instead, analyze the existing project and produce a detailed implementation plan for the following feature.

Objective

Implement an asynchronous API that initiates cleanup of historical data stored in a PostgreSQL database.

The endpoint should immediately return HTTP 202 (Accepted) while the cleanup continues in the background.

---

Functional Requirements

REST API

Create an endpoint to trigger history data cleanup.

- HTTP Method: "POST"
- Returns:
  - HTTP "202 Accepted"
  - Cleanup should execute asynchronously.
  - API must not wait for cleanup completion.

---

Database

Current application already connects to Oracle.

A new PostgreSQL connection must be added.

Requirements:

- PostgreSQL is used only for this cleanup activity.
- Cleanup runs approximately once per month.
- Connection pooling is not required.
- Design should keep PostgreSQL isolated from existing Oracle configuration.
- Existing Oracle functionality must remain unaffected.

---

Cleanup Logic

Delete records from the history table.

Query pattern:

DELETE FROM history_table
WHERE created_date < CURRENT_DATE - INTERVAL '<K days>';

Where:

- "K" is configurable.
- Default retention = 365 days (1 year).
- Retention period should come from configuration.

At completion capture:

- Number of records deleted.
- Total execution time.
- Cleanup status.

---

Notifications

Use the existing notification utility already available in the project.

Send notification when cleanup starts.

Example:

- History data cleanup initiated.
- Timestamp.
- Retention period.

Send another notification when cleanup completes.

Include:

- Cleanup completed.
- Number of records deleted.
- Execution duration.
- Success/Failure status.
- Error message if applicable.

Do not create a new notification mechanism.

Reuse the existing utility.

---

Logging

Follow the exact logging structure and conventions already used by the WebP Processor Service.

This includes:

- Log format
- Log levels
- Entry/Exit logs
- Error logging
- Correlation identifiers (if applicable)

Do not introduce a new logging style.

---

Error Handling

Plan should describe handling for:

- PostgreSQL connection failure
- SQL exceptions
- Partial failures
- Notification failures
- Unexpected runtime exceptions

API should still return 202 once the async task has been accepted.

Errors occurring during execution should be logged and notified appropriately.

---

Configuration

Identify all configuration required, including:

- PostgreSQL connection properties
- Cleanup retention days
- Async executor configuration (if required)

Provide recommended property names.

---

Deliverables

Produce a detailed implementation plan containing:

1. High-level architecture.
2. Component diagram.
3. Required classes and responsibilities.
4. Existing files likely to change.
5. New files to create.
6. Sequence diagram for API → Async execution → PostgreSQL → Notification.
7. Configuration changes.
8. Exception handling strategy.
9. Logging strategy.
10. Testing strategy.
11. Risks and edge cases.
12. Future extensibility recommendations.

---

Constraints

- Use Spring Boot 4.
- Use Java 21.
- Keep implementation aligned with existing project architecture.
- Reuse existing utilities wherever possible.
- Avoid unnecessary abstractions.
- Minimize impact on the Oracle datasource.
- Prefer Spring best practices.

Do not generate implementation code.

Focus only on creating a thorough execution plan that can later be implemented task-by-task.