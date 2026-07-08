# Spring Backend PR Review Skill

**Stack:** Java 17 · Spring Boot 3 · MyBatis · PostgreSQL · Redis · REST · Maven · JUnit 5 · Mockito · SLF4J · Jackson · Docker

This document defines **what good code looks like** and **how to evaluate it** for this stack. It does not describe the review process itself (see the review Workflow for that) — it is the standard the reviewer applies once a PR is in front of it.

---

## Purpose

Give an AI reviewer a consistent, opinionated, stack-specific definition of production-ready Java backend code, so that review quality does not vary by PR, reviewer mood, or phrasing of the diff. The skill exists to catch things that matter — correctness, architecture, security, performance, testability — without turning into a style nag.

---

## Review Philosophy

Priority order when issues compete for attention:

1. **Correctness** — does it do what it claims, including edge cases?
2. **Architecture** — is it in the right layer, with the right dependencies?
3. **Maintainability** — will the next engineer understand and safely change this?
4. **Security** — does it introduce or fail to close an attack surface?
5. **Performance** — will it degrade under real load/data volume?
6. **Testing** — is the behavior actually verified?
7. **Readability** — can it be understood at a glance?
8. **Style** — formatting, naming polish, minor idiom preferences.

Rules of engagement:

- **Never block a PR on formatting alone.** If a linter/formatter can catch it, it isn't a review comment.
- **Every comment explains itself.** State the issue, why it matters (concrete consequence — bug, outage, security hole, unreadable code, slow query), and a better alternative. A comment that only says "this is bad" is not acceptable output.
- **Calibrate to blast radius.** A questionable helper method in a rarely-touched batch job is not equivalent to a questionable query in a hot checkout path.
- **Prefer teaching over dictating.** Explain the principle so the pattern is recognized next time, not just fixed this time.

---

## Review Order

Work top-down; each layer assumes the ones before it are sound, so don't spend deep effort on style while correctness is still broken.

1. Does the change compile conceptually / do the described behaviors make sense (correctness pass)?
2. Is it in the right architectural layer, with dependencies pointing the right direction?
3. Are transactions, validation, and error handling correctly scoped?
4. Are there security or data-integrity exposures?
5. Are there performance red flags (N+1, unbounded loads, blocking calls in async paths)?
6. Is the change adequately tested?
7. Is it readable and consistent with repo conventions?
8. Does documentation need to change alongside it?

---

## SOLID Review

Each principle is reviewed independently. A violation is only worth flagging if it will bite someone — not every class needs to be textbook-perfect.

### Single Responsibility Principle (SRP)

**Explanation:** A class/method should have one reason to change. In Spring Boot this usually means: one concern per service method, not "validate + persist + send email + publish event" all inline.

**Detect violations by asking:** "If requirement X changes, does this class also need to change for reason Y, an unrelated reason?" A `UserService` that does authentication, email dispatch, and report generation has three reasons to change.

**Good:**
```java
@Service
class OrderService {
    OrderService(OrderRepository repo, PaymentGateway gateway, OrderEventPublisher publisher) { ... }

    Order placeOrder(PlaceOrderCommand cmd) {
        Order order = orderFactory.create(cmd);
        repo.save(order);
        publisher.publish(new OrderPlacedEvent(order.getId()));
        return order;
    }
}
```

**Bad:**
```java
@Service
class OrderService {
    Order placeOrder(PlaceOrderRequest req) {
        // validates raw request fields
        // builds SQL manually
        // calls payment provider
        // formats and sends confirmation email
        // logs analytics event
    }
}
```

**Common Spring Boot mistake:** "God services" — one `@Service` injected into every controller, accumulating unrelated methods because it's already there and already autowired.

### Open/Closed Principle (OCP)

**Explanation:** Code should be extensible without modifying existing, tested logic — typically via interfaces/strategy patterns, not via a chain of `if/else` on a type field.

**Detect violations by asking:** does adding a new case (new payment type, new notification channel) require editing an existing `switch`/`if-else` chain scattered across the codebase?

**Good:**
```java
interface DiscountStrategy { BigDecimal apply(Order order); }

@Component class LoyaltyDiscount implements DiscountStrategy { ... }
@Component class SeasonalDiscount implements DiscountStrategy { ... }
```
A new discount type is a new class, not an edited one.

**Bad:**
```java
BigDecimal calculateDiscount(Order order) {
    if (order.getType() == LOYALTY) { ... }
    else if (order.getType() == SEASONAL) { ... }
    else if (order.getType() == FLASH_SALE) { ... } // grows forever
}
```

**Common Spring Boot mistake:** giant `switch` statements on an enum inside a `@Service`, instead of injecting a `List<Strategy>` and selecting by type.

**Caveat:** don't demand a strategy pattern for two cases that will never grow to three — that's overengineering, not OCP.

### Liskov Substitution Principle (LSP)

**Explanation:** A subtype must be usable anywhere its supertype is expected without breaking correctness — no strengthened preconditions, no weakened postconditions, no surprise exceptions.

**Detect violations by asking:** does overriding a method throw `UnsupportedOperationException`, return null where the base contract guarantees a value, or silently no-op?

**Bad:**
```java
class ReadOnlyRepository extends CrudRepository<Order> {
    @Override
    void save(Order o) { throw new UnsupportedOperationException(); } // violates the contract callers rely on
}
```

**Good:** split into a smaller interface (`OrderReader`) that only exposes what's actually supported, rather than inheriting and breaking half the contract.

**Common Spring Boot mistake:** subclassing a JPA/MyBatis mapper interface or a generic base service to "borrow" behavior, then overriding half the methods to throw or return dummy values.

### Interface Segregation Principle (ISP)

**Explanation:** Clients shouldn't depend on methods they don't use. Fat interfaces force irrelevant implementations and irrelevant mocks in tests.

**Detect violations by asking:** in a test, are you forced to stub five methods on a mock to test the one method you care about?

**Bad:** one `UserOperations` interface with 20 methods, injected everywhere, where most consumers use 2.

**Good:** `UserReader`, `UserWriter`, `UserPasswordManager` as separate narrow interfaces, composed where needed.

**Common Spring Boot mistake:** a single repository interface accumulating every possible query method used by every possible caller, rather than scoping queries to the service that actually needs them.

### Dependency Inversion Principle (DIP)

**Explanation:** High-level modules (services) should depend on abstractions, not concrete low-level modules (a specific HTTP client, a specific MyBatis mapper implementation detail, a specific third-party SDK class).

**Detect violations by asking:** does a `@Service` `new` up a concrete client, or hold a direct reference to a vendor SDK class in its public API, rather than depending on an interface owned by the domain?

**Bad:**
```java
@Service
class NotificationService {
    private final TwilioClient twilio = new TwilioClient(apiKey); // concrete, unmockable, vendor-leaked
}
```

**Good:**
```java
interface SmsSender { void send(String to, String message); }

@Service
class NotificationService {
    NotificationService(SmsSender smsSender) { ... } // depends on abstraction
}

@Component
class TwilioSmsSender implements SmsSender { ... }
```

**Common Spring Boot mistake:** letting a third-party SDK's request/response types leak into service or controller signatures instead of wrapping them behind a domain-owned interface.

---

## OOP Review

- **Encapsulation:** domain state should not be mutable from outside via public setters with no invariant checks. Prefer constructors/factory methods that enforce invariants, and behavior methods (`order.cancel()`) over `order.setStatus(CANCELLED)` from a service.
- **Abstraction:** callers should depend on *what* an object does, not *how*. A `PricingEngine` interface should hide whether pricing is computed locally or fetched remotely.
- **Inheritance:** avoid it for code reuse alone. Only use inheritance for genuine "is-a" relationships with a stable contract (e.g., an abstract base handler in a `@ControllerAdvice` hierarchy). If you're inheriting just to share three utility methods, that's a signal for composition or a shared collaborator instead.
- **Composition:** default choice for reuse — inject a collaborator rather than extend a class. Composition keeps dependencies explicit and testable; inheritance hides them.
- **Polymorphism:** prefer interface dispatch (Strategy, Visitor-lite) over `instanceof` chains or type-code `switch` statements scattered through the codebase.
- **Immutable objects:** DTOs, value objects, and events should be immutable (Java `record`s where possible) unless there's a specific reason for mutability (e.g., a JPA/MyBatis-managed entity with lifecycle needs). Immutability removes a whole class of "who mutated this and when" bugs, especially under concurrency.
- **Proper object responsibilities:** an object should own the logic for its own invariants (e.g., `Order.canBeCancelled()` lives on `Order`, not scattered as `if` checks in three different services).

---

## Spring Boot Review

**Controllers**
- Thin: request/response mapping, delegation, and HTTP concerns only. No business logic, no direct persistence calls.
- Return DTOs, never entities/mapper result objects directly — this couples the API contract to the persistence model and risks leaking internal fields.
- Use `ResponseEntity` deliberately for status-code control; don't overuse it where a plain return + `@ResponseStatus` is clearer.

**Services**
- Own business logic and orchestration. Should be framework-agnostic where reasonable — a service shouldn't need `HttpServletRequest` to do its job.
- Should not directly build SQL or reach into `DataSource`; that's the mapper's job.

**Repositories / Mapper layer**
- Persistence logic only — no business rules, no validation beyond data-shape constraints.
- Should not leak MyBatis-specific types (e.g., `RowBounds`, raw `Map<String,Object>` params) into the service layer's public contracts.

**Configuration & Beans**
- `@Configuration` classes should be focused (one concern: web config, security config, cache config) rather than one giant `AppConfig`.
- Avoid field injection (`@Autowired` on a field); use constructor injection — it makes dependencies explicit, enables `final` fields, and makes testing without Spring trivial.
- Beans with mutable shared state must be thread-safe (default Spring bean scope is singleton).

**Dependency Injection**
- Flag circular dependencies (even if `@Lazy` "fixes" it — that's usually a design smell, not a solution).
- Constructor injection > setter injection > field injection, in that order of preference.

**Profiles**
- Environment-specific beans/config should use `@Profile` or `application-{profile}.yml`, not `if (env.equals("prod"))` branching in business code.

**Transactions**
- `@Transactional` should be on the service layer, on public methods, called from outside the class (self-invocation bypasses the proxy — a common silent bug).
- Watch for read-only transactions marked as such (`@Transactional(readOnly = true)`) for query-only methods — real performance win with MyBatis + connection pooling.
- Transaction boundaries should not wrap slow, non-transactional work (HTTP calls, email sending) — this holds a DB connection open needlessly and risks pool exhaustion.
- Verify rollback rules: by default only unchecked exceptions roll back; if the code intentionally throws checked exceptions expecting rollback, it needs `rollbackFor`.

**Validation**
- Request DTOs use Bean Validation (`@NotNull`, `@Size`, etc.) rather than manual `if (field == null) throw ...` scattered in controllers.
- Cross-field/business validation belongs in the service layer, not annotations (annotations can't express "start date before end date" cleanly without a custom validator).

**Exception Handling**
- Centralized via `@RestControllerAdvice`, not per-controller `try/catch` blocks that each format their own error JSON.
- Exceptions should be specific and meaningful (`OrderNotFoundException`), not generic (`RuntimeException("error")`).

**DTO usage**
- Never expose persistence/mapper result objects directly over REST — always map to a DTO, even if it currently looks identical, because API and persistence models evolve independently.

**Serialization (Jackson)**
- Explicit handling of nulls, dates (use `Instant`/`LocalDateTime` with proper Jackson modules, not ad hoc string formatting), and unknown properties (`@JsonIgnoreProperties(ignoreUnknown = true)` where appropriate for forward compatibility).
- Be deliberate about `@JsonInclude` for nulls in high-volume APIs — silent payload bloat matters at scale.

**Configuration Properties**
- Use `@ConfigurationProperties` classes for grouped, typed config rather than scattering `@Value("${...}")` across many classes — improves validation and discoverability.

**Auto Configuration**
- Don't fight Spring Boot's auto-configuration with manual bean definitions unless there's a documented reason; note the reason in a comment so the next reader isn't confused about why it's manual.

**Lifecycle**
- `@PostConstruct`/`@PreDestroy` (or `InitializingBean`/`DisposableBean`) used for necessary setup/teardown only — heavy work here can delay app startup or shutdown in ways that are hard to trace.

**Scheduling**
- `@Scheduled` methods must be idempotent and must not assume single-instance deployment (multiple pods will all fire the schedule) unless a distributed lock is used.

**Caching**
- `@Cacheable`/`@CacheEvict` pairs must be checked together — a cache that's populated but never evicted on write is a correctness bug waiting to happen, not just a performance one.
- Cache keys must be unambiguous (watch out for overloaded methods or missing `key =` SpEL when parameters aren't naturally unique).

**AOP**
- Aspects should be narrowly scoped (specific annotation/pointcut) — broad package-wide pointcuts make behavior hard to trace and slow down the codebase's "grep-ability."

**Interceptors / Filters**
- Cross-cutting HTTP concerns (auth, logging, correlation IDs) belong here, not duplicated in every controller.
- Filters should be lightweight; heavy logic in a filter runs on every request including ones that don't need it.

---

## MyBatis Review

**Mapper Interfaces**
- One mapper per aggregate/table family, methods named by intent (`findActiveOrdersByCustomer`), not by raw SQL shape.

**Mapper XML**
- SQL should be readable and formatted — this is the one place hand-written SQL lives, so it deserves the same care as Java code.
- No business logic in XML (`<if>` for optional filters is fine; computing derived business values in SQL that duplicates Java logic is not).

**Dynamic SQL**
- `<if>`/`<choose>` blocks must be checked for a dangling `AND`/`WHERE` — use `<where>` and `<trim>` helpers rather than manual string concatenation.
- Every dynamic filter branch should be covered by a test — dynamic SQL is exactly where "worked on the happy path, broke on the second filter combination" bugs live.

**Result Maps**
- Explicit `<resultMap>` for anything beyond trivial flat queries; relying on auto-mapping for nested objects/collections invites silent null fields when column names drift.

**Parameter Mapping**
- Use `#{}` always for values (parameterized, injection-safe). `${}` is a **critical security flag** unless the value is a fully sanitized, whitelisted identifier (e.g., a column name from a fixed enum) — flag any `${}` usage touching user input.

**Transactions**
- Multiple related mapper calls that must be atomic need to be wrapped in a single `@Transactional` service method, not left to "probably fine" independent calls.

**Batch Queries**
- Row-by-row inserts/updates in a loop calling a mapper method individually should be flagged — use MyBatis batch mode (`ExecutorType.BATCH`) or a single `<foreach>` bulk statement for anything beyond a handful of rows.

**N+1 Queries**
- The single most common MyBatis review finding: a list query followed by a per-row mapper call inside a loop (often hidden inside a nested `resultMap` with `select=` lazy association). Flag it and require either a join-based single query or explicit batch fetch.

**Reusable SQL**
- Repeated column lists / join fragments should use `<sql id="...">` + `<include>` rather than copy-pasted across statements — duplication here rots silently because it's not compiled.

**Pagination**
- Never paginate in application code by loading the full result set and slicing it in Java. Use `LIMIT`/`OFFSET` (or keyset pagination for large offsets) in the query itself.
- Watch for `RowBounds` misuse, which still fetches all rows from the DB under the hood in older/naive configurations — confirm the actual SQL is bounded.

**Naming**
- Mapper XML `id` should match the interface method name exactly; parameter and result map names should be descriptive, not `map1`, `param`.

**Mapper organization**
- One XML file per mapper interface, colocated by feature/module, not one mega-XML per schema.

**Common mistakes**
- String-concatenated SQL instead of `#{}` bindings.
- Missing indexes for columns used in frequent `WHERE`/`JOIN`/`ORDER BY` in a new query (cross-check against Database Review).
- Nested `resultMap` associations triggering lazy N+1 without the author realizing it.

---

## REST API Design Review

- **Endpoint naming:** plural nouns, resource-oriented (`/orders/{id}/items`), not verbs (`/getOrderItems`).
- **HTTP verbs:** `GET` safe/no side effects, `POST` for create/non-idempotent actions, `PUT` for full replace (idempotent), `PATCH` for partial update, `DELETE` for removal. Flag a `GET` that mutates state — this breaks caching, prefetching, and idempotency assumptions.
- **Status codes:** `200`/`201`/`204` for success shapes, `400` for validation, `401`/`403` for auth, `404` for missing resources, `409` for conflicts, `422` where the org convention uses it, `5xx` reserved for actual server failures — not used as a catch-all for business rule violations.
- **Idempotency:** `PUT`/`DELETE` must be safe to retry; `POST` for critical operations (payments) should support an idempotency key if retries are plausible (client timeout + retry is a real-world scenario, not an edge case).
- **Pagination:** list endpoints must be paginated by default once a table can grow unbounded — no "return everything" endpoints for tables that will have more than a few hundred rows in production.
- **Filtering/Sorting:** validate filter/sort fields against a whitelist; don't pass raw query params straight into a MyBatis `ORDER BY` (SQL injection risk via `${}`).
- **Versioning:** breaking changes require a new version path/header per repo convention — don't silently change response shape on an existing endpoint.
- **Error responses:** consistent shape across the whole API (error code, message, optionally field-level validation errors) — not one-off JSON per controller.
- **Validation:** request DTOs validate input at the boundary; don't rely on the database constraint to be the only line of defense (bad UX, and leaks DB-level error text).
- **Request/Response DTOs:** never reused as the same class for both directions when their constraints differ (e.g., `id` required on response, forbidden on create request).
- **Consistency:** naming, casing, date formats, and error shapes should match the rest of the API surface, not just be "fine in isolation."

---

## Database Review

- **Normalization:** flag obvious redundancy that will drift out of sync (storing a derived total that's also computed elsewhere), but don't demand textbook 3NF where a deliberate denormalization is a documented performance tradeoff.
- **Indexes:** any new query with a `WHERE`, `JOIN`, or `ORDER BY` on a column should have a matching index unless the table is small/rarely queried. Check the migration for it, not just the mapper XML.
- **Constraints:** `NOT NULL`, `UNIQUE`, `CHECK`, and foreign keys should be used to enforce invariants at the DB level, not left purely to application code — application-only validation is bypassable by any other future caller of the same table.
- **Transactions:** multi-statement writes affecting related rows must be transactional; flag any sequence of independent writes that should be atomic but isn't.
- **Foreign keys:** relationships should be declared, not just implied by a column name — undeclared FKs let orphaned rows accumulate silently.
- **Readability/Naming:** consistent snake_case (or repo convention), descriptive table/column names, no abbreviations that aren't already established in the schema.
- **Query efficiency:** watch for `SELECT *` in production code paths, unnecessary joins pulling in unused columns, and queries that can't use an index due to a function wrapped around the indexed column (`WHERE LOWER(email) = ...` without a matching functional index).
- **Batch operations:** bulk writes should be batched, not row-by-row (see MyBatis Batch Queries).
- **Optimistic locking:** version columns / `WHERE version = ?` checks for concurrent update scenarios where lost updates matter (e.g., inventory counts, balances).
- **Pessimistic locking:** `SELECT ... FOR UPDATE` used deliberately and narrowly scoped — flag broad or long-held locks that will cause contention under load.
- **Connection management:** no manual connection handling outside the managed `DataSource`/connection pool; verify pool size assumptions are sane for the deployment (e.g., a scheduled job spawning many threads each grabbing a connection can exhaust the pool).

---

## System Design Review

- **Single Responsibility / Separation of Concerns:** each module/package owns one bounded area; cross-cutting reach into another module's internals is a flag.
- **High Cohesion / Low Coupling:** related logic lives together; unrelated logic doesn't share a class just because it was convenient.
- **Dependency Direction:** dependencies point from outer layers (controller) to inner (domain/service) to persistence — never the reverse (a domain class importing a controller-layer type is backwards).
- **Layer Responsibilities:** controller → service → repository/mapper, each doing only its job (cross-reference Spring Boot Review).
- **Feature Ownership:** new code should live where the feature's existing code lives, not bolted onto an unrelated module for convenience.
- **Extension Points:** genuinely likely future variation points should be designed for extension (interfaces); unlikely ones should not be pre-abstracted (YAGNI).
- **Scalability:** does this design assume a single instance where the app is deployed with multiple replicas (in-memory caches, schedulers, in-memory queues without a distributed backing)?
- **Reliability/Availability:** are failure modes of downstream calls (timeouts, partial failures) handled, or does one slow dependency take down the whole request?
- **Statelessness:** application instances should not hold per-request or per-user state in memory across requests (breaks horizontal scaling and rolling deploys) — session-like state belongs in Redis/DB, not a static map.
- **Idempotency / Retry Safety:** anything that might be retried (message consumers, scheduled jobs, client-retried POSTs) must tolerate being run twice without duplicating side effects.
- **Caching:** cache invalidation strategy must be explicit — stale-cache bugs are a common production incident source.
- **Concurrency:** shared mutable state across requests must be protected or avoided (see Concurrency Review).

---

## Concurrency Review

- **ExecutorService:** custom thread pools must be sized deliberately and shut down cleanly (don't leak threads on app shutdown); prefer a named, bounded pool over `Executors.newCachedThreadPool()` in production code (unbounded growth risk).
- **CompletableFuture:** exceptions in async chains must be handled (`exceptionally`/`handle`) — an unhandled exception in a fire-and-forget future disappears silently.
- **Locks:** prefer `java.util.concurrent` locks over `synchronized` when timeout/interruptibility is needed; any lock held across a blocking I/O call (DB, HTTP) is a red flag for contention.
- **Synchronization:** flag `synchronized` on methods of a Spring singleton bean handling concurrent requests — this serializes all requests through that bean and is a common accidental throughput killer.
- **Atomic classes:** prefer `AtomicInteger`/`AtomicReference`/etc. over hand-rolled `synchronized` counters where applicable — simpler and correctly implemented.
- **Thread safety:** singleton-scoped beans with mutable fields are shared across all concurrent requests — any such field needs a specific thread-safety justification.
- **Race conditions:** check-then-act sequences on shared state (`if (!exists) create()`) need a DB constraint, lock, or atomic operation, not just a Java-level check — the window between check and act is a real bug in production traffic.
- **Deadlocks:** multiple locks acquired in more than one order across the codebase is a deadlock risk — flag inconsistent lock ordering.
- **Blocking calls:** blocking I/O (JDBC via MyBatis, synchronous HTTP clients) inside a reactive or async-executor context can starve the pool — flag mixing blocking calls into non-blocking infrastructure.
- **Resource cleanup:** try-with-resources (or explicit `finally`) for anything `Closeable` — connections, streams, locks must always release, including on the exception path.
- **MDC propagation:** MDC (e.g., trace ID) is thread-local; when work is handed off to another thread (`ExecutorService`, `@Async`, `CompletableFuture`), the context must be explicitly propagated or logs lose correlation.

---

## Performance Review

- **Object allocation:** avoid unnecessary allocation in hot paths (creating new formatter/mapper instances per call instead of reusing a shared, thread-safe one).
- **Streams:** Stream API is fine for readability; flag it when used for a simple loop where it adds overhead and hurts readability, or when it's doing something stateful/side-effecting that a `for` loop would express more clearly.
- **Collections:** right collection for the access pattern (`List` vs `Set` vs `Map` — flag `O(n)` `contains()` checks in a loop that should be a `Set`/`Map` lookup).
- **Database calls:** no DB call inside a loop (classic N+1, see MyBatis Review); batch or join instead.
- **Caching:** repeated computation/lookup of the same rarely-changing value within a request or across requests is a caching candidate — flag missed opportunities in hot paths, but don't demand caching for cold/rarely-hit code.
- **Lazy loading:** understand what triggers a lazy fetch in the mapping layer; flag accidental eager materialization of large collections that are rarely needed.
- **Repeated calculations:** a value computed multiple times from the same inputs within one method/request should be computed once and reused.
- **Algorithm complexity:** flag obviously quadratic-or-worse logic over collections that can be sized in the thousands or more in production (nested loops doing linear search).
- **Memory:** large in-memory collections built from a full table scan should be flagged in favor of paginated/streamed processing.
- **Serialization:** flag expensive per-request serialization/deserialization patterns (e.g., re-parsing the same static config JSON on every request instead of once at startup).
- **Network calls:** synchronous chained calls to multiple external services in sequence where they could be parallelized are a latency flag.
- **Connection pooling:** verify DB/HTTP client connection pools are reused (injected, singleton-scoped clients), not created per-request.

---

## Security Review

- **Authentication:** endpoints must have explicit auth requirements; flag any new endpoint that's unintentionally public because a security config wasn't updated.
- **Authorization:** authentication ≠ authorization — verify object-level checks exist (a logged-in user shouldn't be able to fetch another user's order by guessing an ID; check for **IDOR**).
- **Input validation:** all external input (request body, query params, headers) validated at the boundary — never trusted as-is.
- **SQL Injection:** any `${}` in MyBatis touching user input, or any manually concatenated SQL string, is a **Critical** finding.
- **XSS:** user-supplied content rendered anywhere (including admin tools, emails) must be properly escaped/encoded for its output context.
- **CSRF:** state-changing endpoints relying on cookie-based auth need CSRF protection unless the app is fully stateless with token-based auth (verify which model applies before flagging).
- **Sensitive logging:** passwords, tokens, full card numbers, and other secrets must never appear in log statements — including inside exception messages or serialized request/response logging.
- **Secrets:** no hardcoded credentials/API keys in code or config committed to the repo; secrets come from environment/secret manager.
- **Encryption:** sensitive data at rest (PII, credentials) should be encrypted or hashed as appropriate; sensitive data in transit requires TLS — flag any new outbound call to a sensitive endpoint over plain HTTP.
- **Token handling:** tokens (JWT, API keys) validated for signature/expiry on every use, not just presence; avoid storing tokens in places accessible to XSS (e.g., `localStorage` from a backend-issued token when an httpOnly cookie is safer — flag if it deviates from repo convention without reason).
- **Session management:** session tokens rotated on privilege change (e.g., login), proper expiry, and invalidated server-side on logout where applicable.
- **OWASP Top 10:** use as a mental checklist for anything touching auth, input handling, or dependencies — don't require the reviewer to cite it, just make sure the categories are actually covered by the above points.

---

## Logging Review

- **Structured logging:** prefer structured/keyed log fields over string-concatenated messages, consistent with the repo's existing logging approach.
- **Log levels:** `ERROR` for actual failures needing attention, `WARN` for recoverable/unexpected-but-handled situations, `INFO` for significant business events, `DEBUG` for diagnostic detail — flag `ERROR`-level logs for expected/handled conditions (alert fatigue) and missing `ERROR` logs for actual unhandled failures.
- **Trace IDs / MDC:** requests should carry a correlation/trace ID through logs across service boundaries; flag new async/background work that drops this context (see Concurrency: MDC propagation).
- **Sensitive information:** no PII/secrets in log statements (cross-reference Security Review).
- **Consistency:** log message format/style consistent with the rest of the codebase.
- **Actionability:** an `ERROR` log should give the next on-call engineer enough context (identifiers, relevant state) to act without needing to reproduce the bug from scratch.
- **Production readiness:** no leftover `System.out.println`/debug logging; no logging inside tight loops that will flood production logs under real volume.

---

## Error Handling Review

- **Custom exceptions:** domain-specific exceptions (`OrderNotFoundException`) over generic ones (`RuntimeException`), so callers and the global handler can react meaningfully.
- **Global exception handlers:** `@RestControllerAdvice` maps exceptions to the correct status code and a consistent error shape; verify a new exception type is actually handled somewhere and won't fall through to a generic 500.
- **Meaningful messages:** exception messages should help debugging (include relevant identifiers) without leaking sensitive internals to the client (stack traces, SQL, secrets).
- **Failure isolation:** a failure in one part of a request (e.g., optional enrichment call) shouldn't take down the whole response if the core operation could still succeed — verify this is intentional, not accidental.
- **Retries:** retries used for transient failures (network blips) only, with backoff, and only where the operation is idempotent — flag retries wrapped around non-idempotent writes.
- **Fallbacks:** fallback behavior (default value, cached value, degraded response) should be a deliberate decision, documented in code, not a silently swallowed exception.
- **Recovery:** verify the system can recover cleanly after a failure (no partial state left behind, no connection/resource leaked) — cross-reference Concurrency: Resource cleanup.

---

## Validation Review

- **Bean Validation:** `@NotNull`, `@Size`, `@Pattern`, etc. on request DTOs for structural/format checks — this is boundary validation, not business validation.
- **Business validation:** rules that depend on other data or state (uniqueness, cross-field, workflow-state checks) belong in the service layer, with clear, catchable exceptions.
- **Input sanitization:** anything that flows into SQL (`${}` usage), HTML output, file paths, or shell commands needs explicit sanitization/whitelisting — never trust the shape of "clean" input.
- **Null safety:** flag unguarded dereferences of values that can legitimately be null (`Optional` misuse, nullable mapper results); prefer `Optional` at API boundaries where absence is a valid, common case.
- **Defensive programming:** guard clauses for invalid state should fail fast with a clear exception rather than proceeding with implicit assumptions.

---

## Testing Review

- **Unit testing:** service-layer business logic should have unit tests with dependencies mocked (Mockito) — testing the actual decision logic, not just that mocks were called.
- **Integration testing:** MyBatis mappers and full request flows should have integration tests against a real (or Testcontainers) database — SQL correctness can't be verified by mocking the mapper.
- **Mockito usage:** mock collaborators, not the class under test; avoid over-mocking that verifies implementation details instead of behavior (excessive `verify()` chains that break on any refactor).
- **Test naming:** descriptive of scenario and expectation (`shouldThrowWhenOrderAlreadyCancelled`), not `test1`, `testOrder`.
- **Assertions:** specific assertions (assert the actual value/exception type/message), not just "no exception thrown" or overly loose assertions that would pass for wrong output.
- **Edge cases:** boundary values, empty collections, nulls where legal, max sizes — flag tests that only cover the one happy path shown in the PR description.
- **Negative tests:** invalid input, unauthorized access, not-found scenarios should have explicit tests, not just implicit trust in the framework.
- **Parameterized tests:** used for the same logic across multiple input variations instead of near-duplicate copy-pasted test methods.
- **Coverage expectations:** new business logic must be tested; flag PRs that add branching logic (`if`/`switch`) with no corresponding test for each branch — but don't demand tests for trivial getters/DTOs or framework-generated code.

---

## Maintainability Review

- **Code duplication:** near-identical logic copy-pasted across services/mappers should be extracted — but two or three short, coincidentally-similar snippets don't automatically need a shared abstraction (see False Positive Rules).
- **Reusability:** shared logic placed in a common, discoverable location (utility class, shared service) rather than re-implemented per feature.
- **Configuration:** environment-specific or tunable values externalized to config, not hardcoded magic numbers/URLs in code.
- **Constants:** repeated literal values (status strings, magic numbers with business meaning) extracted to named constants/enums.
- **Utilities:** utility classes should be genuinely generic/stateless; a "Utils" class accumulating unrelated one-off methods is itself a maintainability smell worth naming.
- **Package organization:** consistent with the repo's existing structure (feature-based vs layer-based) — don't introduce a competing organizational style in one PR.
- **Extensibility:** code should accommodate reasonably foreseeable extension (new enum values, new strategy implementations) without requiring a rewrite — balanced against not over-abstracting for hypothetical futures.
- **Technical debt:** if the PR knowingly introduces a shortcut, it should be flagged with a comment/ticket reference, not left silent for the next person to discover.

---

## Documentation Review

Check whether the change requires updates to:

- **Feature README** — new module, new setup step, new env var.
- **architecture.md** (or equivalent) — new service, new external dependency, changed data flow.
- **AGENTS.md** (or equivalent AI-agent operating instructions) — new conventions, new commands, changed project structure that an AI agent would need to know.
- **Configuration documentation** — new/changed `@ConfigurationProperties`, new required environment variables.
- **Migration guide** — breaking schema or API changes that downstream consumers/operators need to act on.
- **API documentation** — new/changed endpoints, request/response shape changes, new error codes.

A PR that changes behavior documented elsewhere without updating that documentation should be flagged, even if the code itself is correct — stale docs are a maintainability liability.

---

## Severity Classification

| Severity | When to use it | Example | Expected developer action |
|---|---|---|---|
| **Critical** | Will cause data loss, security breach, or production outage; must not merge as-is. | SQL injection via `${}`; missing authorization check on a sensitive endpoint; transaction not rolled back on failure, corrupting data. | Fix before merge — blocking. |
| **High** | Significant correctness, architecture, or performance risk under realistic production conditions. | N+1 query on a high-traffic endpoint; unhandled exception path that silently drops user data; circular dependency between core modules. | Fix before merge, or explicit sign-off with a tracked follow-up if truly time-boxed. |
| **Medium** | Real problem, but bounded impact or low likelihood; doesn't require blocking. | Missing test coverage for a non-trivial branch; a service method doing slightly more than its single responsibility; a cache with no eviction on a low-traffic entity. | Should fix in this PR; acceptable to defer with a linked follow-up ticket if agreed. |
| **Low** | Minor maintainability/readability concern with limited future cost. | A magic number that should be a named constant; a slightly-too-long method that's still readable; a duplicated 3-line snippet. | Optional fix; author's discretion. |
| **Suggestion** | Idea that could improve the code but isn't a problem as-is. | An alternative pattern that might read more cleanly; a possible future extension point. | No action required; take it or leave it. |

---

## False Positive Rules

Do **not** report an issue when:

- An existing, established repo convention intentionally differs from general best practice (e.g., the repo consistently uses field injection in test classes, or a specific package layout) — follow the repo, don't fight it.
- Small methods are intentionally duplicated for readability/independence rather than sharing a fragile abstraction (e.g., two similar-looking validation methods that will diverge as business rules evolve).
- A performance optimization is suggested for code with no realistic scale to justify it (a config-loading method called once at startup does not need to be optimized like a hot request path).
- Code is framework-managed and the "smell" is inherent to the framework's contract (e.g., a Spring `@Configuration` class technically violating SRP by declaring multiple unrelated beans — that's how Spring config classes work).
- The "violation" is inside test code where the tradeoffs are different (e.g., a large `synchronized` test setup, or copy-pasted test data builders for clarity, are often fine even if they'd be flagged in production code).
- The issue is purely stylistic and would be caught by an automated formatter/linter if one were configured — don't manually restate what tooling should handle.
- A generic pattern (e.g., Strategy) is deliberately not used for something with only two stable, unlikely-to-grow cases — introducing the abstraction would be overengineering, not an improvement.

---

## Repository Convention Rules

- Prefer the existing repository convention over a personal or generic best-practice preference when the two conflict and the existing convention is applied consistently.
- Do not suggest an architectural redesign unless the PR's own change is unsafe or unworkable without it — architecture feedback belongs in a design discussion, not sprung on a single PR.
- Do not introduce abstraction (interfaces, strategy patterns, generic base classes) beyond what the current requirement justifies.
- Do not recommend patterns purely because they're "more enterprise" or "more standard" if the simpler existing approach already works and is understood by the team.
- Preserve backward compatibility for public APIs, published events, and shared library contracts unless the PR explicitly is a breaking-change/version-bump PR.
- Respect the existing dependency direction between modules/layers; don't approve or suggest a dependency that flows backward even if it's a one-line convenience.

---

## AI Reviewer Checklist

### Correctness & Architecture
```
□ Change does what the PR description claims
□ Edge cases (null, empty, boundary values) are handled
□ SOLID principles respected where they matter (not dogmatically)
□ Layer responsibilities respected (controller/service/repository)
□ No business logic in controllers
□ No persistence/SQL logic outside repositories/mappers
□ Dependency direction points inward (controller → service → persistence)
□ No circular dependencies between beans/modules
□ Composition preferred over inheritance for code reuse
□ Domain objects protect their own invariants
□ Immutable value objects/DTOs used where mutability isn't required
□ No unnecessary architectural abstraction introduced (YAGNI respected)
```

### Spring Boot
```
□ Constructor injection used, not field injection
□ @Transactional applied at the correct boundary (service, public method, external call)
□ Read-only transactions marked as such where applicable
□ No self-invocation bypassing @Transactional/AOP proxies
□ Transactions don't wrap slow non-transactional work (HTTP, email)
□ Validation uses Bean Validation for structural checks
□ Business validation lives in the service layer
□ Exceptions handled centrally via @RestControllerAdvice
□ Exceptions are specific and meaningful, not generic RuntimeException
□ DTOs used at API boundary, entities/mapper results never exposed directly
□ Jackson null/date handling explicit and consistent
□ @ConfigurationProperties used for grouped config, not scattered @Value
□ @Scheduled jobs are idempotent and safe for multi-instance deployment
□ @Cacheable/@CacheEvict pairs are correct and complete
□ Cache keys are unambiguous
□ AOP pointcuts are narrowly scoped
□ Filters/interceptors used for cross-cutting HTTP concerns, not duplicated per controller
```

### MyBatis & Database
```
□ No ${} used with user-supplied input (SQL injection check)
□ All parameters use #{} bindings
□ No N+1 query patterns (list + per-row mapper call)
□ Batch operations used for bulk inserts/updates, not row-by-row loops
□ Dynamic SQL uses <where>/<trim>, no dangling AND/WHERE
□ Every dynamic SQL branch has test coverage
□ Result maps explicit for non-trivial/nested mappings
□ Reusable SQL fragments use <sql>/<include>, not copy-paste
□ Pagination done in SQL (LIMIT/OFFSET or keyset), not in application memory
□ New/changed queries have supporting indexes
□ Foreign keys and constraints declared at the DB level
□ Multi-statement writes wrapped in a single transaction
□ Optimistic/pessimistic locking used where concurrent writes matter
□ No SELECT * in production code paths
□ Connection pool usage is bounded and reused, not created per call
```

### REST API
```
□ Endpoints are resource-oriented and use correct HTTP verbs
□ Status codes match actual outcome semantics
□ List endpoints are paginated
□ Sort/filter params validated against a whitelist, not passed raw into SQL
□ Idempotency considered for retryable POST operations
□ Error response shape is consistent with the rest of the API
□ Breaking changes are versioned per repo convention
□ Request and response DTOs are not blindly reused for both directions
```

### Concurrency & Performance
```
□ Shared mutable state in singleton beans is thread-safe or eliminated
□ No blocking I/O inside non-blocking/async execution contexts
□ Locks are not held across blocking calls
□ Check-then-act sequences on shared state are protected (lock/constraint/atomic)
□ Async/executor handoffs propagate MDC/trace context
□ Resources (connections, streams, locks) are released via try-with-resources
□ No DB call inside a loop
□ No obviously quadratic-or-worse logic over unbounded collections
□ Expensive objects (formatters, mappers, clients) are reused, not reallocated per call
□ Repeated computations within a request are cached/reused, not recomputed
```

### Security
```
□ New/changed endpoints have explicit authentication requirements
□ Object-level authorization checked (no IDOR)
□ All external input validated at the boundary
□ No secrets/credentials hardcoded in code or config
□ Sensitive data not written to logs
□ Sensitive data encrypted at rest / transmitted over TLS
□ Tokens validated for signature and expiry, not just presence
□ CSRF protection present where session/cookie auth is used
```

### Logging & Error Handling
```
□ Log levels used correctly (ERROR reserved for real failures)
□ Trace/correlation IDs propagate across async and service boundaries
□ No sensitive information in log statements
□ ERROR logs contain enough context to act on without reproducing locally
□ No leftover debug prints or log statements inside tight loops
□ Retries are limited to idempotent, transient-failure scenarios with backoff
□ Fallback/degraded behavior is intentional and documented, not an accidental empty catch
```

### Testing
```
□ New business logic has unit test coverage
□ Mapper/SQL changes have integration test coverage
□ Tests assert specific, meaningful outcomes, not just "no exception"
□ Edge cases and negative scenarios are tested, not just the happy path
□ Test names describe scenario and expectation
□ Mocks verify behavior, not implementation detail
```

### Maintainability & Documentation
```
□ No significant duplicated logic left unextracted
□ Magic numbers/strings replaced with named constants where they carry business meaning
□ New code follows existing package/module organization
□ Known shortcuts/technical debt are flagged with a comment or ticket, not silent
□ README/architecture docs updated if structure or setup changed
□ API documentation updated if request/response contracts changed
□ AGENTS.md or equivalent updated if conventions/commands changed
□ Migration guide updated for breaking schema/API changes
```

---

*This document defines review standards, not review process. Extend it by adding new bullet points under the relevant section and, if a new category of concern doesn't fit any existing section, add a new top-level section following the existing format (Explanation → Detection → Good/Bad examples → Common mistakes, where applicable).*
