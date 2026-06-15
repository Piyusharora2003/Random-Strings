# Spring Boot 3 / Java 17 — SLF4J `@Slf4j` Logging Improvement Skill

> **Skill trigger:** Use this whenever improving, auditing, restructuring, or adding logs to a
> Spring Boot 3 service using the `@Slf4j` annotation. Applies to requests like "make logs more
> informative", "reduce log noise", "add structured logging", "set up MDC / correlation IDs",
> or any mention of log levels, `@Slf4j`, SLF4J, Logback, JSON logs, ELK, Splunk, or Loki.

---

## Core Philosophy

> **Informative, not verbose.**
> Every log line must answer: *Who did what, with what result, in how long, under which context?*
> If a line cannot answer at least two of those questions, reconsider it.

### The Three Rules
1. **Right level** — wrong levels are the #1 cause of alert fatigue and missed bugs.
2. **Right context** — a message without a correlation ID or request path is half a message.
3. **Right cost** — logging inside hot loops or serialising large objects is a performance hazard.

---

## Step 1 — Audit Existing Logs First

Before writing a single line, classify what already exists:

```
OVER-LOGGED (remove or downgrade)           UNDER-LOGGED (add)
─────────────────────────────────────────   ───────────────────────────────────
INFO  "Entering method X"                   WARN  recoverable errors / retries
INFO  "Leaving method X"                    ERROR root-cause exception + context
DEBUG loop body on every iteration          INFO  key business events with IDs
INFO  object.toString() dumps               DEBUG decision branches, feature flags
TRACE payloads in production                INFO  external call latency (durationMs)
```

---

## Step 2 — Log Level Guide

| Level   | When to use                                            | Never use for                           |
|---------|--------------------------------------------------------|-----------------------------------------|
| `ERROR` | Unrecoverable failure, needs human action              | Expected errors (e.g. 404, validation)  |
| `WARN`  | Recoverable issue, degraded behaviour, retry occurred  | Normal happy-path noise                 |
| `INFO`  | Key lifecycle event (startup, shutdown, job complete)  | Per-request chatter in high throughput  |
| `DEBUG` | Dev/staging diagnostics (branches, payloads)           | Production default level                |
| `TRACE` | Fine-grained internals (SQL params, serialisation)     | Production — ever                       |

**Default production profile:** `INFO` for your packages, `WARN` for all framework packages.

---

## Step 3 — Logger Declaration with `@Slf4j`

`@Slf4j` is a Lombok compile-time annotation. It generates a `private static final Logger log`
field on the class automatically — no boilerplate, no typo risk, no import of `LoggerFactory`.

### Maven dependency

```xml
<dependency>
    <groupId>org.projectlombok</groupId>
    <artifactId>lombok</artifactId>
    <optional>true</optional>  <!-- compile-only; not bundled in the JAR -->
</dependency>
```

### Standard usage — annotate every class that logs

```java
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

@Slf4j                          // generates: private static final Logger log = ...
@Service
public class OrderService {

    public void createOrder(OrderRequest req) {
        log.info("Creating order customerId={}", req.getCustomerId());
    }
}
```

Lombok generates exactly this under the hood (you never write it):
```java
private static final org.slf4j.Logger log =
    org.slf4j.LoggerFactory.getLogger(OrderService.class);
```

### The one exception — named loggers (e.g. AUDIT)

`@Slf4j` always names the logger after the class. When you need a **custom-named** logger
(like `"AUDIT"` to route to a dedicated appender), you must declare it manually alongside
`@Slf4j`:

```java
import lombok.extern.slf4j.Slf4j;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

@Slf4j
@Component
public class AuditLogger {

    // Named logger routes to its own Logback appender — cannot use @Slf4j for this
    private static final Logger AUDIT = LoggerFactory.getLogger("AUDIT");

    public void orderCreated(String orderId, String customerId, BigDecimal total) {
        AUDIT.info("event=ORDER_CREATED orderId={} customerId={} totalGbp={}",
                   orderId, customerId, total);
    }

    public void paymentFailed(String orderId, String reason) {
        AUDIT.warn("event=PAYMENT_FAILED orderId={} reason={}", orderId, reason);
    }

    public void userDeleted(String hashedUserId, String deletedBy) {
        AUDIT.info("event=USER_DELETED hashedUserId={} deletedBy={}", hashedUserId, deletedBy);
    }
}
```

> **Rule:** `@Slf4j` everywhere. Manual `LoggerFactory.getLogger("NAME")` only for
> dedicated named loggers like `AUDIT`. Never mix both styles in the same class unless
> the second logger is intentionally named differently.

---

## Step 4 — Message Format Rules

### Use `{}` placeholders — never string concatenation

```java
// ✅ Lazy evaluation — string is never built if the level is disabled
log.debug("Order {} transitioned from {} to {}", orderId, prevStatus, newStatus);

// ❌ String is always built even when DEBUG is off — wastes CPU and memory
log.debug("Order " + orderId + " transitioned from " + prevStatus + " to " + newStatus);
```

### Message anatomy

```
[verb] [subject] [qualifier] — [key=value pairs]
```

```java
log.info("Created order orderId={} customerId={} totalGbp={}", id, custId, total);
log.warn("Payment retry attempt={} orderId={} reason={}", attempt, orderId, reason);
log.error("Failed to charge card orderId={} cardLast4={}", orderId, last4, ex);
```

### Always use `key=value` inline tokens

`key=value` tokens let log aggregators (ELK, Splunk, Loki) index fields without regex:

```java
log.info("Invoice generated invoiceId={} orderId={} durationMs={}",
         invoiceId, orderId, elapsed);
```

### Exception logging — exception object goes LAST

SLF4J detects a `Throwable` as the final argument and appends the full stack trace automatically.

```java
// ✅ Full stack trace attached
log.error("Failed to process payment orderId={}", orderId, ex);

// ❌ Stack trace swallowed — only the message string is logged
log.error("Failed to process payment: " + ex.getMessage());
```

---

## Step 5 — MDC (Mapped Diagnostic Context)

MDC automatically appends key-value pairs to **every** log line within a request thread —
without touching individual log call sites. Set it once in a servlet filter, clear it in `finally`.

```java
import jakarta.servlet.Filter;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.ServletRequest;
import jakarta.servlet.ServletResponse;
import jakarta.servlet.http.HttpServletRequest;
import org.slf4j.MDC;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;

import java.io.IOException;
import java.util.UUID;

@Component
@Order(1)   // run before other filters so MDC is available everywhere
public class MdcRequestFilter implements Filter {

    private static final String TRACE_ID    = "traceId";
    private static final String REQUEST_ID  = "requestId";
    private static final String USER_ID     = "userId";
    private static final String HTTP_METHOD = "httpMethod";
    private static final String REQUEST_URI = "requestUri";

    @Override
    public void doFilter(ServletRequest req, ServletResponse res, FilterChain chain)
            throws IOException, ServletException {

        HttpServletRequest http = (HttpServletRequest) req;
        try {
            // Honour upstream trace header (API Gateway, AWS ALB, Istio, etc.)
            String traceId = http.getHeader("X-Trace-Id");
            if (traceId == null || traceId.isBlank()) {
                traceId = UUID.randomUUID().toString();
            }

            MDC.put(TRACE_ID,    traceId);
            MDC.put(REQUEST_ID,  UUID.randomUUID().toString());
            MDC.put(HTTP_METHOD, http.getMethod());
            MDC.put(REQUEST_URI, http.getRequestURI());

            // userId is available only after Spring Security authenticates the request
            Authentication auth = SecurityContextHolder.getContext().getAuthentication();
            if (auth != null && auth.isAuthenticated() && !"anonymousUser".equals(auth.getName())) {
                MDC.put(USER_ID, auth.getName());
            }

            chain.doFilter(req, res);

        } finally {
            MDC.clear(); // CRITICAL — thread pools reuse threads; stale MDC leaks across requests
        }
    }
}
```

With this filter active, every log line in a request automatically carries:
```
traceId=b3d7e91f requestId=a1b2c3d4 httpMethod=POST requestUri=/api/v1/orders userId=alice
```

---

## Step 6 — Logback Configuration (`logback-spring.xml`)

Place in `src/main/resources/logback-spring.xml`. Spring Boot auto-discovers it and
activates `<springProfile>` blocks per active profile.

### Maven dependency for JSON output (production)

```xml
<dependency>
    <groupId>net.logstash.logback</groupId>
    <artifactId>logstash-logback-encoder</artifactId>
    <version>7.4</version>
</dependency>
```

### `application.yml` — profile-level defaults

```yaml
# application.yml  (shared baseline)
logging:
  level:
    root: WARN
    com.yourcompany: INFO

---
# application-dev.yml
logging:
  level:
    com.yourcompany: DEBUG
    org.springframework.web: DEBUG

---
# application-prod.yml
logging:
  level:
    root: WARN
    com.yourcompany: INFO
    # JSON format is handled by logback-spring.xml prod profile below
```

### Full `logback-spring.xml`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<configuration scan="true" scanPeriod="30 seconds">

  <!-- Read app name from Spring config -->
  <springProperty scope="context" name="appName"
                  source="spring.application.name"
                  defaultValue="app"/>

  <property name="LOG_DIR"     value="${LOG_DIR:-logs}"/>
  <property name="MAX_SIZE"    value="50MB"/>
  <property name="MAX_HISTORY" value="30"/>
  <property name="TOTAL_CAP"   value="1GB"/>

  <!-- ============================================================
       DEV PROFILE — coloured, human-readable console
       ============================================================ -->
  <springProfile name="dev,default">

    <appender name="CONSOLE" class="ch.qos.logback.core.ConsoleAppender">
      <encoder>
        <pattern>
          %clr(%d{HH:mm:ss.SSS}){faint}
          %clr(%-5level){highlight}
          %clr([%15.15t]){faint}
          %clr(%-40.40logger{39}){cyan} :
          %m
          %clr([traceId=%X{traceId} userId=%X{userId}]){faint}
          %n%wEx
        </pattern>
      </encoder>
    </appender>

    <root level="INFO">
      <appender-ref ref="CONSOLE"/>
    </root>

    <logger name="com.yourcompany" level="DEBUG" additivity="false">
      <appender-ref ref="CONSOLE"/>
    </logger>

    <!-- Suppress noisy framework output in dev -->
    <logger name="org.springframework"  level="WARN"/>
    <logger name="org.hibernate"        level="WARN"/>
    <logger name="com.zaxxer.hikari"    level="WARN"/>

  </springProfile>

  <!-- ============================================================
       PRODUCTION / STAGING — structured JSON, rolling file
       ============================================================ -->
  <springProfile name="prod,staging">

    <appender name="ROLLING_JSON" class="ch.qos.logback.core.rolling.RollingFileAppender">
      <file>${LOG_DIR}/${appName}.log</file>

      <rollingPolicy class="ch.qos.logback.core.rolling.SizeAndTimeBasedRollingPolicy">
        <fileNamePattern>${LOG_DIR}/${appName}.%d{yyyy-MM-dd}.%i.log.gz</fileNamePattern>
        <maxFileSize>${MAX_SIZE}</maxFileSize>
        <maxHistory>${MAX_HISTORY}</maxHistory>
        <totalSizeCap>${TOTAL_CAP}</totalSizeCap>
        <cleanHistoryOnStart>true</cleanHistoryOnStart>
      </rollingPolicy>

      <!-- Every MDC key becomes a top-level JSON field — no regex needed in ELK -->
      <encoder class="net.logstash.logback.encoder.LogstashEncoder">
        <includeMdcKeyName>traceId</includeMdcKeyName>
        <includeMdcKeyName>requestId</includeMdcKeyName>
        <includeMdcKeyName>userId</includeMdcKeyName>
        <includeMdcKeyName>httpMethod</includeMdcKeyName>
        <includeMdcKeyName>requestUri</includeMdcKeyName>
        <customFields>{"service":"${appName}","env":"prod"}</customFields>
        <shortenedLoggerNameLength>36</shortenedLoggerNameLength>
        <throwableConverter class="net.logstash.logback.stacktrace.ShortenedThrowableConverter">
          <maxDepthPerCause>10</maxDepthPerCause>
          <shortenedClassNameLength>35</shortenedClassNameLength>
          <rootCauseFirst>true</rootCauseFirst>
        </throwableConverter>
      </encoder>
    </appender>

    <!-- Async wrapper — I/O never blocks request threads -->
    <appender name="ASYNC_JSON" class="ch.qos.logback.classic.AsyncAppender">
      <appender-ref ref="ROLLING_JSON"/>
      <queueSize>2048</queueSize>
      <discardingThreshold>20</discardingThreshold>  <!-- drops DEBUG under back-pressure -->
      <neverBlock>true</neverBlock>
      <includeCallerData>false</includeCallerData>   <!-- saves CPU -->
    </appender>

    <!-- Separate AUDIT appender — never discarded, 90-day retention -->
    <appender name="AUDIT_FILE" class="ch.qos.logback.core.rolling.RollingFileAppender">
      <file>${LOG_DIR}/${appName}-audit.log</file>
      <rollingPolicy class="ch.qos.logback.core.rolling.SizeAndTimeBasedRollingPolicy">
        <fileNamePattern>${LOG_DIR}/${appName}-audit.%d{yyyy-MM-dd}.%i.log.gz</fileNamePattern>
        <maxFileSize>100MB</maxFileSize>
        <maxHistory>90</maxHistory>
      </rollingPolicy>
      <encoder class="net.logstash.logback.encoder.LogstashEncoder">
        <customFields>{"service":"${appName}","log_type":"audit"}</customFields>
      </encoder>
    </appender>

    <!-- AUDIT logger — routes to its own file, does NOT bubble up to root -->
    <logger name="AUDIT" level="INFO" additivity="false">
      <appender-ref ref="AUDIT_FILE"/>
    </logger>

    <root level="WARN">
      <appender-ref ref="ASYNC_JSON"/>
    </root>

    <logger name="com.yourcompany" level="INFO" additivity="false">
      <appender-ref ref="ASYNC_JSON"/>
    </logger>

    <logger name="org.springframework"  level="WARN"/>
    <logger name="org.hibernate.SQL"    level="WARN"/>
    <logger name="com.zaxxer.hikari"    level="WARN"/>

  </springProfile>

</configuration>
```

### JSON line produced in production

```json
{
  "@timestamp":  "2024-11-18T14:22:03.841Z",
  "level":       "INFO",
  "logger_name": "com.yourcompany.order.OrderService",
  "message":     "Created order orderId=ORD-99123 customerId=CUST-4411 totalGbp=149.99",
  "traceId":     "b3d7e91f-2a4c-4d88-b6e7-f4a2c3d1e0b5",
  "requestId":   "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "userId":      "alice@example.com",
  "httpMethod":  "POST",
  "requestUri":  "/api/v1/orders",
  "service":     "order-service",
  "env":         "prod"
}
```

---

## Step 7 — Performance Guard Rails

### Guard expensive DEBUG/TRACE arguments

```java
// ✅ toDetailedString() is only called when DEBUG is actually enabled
if (log.isDebugEnabled()) {
    log.debug("Full cart contents userId={} cart={}", userId, cart.toDetailedString());
}
```

### Never log inside tight loops — log summaries instead

```java
// ❌ 10 000 log lines for a bulk import — kills throughput and fills disks
for (Record r : records) {
    log.info("Processing record id={}", r.getId());
    process(r);
}

// ✅ One INFO at start, one INFO at end, WARN per failure only
log.info("Bulk import started count={}", records.size());
int errors = 0;
for (Record r : records) {
    try {
        process(r);
    } catch (Exception ex) {
        errors++;
        log.warn("Skipped record id={} reason={}", r.getId(), ex.getMessage());
    }
}
log.info("Bulk import complete total={} errors={} durationMs={}",
         records.size(), errors, elapsed);
```

### Mask sensitive data before logging

```java
// ❌ PCI-DSS / GDPR breach
log.info("Processing card number={} cvv={}", cardNumber, cvv);

// ✅ Only the last 4 digits
log.info("Processing card last4={}", maskCard(cardNumber));

private String maskCard(String pan) {
    if (pan == null || pan.length() < 4) return "****";
    return "*".repeat(pan.length() - 4) + pan.substring(pan.length() - 4);
}
```

---

## Step 8 — Audit Trail Pattern

Domain events that must be retained long-term (orders placed, payments succeeded, accounts
deleted) belong in a dedicated `AuditLogger` component — not scattered as `log.info` calls
across service classes. See the **named logger exception** in Step 3 for the full class.

The `AUDIT` named logger cannot use `@Slf4j` (which always names the logger after the class).
It uses a manual `LoggerFactory.getLogger("AUDIT")` declaration so Logback can route it to its
own `AUDIT_FILE` appender with 90-day retention (defined in `logback-spring.xml`).

Inject and call it alongside the normal `@Slf4j` operational log:

```java
@Slf4j
@Service
@RequiredArgsConstructor
public class OrderService {

    private final AuditLogger auditLogger;

    public Order create(OrderRequest req) {
        Order order = orderRepository.save(toEntity(req));
        log.info("Order persisted orderId={} durationMs={}", order.getId(), elapsed);  // operational
        auditLogger.orderCreated(order.getId(), req.getCustomerId(), req.getTotal());   // audit
        return order;
    }
}
```

---

## Step 9 — Common Patterns by Scenario

### REST Controller

```java
import lombok.extern.slf4j.Slf4j;

@Slf4j
@RestController
@RequestMapping("/api/v1/orders")
public class OrderController {

    @PostMapping
    public ResponseEntity<OrderResponse> create(@RequestBody @Valid OrderRequest req) {
        log.info("Received create-order request customerId={} itemCount={}",
                 req.getCustomerId(), req.getItems().size());

        OrderResponse resp = orderService.create(req);

        log.info("Order created successfully orderId={} customerId={}",
                 resp.getOrderId(), req.getCustomerId());
        return ResponseEntity.status(HttpStatus.CREATED).body(resp);
    }
}
```

### Service layer with timing

```java
import lombok.extern.slf4j.Slf4j;

@Slf4j
@Service
public class OrderService {

    public OrderResponse create(OrderRequest req) {
        long start = System.currentTimeMillis();
        log.debug("Creating order customerId={} items={}", req.getCustomerId(), req.getItems());

        Order saved = orderRepository.save(toEntity(req));

        log.info("Order persisted orderId={} durationMs={}",
                 saved.getId(), System.currentTimeMillis() - start);
        return mapper.toResponse(saved);
    }
}
```

### External HTTP client (RestClient)

```java
import lombok.extern.slf4j.Slf4j;

@Slf4j
@Component
public class PaymentClient {

    public PaymentResult charge(ChargeRequest req) {
        long start = System.currentTimeMillis();
        log.debug("Calling payment gateway orderId={} amountGbp={}", req.getOrderId(), req.getAmount());
        try {
            PaymentResult result = restClient.post()
                    .uri("/charge").body(req).retrieve().body(PaymentResult.class);
            log.info("Payment successful orderId={} transactionId={} durationMs={}",
                     req.getOrderId(), result.getTransactionId(), System.currentTimeMillis() - start);
            return result;
        } catch (HttpClientErrorException ex) {
            log.warn("Payment rejected orderId={} status={} reason={}",
                     req.getOrderId(), ex.getStatusCode(), ex.getMessage());
            throw new PaymentRejectedException(req.getOrderId(), ex.getMessage());
        } catch (Exception ex) {
            log.error("Payment gateway error orderId={}", req.getOrderId(), ex);
            throw new PaymentGatewayException(req.getOrderId(), ex);
        }
    }
}
```

### Scheduled job / batch

```java
import lombok.extern.slf4j.Slf4j;

@Slf4j
@Component
public class InvoiceGenerationJob {

    @Scheduled(cron = "0 0 2 * * *")
    public void generateDailyInvoices() {
        long start = System.currentTimeMillis();
        log.info("Job started job=generateDailyInvoices");

        List<Order> pending = orderRepo.findUnbilledOrders();
        log.info("Found unbilled orders count={}", pending.size());

        int processed = 0, failed = 0;
        for (Order order : pending) {
            try {
                invoiceService.generate(order);
                processed++;
            } catch (Exception ex) {
                failed++;
                log.error("Failed to generate invoice orderId={}", order.getId(), ex);
            }
        }
        log.info("Job completed job=generateDailyInvoices processed={} failed={} durationMs={}",
                 processed, failed, System.currentTimeMillis() - start);
    }
}
```

### Global exception handler

```java
import lombok.extern.slf4j.Slf4j;

@Slf4j
@RestControllerAdvice
public class GlobalExceptionHandler {

    // 4xx — expected, client error: WARN
    @ExceptionHandler(OrderNotFoundException.class)
    public ResponseEntity<ErrorResponse> handleNotFound(OrderNotFoundException ex) {
        log.warn("Order not found orderId={}", ex.getOrderId());
        return ResponseEntity.status(404).body(new ErrorResponse("Order not found"));
    }

    // Validation — very common, low signal: DEBUG
    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ErrorResponse> handleValidation(MethodArgumentNotValidException ex) {
        log.debug("Validation failed fields={}", ex.getBindingResult().getFieldErrors());
        return ResponseEntity.status(400).body(new ErrorResponse("Validation error"));
    }

    // 5xx — unexpected, our bug: ERROR with full stack trace
    @ExceptionHandler(Exception.class)
    public ResponseEntity<ErrorResponse> handleUnexpected(Exception ex) {
        log.error("Unexpected server error", ex);
        return ResponseEntity.status(500).body(new ErrorResponse("Internal server error"));
    }
}
```

### Retry / circuit breaker recovery

```java
import lombok.extern.slf4j.Slf4j;

@Slf4j
@Component
public class InventoryClient {

    @Retryable(maxAttempts = 3, backoff = @Backoff(delay = 500, multiplier = 2))
    public InventoryStatus check(String sku) {
        log.debug("Checking inventory sku={}", sku);
        return inventoryApi.status(sku);
    }

    @Recover
    public InventoryStatus recoverInventoryCheck(Exception ex, String sku) {
        log.warn("Inventory check failed after all retries sku={} reason={}", sku, ex.getMessage());
        return InventoryStatus.UNKNOWN;
    }
}
```

---

## Step 10 — HTTP Request/Response Logging

Use Spring's built-in filter — never log raw bodies at `INFO` (PII + size risk):

```java
@Bean
public CommonsRequestLoggingFilter requestLoggingFilter() {
    CommonsRequestLoggingFilter filter = new CommonsRequestLoggingFilter();
    filter.setIncludeQueryString(true);
    filter.setIncludeHeaders(false);     // exclude Authorization, Cookie
    filter.setIncludePayload(false);     // no body at INFO
    filter.setMaxPayloadLength(500);
    return filter;
}
```

Enable per environment in `application-dev.yml`:

```yaml
logging:
  level:
    org.springframework.web.filter.CommonsRequestLoggingFilter: DEBUG
```

---

## Step 11 — Sensitive Data Reference

### Fields that must never appear unmasked in logs

| Category    | Examples                              | Risk                  |
|-------------|---------------------------------------|-----------------------|
| Auth        | Passwords, tokens, API keys, JWTs     | Account takeover      |
| Payment     | Full card numbers, CVV, sort codes    | PCI-DSS breach        |
| Personal    | Full name + address, DOB, NI/SSN      | GDPR / CCPA fine      |
| Session     | Session cookies, CSRF tokens          | Session hijacking     |

### Masking helpers

```java
// Card number — keep last 4
public static String maskCard(String pan) {
    if (pan == null || pan.length() < 4) return "****";
    return "*".repeat(pan.length() - 4) + pan.substring(pan.length() - 4);
}

// Email — keep first char, domain
public static String maskEmail(String email) {
    if (email == null || !email.contains("@")) return "***@***";
    int at = email.indexOf('@');
    String local = email.substring(0, at);
    String domain = email.substring(at);
    if (local.length() <= 2) return "**" + domain;
    return local.charAt(0) + "*".repeat(local.length() - 2)
           + local.charAt(local.length() - 1) + domain;
}

// Truncate large strings (request bodies, payloads)
public static String truncate(String value, int maxLength) {
    if (value == null) return null;
    return value.length() <= maxLength
           ? value
           : value.substring(0, maxLength) + "…[truncated]";
}
```

---

## Step 12 — Pre-Commit Checklist

- [ ] No `System.out.println`, `e.printStackTrace()`, or `java.util.logging` anywhere
- [ ] Every class that logs carries `@Slf4j` — no manual `LoggerFactory.getLogger(...)` except for named loggers (e.g. `AUDIT`)
- [ ] All log arguments use `{}` placeholders — zero string concatenation
- [ ] Every `log.error(...)` call passes the exception object as the last argument
- [ ] MDC filter present; `MDC.clear()` called in `finally` block
- [ ] All log messages include at least one `key=value` context token
- [ ] No PII (emails, card numbers, passwords) in plain text
- [ ] `isDebugEnabled()` guard wraps any call where building the argument is expensive
- [ ] No per-iteration logging inside loops — only start/end summaries + per-error WARN
- [ ] Production profile: `WARN` for framework packages, `INFO` for app packages
- [ ] `logback-spring.xml` uses JSON encoder + async appender for `prod`/`staging` profiles
- [ ] Audit events routed through `AuditLogger` (named logger) to its own dedicated appender

---

## Logback Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| Logs stop under load | Async queue full | Increase `queueSize` or check sink throughput |
| Duplicate log lines | `additivity="true"` on child logger | Set `additivity="false"` on that logger |
| MDC fields missing in output | `MDC.clear()` fires before response is committed | Move `clear()` into the `finally` block after `chain.doFilter` |
| JSON not produced | Wrong encoder class | Use `LogstashEncoder`, not `PatternLayoutEncoder` |
| Old files not deleted | `cleanHistoryOnStart` absent | Add `<cleanHistoryOnStart>true</cleanHistoryOnStart>` |
| Stack trace missing | Exception not passed as last arg | `log.error("msg context={}", ctx, ex)` — ex is always last |
