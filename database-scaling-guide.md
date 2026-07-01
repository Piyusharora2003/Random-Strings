# Database Scaling for Engineers: Sharding, Partitioning, and Read Replicas

*A mentoring guide for engineers new to distributed data systems. Assumes basic SQL knowledge, no prior distributed-systems background.*

---

## Table of Contents
1. [Sharding](#1-sharding)
2. [Partitioning](#2-partitioning)
3. [Read Replicas](#3-read-replicas)
4. [Comparison Table](#4-comparison-table)
5. [How They Work Together](#5-how-they-work-together)
6. [Real-World Examples](#6-real-world-examples)
7. [Common Interview Questions](#7-common-interview-questions)
8. [Interesting Related Concepts](#8-interesting-related-concepts)
9. [Key Takeaways](#9-key-takeaways)

---

# 1. Sharding

## 1.1 What is it?

**Analogy:** Imagine a single librarian trying to manage every book in a country's library system from one desk. Eventually the line of people is too long and the desk runs out of shelf space. The solution: build separate library branches around the country, and send each patron to the branch that holds *their* books (say, based on the first letter of their last name). Each branch is independent, has its own shelves, its own librarian, and only ever deals with a slice of the whole collection.

**Technical definition:** Sharding is a horizontal scaling technique where a single logical database is split into multiple independent physical databases (**shards**), each holding a disjoint subset of the data (usually determined by a **shard key**, e.g. `user_id`). Each shard is a fully independent MySQL instance — its own CPU, memory, disk, and connections. The application is responsible for figuring out which shard a piece of data lives on.

This is different from partitioning (Section 2) — partitioning splits a table *within a single database server*, while sharding splits data *across separate database servers*.

## 1.2 Why is it used?

**Problems it solves:**
- A single MySQL instance has a ceiling on write throughput, storage capacity, and connection count. Sharding removes this ceiling by spreading data (and therefore load) across many machines.
- Vertical scaling (bigger CPU/RAM/disk on one box) has diminishing returns and a hard limit — eventually you can't buy a bigger machine. Sharding scales horizontally, in principle indefinitely.

**Benefits:**
- Near-linear increase in write capacity by adding shards.
- Smaller per-shard data sets → faster index scans, smaller backups, faster recovery.
- Blast-radius containment: an outage on one shard doesn't take down 100% of users.

**Trade-offs:**
- Massive increase in operational complexity (deployment, monitoring, backups × N).
- Cross-shard joins and transactions become hard or impossible at the database level.
- Rebalancing data when adding/removing shards is a genuinely difficult engineering problem.
- Application code must be shard-aware.

## 1.3 When should you use it?

Use sharding when:
- A single database server can no longer handle write throughput, even after adding read replicas and optimizing queries/indexes.
- Data volume exceeds what a single server can store or back up in a reasonable window (multi-terabyte tables).
- You have a natural, high-cardinality shard key (e.g., `user_id`, `tenant_id`) and most queries filter by it.

Real-world triggers: Instagram sharded Postgres by user ID once a single primary could no longer keep up with photo/comment write volume. Multi-tenant SaaS platforms often shard by `tenant_id` so each customer's data — and load — is isolated.

**Do not reach for sharding first.** It's usually the last resort after read replicas, caching, query optimization, and vertical scaling have been exhausted, because of the complexity cost described below.

## 1.4 How does it work?

### Step-by-step mechanism

1. **Choose a shard key** — a column present on (almost) every write, with high cardinality and even distribution (e.g., `user_id`).
2. **Choose a sharding strategy:**
   - **Hash-based:** `shard_id = hash(user_id) % num_shards`. Even distribution, but resharding is expensive because the modulus changes.
   - **Range-based:** `user_id 1–1,000,000 → shard 1`, `1,000,001–2,000,000 → shard 2`. Easy to reason about and to add shards, but can create "hot" shards if traffic isn't uniform across ranges.
   - **Directory-based (lookup table):** A mapping service/table records `user_id → shard_id` explicitly. Most flexible (arbitrary rebalancing) but adds a lookup hop and a new single point of failure to protect.
   - **Tenant ID / Region-based:** For B2B SaaS, shard by `tenant_id` (whole customer lives on one shard) or by geography (EU data stays in EU shards, for compliance).
3. **Route each request** to the correct shard using a **shard router** — either a library inside the application (common with Spring Boot) or a separate proxy layer (e.g., Vitess for MySQL, ProxySQL).
4. **Execute the query** against the resolved shard's connection pool.

### ASCII diagram

```
                     ┌────────────────────┐
                     │   Spring Boot App   │
                     │   Shard Router      │
                     │ shard = hash(userId)│
                     │        % N          │
                     └─────────┬───────────┘
             ┌──────────────────┼──────────────────┐
             ▼                  ▼                  ▼
      ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
      │   Shard 0    │    │   Shard 1    │    │   Shard 2    │
      │ MySQL 8      │    │ MySQL 8      │    │ MySQL 8      │
      │ users 0-333k │    │ users334-666k│    │ users667k-1M │
      └─────────────┘    └─────────────┘    └─────────────┘
```

### Transactions across shards

MySQL does not support ACID transactions across two independent server instances out of the box. Options:
- **Avoid it** — design so a single business transaction touches only one shard (this is the #1 goal of picking a good shard key).
- **Saga pattern** — break the operation into a sequence of local transactions with compensating actions if a later step fails. Eventually consistent, not atomic.
- **Two-phase commit (2PC) / XA transactions** — technically possible in MySQL via the `XA` protocol, but rarely used in practice: it's slow, and a coordinator crash can leave shards in-doubt indefinitely.

### Cross-shard joins

There is no native cross-shard `JOIN`. Common approaches:
- **Scatter-gather:** query every shard in parallel, then join/merge in the application layer. Works for small result sets; expensive at scale.
- **Denormalization:** duplicate the data you'd otherwise join, onto the same shard as the entity being queried, so no join is needed.
- **Reference/lookup tables replicated to every shard:** for small, rarely-changing tables (e.g., "country codes"), just keep a full copy on every shard.

### Adding a new shard

This is the hardest operational task in a sharded system.
- With **hash-based** sharding, adding a shard changes the modulus, which reshuffles almost all keys → requires a live data migration (often done with **consistent hashing**, see Section 8, to minimize the amount of data that has to move).
- With **range-based** or **directory-based** sharding, you can simply carve out a new range or move specific keys, without touching everyone else's data.
- Typically done as: dual-write to old + new location → backfill historical data → verify consistency → cut over reads → stop writing to the old location.

## 1.5 When should you NOT use it?

- Your data and load fit comfortably on one well-tuned server (most applications, even fairly large ones, never need this).
- You haven't yet tried read replicas, caching (Redis/Memcached), query/index optimization, or vertical scaling.
- Your queries frequently need to join or aggregate across what would become shard boundaries — sharding will force expensive denormalization or scatter-gather.
- Your team is small; the ongoing operational burden (migrations, monitoring, rebalancing, backups per shard) can outweigh the benefit.
- You need strong, cross-entity ACID transactions as a core product requirement.

**Common pitfall:** picking a shard key that isn't on most queries (e.g., sharding by `user_id` but most queries filter by `product_id`) turns every read into an expensive scatter-gather across all shards — the worst of both worlds.

## 1.6 How is it implemented in production code (Spring Boot 3 + Java 21 + JPA/Hibernate + MySQL 8)

### Project structure

```
src/main/java/com/example/sharding
 ├── config/
 │    ├── ShardDataSourceConfig.java
 │    ├── ShardRoutingDataSource.java
 │    └── ShardContext.java
 ├── aspect/
 │    └── ShardResolverAspect.java
 ├── controller/
 │    └── OrderController.java
 ├── service/
 │    └── OrderService.java
 ├── repository/
 │    └── OrderRepository.java
 └── model/
      └── Order.java
```

### Core idea: `AbstractRoutingDataSource`

Spring provides `AbstractRoutingDataSource`, which lets you resolve the actual `DataSource` used per-call based on a "lookup key" you supply. We'll set that lookup key from a `ThreadLocal` holding the current shard, resolved from the request's `userId`.

**`ShardContext.java`** — thread-local holder for the current shard:

```java
package com.example.sharding.config;

public final class ShardContext {

    private static final ThreadLocal<Integer> CURRENT_SHARD = new ThreadLocal<>();

    private ShardContext() {}

    public static void setShard(int shardId) {
        CURRENT_SHARD.set(shardId);
    }

    public static Integer getShard() {
        return CURRENT_SHARD.get();
    }

    public static void clear() {
        CURRENT_SHARD.remove();
    }
}
```

**`ShardRoutingDataSource.java`** — tells Spring which physical `DataSource` to use for the current thread:

```java
package com.example.sharding.config;

import org.springframework.jdbc.datasource.lookup.AbstractRoutingDataSource;

public class ShardRoutingDataSource extends AbstractRoutingDataSource {

    @Override
    protected Object determineCurrentLookupKey() {
        // Returns the key used to look up the target DataSource
        // (registered in setTargetDataSources in the config class below)
        return ShardContext.getShard();
    }
}
```

**`ShardDataSourceConfig.java`** — registers 3 physical shards:

```java
package com.example.sharding.config;

import com.zaxxer.hikari.HikariDataSource;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.jdbc.DataSourceBuilder;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import javax.sql.DataSource;
import java.util.HashMap;
import java.util.Map;

@Configuration
public class ShardDataSourceConfig {

    @Value("${shard.count:3}")
    private int shardCount;

    @Bean
    public DataSource shard0DataSource() {
        return buildDataSource("jdbc:mysql://shard0-host:3306/orders_shard0");
    }

    @Bean
    public DataSource shard1DataSource() {
        return buildDataSource("jdbc:mysql://shard1-host:3306/orders_shard1");
    }

    @Bean
    public DataSource shard2DataSource() {
        return buildDataSource("jdbc:mysql://shard2-host:3306/orders_shard2");
    }

    private DataSource buildDataSource(String url) {
        HikariDataSource ds = DataSourceBuilder.create()
                .type(HikariDataSource.class)
                .url(url)
                .username("app_user")
                .password("app_password")
                .driverClassName("com.mysql.cj.jdbc.Driver")
                .build();
        ds.setMaximumPoolSize(20);
        ds.setPoolName(url);
        return ds;
    }

    // The routing DataSource that Hibernate/JPA actually talks to
    @Bean
    public DataSource routingDataSource(DataSource shard0DataSource,
                                         DataSource shard1DataSource,
                                         DataSource shard2DataSource) {
        ShardRoutingDataSource routingDataSource = new ShardRoutingDataSource();

        Map<Object, Object> targetDataSources = new HashMap<>();
        targetDataSources.put(0, shard0DataSource);
        targetDataSources.put(1, shard1DataSource);
        targetDataSources.put(2, shard2DataSource);

        routingDataSource.setTargetDataSources(targetDataSources);
        routingDataSource.setDefaultTargetDataSource(shard0DataSource);
        routingDataSource.afterPropertiesSet();
        return routingDataSource;
    }
}
```

**`ShardResolverAspect.java`** — resolves and sets the shard *before* any repository call, based on `userId`, using a simple AOP interceptor around service methods:

```java
package com.example.sharding.aspect;

import com.example.sharding.config.ShardContext;
import org.aspectj.lang.ProceedingJoinPoint;
import org.aspectj.lang.annotation.Around;
import org.aspectj.lang.annotation.Aspect;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;

@Aspect
@Component
@Order(1)
public class ShardResolverAspect {

    private static final int SHARD_COUNT = 3;

    // Any service method annotated with @ShardedBy("userId") gets routed automatically
    @Around("@annotation(com.example.sharding.config.ShardedByUserId) && args(userId,..)")
    public Object routeByUserId(ProceedingJoinPoint pjp, Long userId) throws Throwable {
        try {
            int shardId = resolveShard(userId);
            ShardContext.setShard(shardId);
            return pjp.proceed();
        } finally {
            ShardContext.clear(); // always clean up — thread pools reuse threads!
        }
    }

    private int resolveShard(Long userId) {
        // Simple, deterministic hash-based routing
        return (int) (Math.floorMod(userId, SHARD_COUNT));
    }
}
```

A tiny marker annotation makes the aspect declarative and easy to apply:

```java
package com.example.sharding.config;

import java.lang.annotation.*;

@Target(ElementType.METHOD)
@Retention(RetentionPolicy.RUNTIME)
public @interface ShardedByUserId {}
```

**`OrderService.java`** — usage:

```java
package com.example.sharding.service;

import com.example.sharding.config.ShardedByUserId;
import com.example.sharding.model.Order;
import com.example.sharding.repository.OrderRepository;
import org.springframework.stereotype.Service;

@Service
public class OrderService {

    private final OrderRepository orderRepository;

    public OrderService(OrderRepository orderRepository) {
        this.orderRepository = orderRepository;
    }

    @ShardedByUserId
    public Order createOrder(Long userId, Order order) {
        order.setUserId(userId);
        return orderRepository.save(order); // goes to the correct physical shard
    }

    @ShardedByUserId
    public java.util.List<Order> getOrdersForUser(Long userId) {
        return orderRepository.findByUserId(userId);
    }
}
```

**`application.yml`** (base config; per-shard URLs are set programmatically above):

```yaml
spring:
  jpa:
    hibernate:
      ddl-auto: validate
    properties:
      hibernate:
        dialect: org.hibernate.dialect.MySQLDialect
  datasource:
    hikari:
      connection-timeout: 5000

shard:
  count: 3
```

### Common mistakes when implementing sharding
- **Forgetting to clear the `ThreadLocal`** after the call — under a pooled thread executor, a leaked shard ID silently routes the *next unrelated request* to the wrong shard. Always clear in a `finally` block.
- **Picking a shard key that doesn't match query patterns**, forcing scatter-gather for common reads.
- **Assuming JPA-level `@ManyToOne`/`@OneToMany` relationships work across shards** — they do not; Hibernate has no concept of "this related row is on a different database."
- **No plan for resharding** — teams often hardcode `% N` shard counts, making it painful later to add capacity.

---

# 2. Partitioning

## 2.1 What is it?

**Analogy:** Picture one giant warehouse (a single database server) that stores a company's inventory. Instead of building separate warehouses in different cities (that would be sharding), you simply organize *shelves within the same warehouse* by category — Electronics on aisle 1, Furniture on aisle 2, and so on. It's still one building, one address, one staff — just internally organized so a forklift only has to check the relevant aisle instead of walking the whole warehouse.

**Technical definition:** Partitioning splits a single large table into multiple physical sub-tables (**partitions**) *within the same database server/instance*, based on the values of a partition key. Unlike sharding, this is transparent to the application — you still connect to one database and run normal SQL; MySQL's storage engine decides which partition(s) to read or write.

## 2.2 Why is it used?

**Problems it solves:**
- A single huge table (hundreds of millions of rows) becomes slow to scan, slow to index, and slow to maintain (e.g., `ALTER TABLE`, backups).
- Deleting old data (e.g., logs older than 90 days) from a giant table is slow with `DELETE`, but instantly fast if that data is isolated in its own partition (`DROP PARTITION`).

**Benefits:**
- **Partition pruning** — the optimizer skips partitions that can't contain matching rows, dramatically speeding up range-filtered queries.
- Easier maintenance: you can back up, rebuild indexes on, or drop a single partition without touching the rest of the table.
- No application changes required — it's purely a storage-layer optimization.

**Trade-offs:**
- Doesn't add compute or memory — the whole table still lives on one server, so it doesn't solve a server-level bottleneck the way sharding does.
- Partition key becomes a strong influence on query design — queries that don't filter on it get no pruning benefit.
- Some constraints in MySQL: every unique key (including the primary key) must include the partitioning column.

## 2.3 When should you use it?

- Very large, single-server tables where queries commonly filter by a natural range, like date (`created_at`) or category (`region`, `status`).
- Time-series data with a rolling retention window (metrics, logs, events) — `DROP PARTITION` is far faster than a bulk `DELETE`.
- You want the maintenance/performance benefits but don't yet need (or want the complexity of) multiple servers.

Practical examples: a `orders` table partitioned by `YEAR(order_date)` at an e-commerce company so quarterly reporting queries only scan relevant partitions; a `logs` table partitioned by day, with a daily job that drops the partition for 91 days ago.

## 2.4 How does it work?

Partitioning is handled by MySQL's storage engine (InnoDB), not by the application. You declare it in the `CREATE TABLE` statement, and MySQL takes care of routing each row's storage and each query's execution across the right partitions.

### Types of MySQL partitioning

| Type | Rule | Good for |
|---|---|---|
| **RANGE** | Row goes into a partition based on a value falling within a range | Dates, sequential IDs |
| **LIST** | Row goes into a partition based on matching a discrete value in a set | Fixed categories (region, status) |
| **HASH** | MySQL applies a hash function to the key and picks a partition | Even distribution with no natural ranges |
| **KEY** | Like HASH, but MySQL supplies the hashing function internally (supports multiple columns) | Similar to HASH, more automatic |

### Example: RANGE partitioning by date

```sql
CREATE TABLE orders (
    id BIGINT NOT NULL AUTO_INCREMENT,
    user_id BIGINT NOT NULL,
    order_date DATE NOT NULL,
    total_amount DECIMAL(10,2) NOT NULL,
    PRIMARY KEY (id, order_date)
)
PARTITION BY RANGE (YEAR(order_date)) (
    PARTITION p2023 VALUES LESS THAN (2024),
    PARTITION p2024 VALUES LESS THAN (2025),
    PARTITION p2025 VALUES LESS THAN (2026),
    PARTITION p2026 VALUES LESS THAN (2027),
    PARTITION pmax  VALUES LESS THAN MAXVALUE
);
```

### Example: HASH partitioning for even spread

```sql
CREATE TABLE sessions (
    id BIGINT NOT NULL AUTO_INCREMENT,
    user_id BIGINT NOT NULL,
    created_at DATETIME NOT NULL,
    PRIMARY KEY (id, user_id)
)
PARTITION BY HASH(user_id)
PARTITIONS 8;
```

### Example: LIST partitioning by region

```sql
CREATE TABLE customers (
    id BIGINT NOT NULL AUTO_INCREMENT,
    name VARCHAR(255) NOT NULL,
    region VARCHAR(10) NOT NULL,
    PRIMARY KEY (id, region)
)
PARTITION BY LIST COLUMNS(region) (
    PARTITION p_na VALUES IN ('US', 'CA', 'MX'),
    PARTITION p_eu VALUES IN ('DE', 'FR', 'UK'),
    PARTITION p_apac VALUES IN ('JP', 'IN', 'AU')
);
```

### Partition pruning in action

```sql
EXPLAIN SELECT * FROM orders WHERE order_date BETWEEN '2026-01-01' AND '2026-03-31';
```
The `EXPLAIN` output's `partitions` column will show only `p2026` — MySQL never touches `p2023`, `p2024`, or `p2025` at all. This is **partition pruning**, and it's the main performance win.

### How indexes behave

- Indexes in a partitioned InnoDB table are **local by default** — each partition has its own copy of every index, not one global index across all partitions.
- Any unique index (including the primary key) **must include all columns used in the partitioning expression** — this is a hard MySQL requirement, and it's the most common `ERROR 1503` developers hit when partitioning an existing table.

### ASCII diagram

```
              orders  (one logical table, one connection)
   ┌───────────────────────────────────────────────────┐
   │  Partition p2024   Partition p2025   Partition p2026 │
   │  (Jan–Dec 2024)    (Jan–Dec 2025)    (Jan–Dec 2026)   │
   └───────────────────────────────────────────────────┘
   Query WHERE order_date >= '2026-01-01'
        └──> optimizer prunes to p2026 only
```

## 2.5 When should you NOT use it?

- The table is small enough that a full scan is already fast (a few million rows or less on well-indexed InnoDB tables rarely need partitioning).
- Queries don't consistently filter on the partition key — you get all the schema complexity with none of the pruning benefit.
- You need foreign keys referencing/from the partitioned table — MySQL partitioning does **not** support foreign keys.
- You're trying to solve a *server capacity* problem (CPU/RAM/disk saturation) — partitioning doesn't add hardware, so it won't help; you need sharding or a bigger box instead.

**Common pitfall:** adding partitioning to an existing table without updating the primary/unique keys to include the partition column, hitting `ERROR 1503: A PRIMARY KEY must include all columns in the table's partitioning function`.

## 2.6 How is it implemented in production code

The good news: **partitioning is invisible to Spring Data JPA and Hibernate.** You don't write different repository code — the entity maps to the table exactly as normal, and MySQL routes it under the hood.

```java
package com.example.partitioning.model;

import jakarta.persistence.*;
import java.math.BigDecimal;
import java.time.LocalDate;

@Entity
@Table(name = "orders")
@IdClass(OrderId.class)
public class Order {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Id
    @Column(name = "order_date", nullable = false)
    private LocalDate orderDate; // must be part of the ID because MySQL requires
                                  // the partition column in every unique key

    @Column(name = "user_id", nullable = false)
    private Long userId;

    @Column(name = "total_amount", nullable = false)
    private BigDecimal totalAmount;

    // getters/setters omitted for brevity
}
```

```java
package com.example.partitioning.model;

import java.io.Serializable;
import java.time.LocalDate;
import java.util.Objects;

public class OrderId implements Serializable {
    private Long id;
    private LocalDate orderDate;

    public OrderId() {}
    public OrderId(Long id, LocalDate orderDate) {
        this.id = id;
        this.orderDate = orderDate;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (!(o instanceof OrderId that)) return false;
        return Objects.equals(id, that.id) && Objects.equals(orderDate, that.orderDate);
    }

    @Override
    public int hashCode() {
        return Objects.hash(id, orderDate);
    }
}
```

```java
package com.example.partitioning.repository;

import com.example.partitioning.model.Order;
import com.example.partitioning.model.OrderId;
import org.springframework.data.jpa.repository.JpaRepository;
import java.time.LocalDate;
import java.util.List;

public interface OrderRepository extends JpaRepository<Order, OrderId> {
    // Query is written normally; MySQL prunes partitions automatically
    List<Order> findByOrderDateBetween(LocalDate start, LocalDate end);
}
```

Because Hibernate's `ddl-auto` doesn't know how to generate `PARTITION BY` clauses, the table itself is normally created via a Flyway/Liquibase migration script containing the raw `CREATE TABLE ... PARTITION BY ...` DDL shown in section 2.4, with `spring.jpa.hibernate.ddl-auto: validate` so Hibernate never tries to regenerate the schema.

---

# 3. Read Replicas

## 3.1 What is it?

**Analogy:** Think of a popular restaurant with one head chef (the **primary**) who is the only one allowed to *cook* new dishes (writes). To handle a big lunch crowd, the restaurant makes several identical copies of each finished dish and puts them on serving stations around the room (the **replicas**) — customers who just want to *look at or eat* an already-made dish (reads) can go to any station, so the head chef isn't the bottleneck for serving people, only for cooking new food.

**Technical definition:** A read replica is a copy of a database that continuously receives a stream of changes from a **primary** (writer) instance via replication, and can serve read-only queries. All writes go to the primary; reads can be distributed across one or more replicas to spread out read load.

## 3.2 Why is it used?

**Problems it solves:**
- Read-heavy applications (most web apps: many more reads than writes) can bottleneck a single database's read capacity long before write capacity becomes an issue.
- Provides a natural, low-effort scaling path before jumping to sharding.

**Benefits:**
- Scales read throughput roughly linearly by adding more replicas.
- Improves availability: a replica can be promoted to primary if the original primary fails.
- Can isolate expensive analytical/reporting queries onto a dedicated replica, protecting the primary from being slowed down by them.

**Trade-offs:**
- Replication is (in the common case) **asynchronous**, so replicas lag behind the primary by some amount of time (**replica lag**) — reads from a replica can return stale data.
- Doesn't help write throughput at all — all writes still funnel through one primary.
- Adds operational complexity: monitoring lag, handling failover, routing logic in the app.

## 3.3 When should you use it?

- Read:write ratio is high (e.g., a content site with far more page views than content updates).
- You want to offload reporting/analytics queries so they don't compete with production traffic on the primary.
- You want a warm standby for failover/high availability.

Real-world use: most e-commerce catalog browsing (product pages, search) is served from replicas, while checkout/order writes hit the primary; SaaS dashboards often run heavy aggregate queries against a dedicated "reporting" replica.

## 3.4 How does it work?

### Primary vs Replica architecture

```
        WRITES                         READS
           │                              │
           ▼                              ▼
   ┌───────────────┐   binlog    ┌────────────────┐
   │   Primary DB    │ ────────► │   Replica DB 1   │
   │  (MySQL 8)      │ ────────► │   Replica DB 2   │
   └───────────────┘   stream    └────────────────┘
```

### Replication flow

1. The primary records every data change (INSERT/UPDATE/DELETE) in its **binary log (binlog)**.
2. Each replica runs an I/O thread that continuously pulls new binlog events from the primary.
3. The replica's SQL thread applies those events to its own copy of the data, in order.
4. This is typically **asynchronous** — the primary doesn't wait for replicas to confirm before considering a write complete (MySQL also supports **semi-synchronous** replication, where the primary waits for at least one replica to acknowledge receipt, trading a little latency for less risk of data loss on failover).

### Read-after-write consistency & replica lag

Because replication is asynchronous, there's a window (**replica lag**, often milliseconds, but can spike to seconds under load) where a replica doesn't yet reflect a write that just happened on the primary. This causes a classic bug: a user updates their profile, then immediately reloads the page and sees the *old* data because the read hit a lagging replica.

**Common mitigation strategies:**
- **Sticky sessions / read-your-own-writes:** after a user performs a write, route their subsequent reads (for some short window) to the primary instead of a replica.
- **Monotonic reads:** always route a given user's reads to the *same* replica, so they never see time go "backwards" even if they see slightly stale data.
- **Lag-aware routing:** monitor each replica's lag (`SHOW REPLICA STATUS`) and skip any replica lagging beyond an acceptable threshold.

## 3.5 When should you NOT use it?

- Your workload is write-heavy — read replicas don't help write throughput at all.
- Your application cannot tolerate *any* staleness (e.g., financial balance checks immediately before a transaction) without adding read-your-own-write logic — naively routing such reads to a replica introduces subtle bugs.
- Traffic is low enough that a single primary handles reads and writes comfortably — added replicas are pure operational overhead with no benefit.

**Common pitfall:** routing *every* read to a replica indiscriminately, including reads that immediately follow a write in the same user flow, causing confusing "my change didn't save!" support tickets that are actually just replica lag.

## 3.6 How is it implemented in production code

### Project structure

```
src/main/java/com/example/replicas
 ├── config/
 │    ├── ReplicationDataSourceConfig.java
 │    ├── ReplicaRoutingDataSource.java
 │    └── DataSourceContextHolder.java
 ├── aspect/
 │    └── ReadOnlyRoutingAspect.java
 ├── controller/
 │    └── ProductController.java
 ├── service/
 │    └── ProductService.java
 ├── repository/
 │    └── ProductRepository.java
 └── model/
      └── Product.java
```

### The key Spring mechanism: `@Transactional(readOnly = true)` + a routing `DataSource`

Spring's `@Transactional(readOnly = true)` doesn't automatically route to a replica by itself — but it's the perfect signal to hook into with a custom `TransactionSynchronization`/AOP layer to switch the active `DataSource`.

**`DataSourceContextHolder.java`:**

```java
package com.example.replicas.config;

public final class DataSourceContextHolder {

    public enum DataSourceType { PRIMARY, REPLICA }

    private static final ThreadLocal<DataSourceType> CONTEXT = new ThreadLocal<>();

    private DataSourceContextHolder() {}

    public static void set(DataSourceType type) {
        CONTEXT.set(type);
    }

    public static DataSourceType get() {
        return CONTEXT.get() == null ? DataSourceType.PRIMARY : CONTEXT.get();
    }

    public static void clear() {
        CONTEXT.remove();
    }
}
```

**`ReplicaRoutingDataSource.java`:**

```java
package com.example.replicas.config;

import org.springframework.jdbc.datasource.lookup.AbstractRoutingDataSource;

public class ReplicaRoutingDataSource extends AbstractRoutingDataSource {

    @Override
    protected Object determineCurrentLookupKey() {
        return DataSourceContextHolder.get();
    }
}
```

**`ReadOnlyRoutingAspect.java`** — the important piece: intercept every `@Transactional` call and check its `readOnly` flag:

```java
package com.example.replicas.aspect;

import com.example.replicas.config.DataSourceContextHolder;
import org.aspectj.lang.ProceedingJoinPoint;
import org.aspectj.lang.annotation.Around;
import org.aspectj.lang.annotation.Aspect;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

@Aspect
@Component
@Order(0) // must run before Spring's own @Transactional interceptor
public class ReadOnlyRoutingAspect {

    @Around("@annotation(transactional)")
    public Object route(ProceedingJoinPoint pjp, Transactional transactional) throws Throwable {
        boolean isReadOnly = transactional.readOnly();
        try {
            DataSourceContextHolder.set(isReadOnly
                    ? DataSourceContextHolder.DataSourceType.REPLICA
                    : DataSourceContextHolder.DataSourceType.PRIMARY);
            return pjp.proceed();
        } finally {
            DataSourceContextHolder.clear();
        }
    }
}
```

**`ReplicationDataSourceConfig.java`:**

```java
package com.example.replicas.config;

import com.zaxxer.hikari.HikariDataSource;
import org.springframework.boot.jdbc.DataSourceBuilder;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import javax.sql.DataSource;
import java.util.Map;

@Configuration
public class ReplicationDataSourceConfig {

    @Bean
    public DataSource primaryDataSource() {
        return build("jdbc:mysql://primary-host:3306/appdb");
    }

    @Bean
    public DataSource replicaDataSource() {
        return build("jdbc:mysql://replica-host:3306/appdb?readOnly=true");
    }

    private DataSource build(String url) {
        HikariDataSource ds = DataSourceBuilder.create()
                .type(HikariDataSource.class)
                .url(url)
                .username("app_user")
                .password("app_password")
                .driverClassName("com.mysql.cj.jdbc.Driver")
                .build();
        ds.setMaximumPoolSize(20);
        return ds;
    }

    @Bean
    public DataSource routingDataSource(DataSource primaryDataSource, DataSource replicaDataSource) {
        ReplicaRoutingDataSource routingDataSource = new ReplicaRoutingDataSource();
        routingDataSource.setTargetDataSources(Map.of(
                DataSourceContextHolder.DataSourceType.PRIMARY, primaryDataSource,
                DataSourceContextHolder.DataSourceType.REPLICA, replicaDataSource
        ));
        routingDataSource.setDefaultTargetDataSource(primaryDataSource);
        routingDataSource.afterPropertiesSet();
        return routingDataSource;
    }
}
```

**`ProductService.java`** — end-to-end usage:

```java
package com.example.replicas.service;

import com.example.replicas.model.Product;
import com.example.replicas.repository.ProductRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class ProductService {

    private final ProductRepository productRepository;

    public ProductService(ProductRepository productRepository) {
        this.productRepository = productRepository;
    }

    @Transactional(readOnly = true) // ──> routed to REPLICA
    public Product getProduct(Long id) {
        return productRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Not found"));
    }

    @Transactional // readOnly = false (default) ──> routed to PRIMARY
    public Product updatePrice(Long id, java.math.BigDecimal newPrice) {
        Product product = productRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Not found"));
        product.setPrice(newPrice);
        return productRepository.save(product);
    }
}
```

**`ProductController.java`** — the request never needs to know about shards or replicas; that's the point:

```java
package com.example.replicas.controller;

import com.example.replicas.model.Product;
import com.example.replicas.service.ProductService;
import org.springframework.web.bind.annotation.*;
import java.math.BigDecimal;

@RestController
@RequestMapping("/products")
public class ProductController {

    private final ProductService productService;

    public ProductController(ProductService productService) {
        this.productService = productService;
    }

    @GetMapping("/{id}")
    public Product get(@PathVariable Long id) {
        return productService.getProduct(id); // Controller → Service → Repository → REPLICA
    }

    @PutMapping("/{id}/price")
    public Product updatePrice(@PathVariable Long id, @RequestParam BigDecimal price) {
        return productService.updatePrice(id, price); // Controller → Service → Repository → PRIMARY
    }
}
```

**`application.yml`:**

```yaml
spring:
  jpa:
    hibernate:
      ddl-auto: validate
    properties:
      hibernate:
        dialect: org.hibernate.dialect.MySQLDialect
  datasource:
    hikari:
      maximum-pool-size: 20
      connection-timeout: 5000

app:
  datasource:
    primary:
      url: jdbc:mysql://primary-host:3306/appdb
    replica:
      url: jdbc:mysql://replica-host:3306/appdb?readOnly=true
```

### Solving read-your-own-writes

A simple, common pattern: store a short-lived flag (e.g., in the session or a Redis key) after any write, and force the *next* read for that user within a few seconds to hit the primary regardless of the `readOnly` annotation — then fall back to normal replica routing.

### Common mistakes when implementing read replicas
- Forgetting `@Order(0)` on the routing aspect, so it runs *after* Spring's transaction interceptor has already opened a connection against the wrong `DataSource`.
- Marking a method `@Transactional(readOnly = true)` while it actually performs a write hidden inside a called method — the write silently goes to a read-only replica connection and fails (or worse, is silently ignored depending on driver settings).
- Not monitoring replica lag in production, so a "replica caught up" assumption quietly breaks under load spikes.
- Never clearing the `ThreadLocal`, causing shard/replica "bleed" between requests on pooled threads (same issue as in sharding).

---

# 4. Comparison Table

| Dimension | Sharding | Partitioning | Read Replicas |
|---|---|---|---|
| **Purpose** | Scale writes + storage across multiple servers | Improve manageability/performance of a large table on one server | Scale read throughput; improve availability |
| **Scalability** | Very high (horizontal, near-linear with shard count) | Limited — bounded by single server's capacity | High for reads only; writes remain bottlenecked at primary |
| **Performance Impact** | Big win for write-heavy, huge-scale systems | Big win for range-filtered queries via partition pruning | Big win for read-heavy systems |
| **Data Distribution** | Across multiple independent database servers | Within one server, across physical sub-tables | Full copies of the same data on multiple servers |
| **Data Consistency** | Strong per-shard; cross-shard requires sagas/2PC | Strong (single database, standard ACID) | Eventually consistent on replicas (replica lag) |
| **Complexity** | Very high (routing, resharding, cross-shard logic) | Low–Medium (schema/DDL only, no app changes) | Medium (routing logic, lag handling) |
| **Cost** | High (N servers, N times the ops overhead) | Low (same server, just schema design) | Medium (extra server(s) per replica) |
| **Fault Tolerance** | One shard down affects only its slice of users | No isolation — one server down affects everyone | High — replica can be promoted on primary failure |
| **Typical Use Cases** | Massive multi-tenant SaaS, huge social platforms | Time-series/log tables, large reporting tables | Read-heavy web/mobile apps, dashboards, HA setups |

---

# 5. How They Work Together

These three techniques are not mutually exclusive — large systems typically layer all three:

- **Sharding** splits the overall dataset across independent database clusters (e.g., by `tenant_id`).
- **Partitioning** is applied *within each shard* to keep individual tables manageable (e.g., partition each shard's `events` table by month).
- **Read replicas** are attached to *each shard's primary* to absorb read traffic for that shard.

### Full architecture diagram

```
                              Client
                                │
                        Load Balancer
                                │
                    Spring Boot Application
                                │
                          Shard Router
                    (resolves shard by tenant_id)
                                │
        ┌───────────────────────┴───────────────────────┐
        ▼                                                 ▼
   ┌─────────────────────┐                       ┌─────────────────────┐
   │       Shard 1         │                       │       Shard 2         │
   │  ┌─────────────────┐ │                       │  ┌─────────────────┐ │
   │  │ Primary (MySQL)   │ │                       │  │ Primary (MySQL)   │ │
   │  │ table partitioned │ │                       │  │ table partitioned │ │
   │  │ by month           │ │                       │  │ by month           │ │
   │  └─────────┬─────────┘ │                       │  └─────────┬─────────┘ │
   │            │ binlog     │                       │            │ binlog     │
   │  ┌─────────▼─────────┐ │                       │  ┌─────────▼─────────┐ │
   │  │  Replica A, B, C   │ │                       │  │  Replica A, B, C   │ │
   │  └───────────────────┘ │                       │  └───────────────────┘ │
   └─────────────────────┘                       └─────────────────────┘
```

### Lifecycle of a write request
1. Request hits the load balancer → Spring Boot app.
2. Shard router computes the shard from the request's `tenant_id`/`user_id`.
3. The app opens a transaction against that shard's **primary**.
4. MySQL writes the row; because the table is partitioned (e.g., by date), InnoDB stores it in the correct physical partition automatically.
5. The primary appends the change to its binlog.
6. Replicas for that shard asynchronously pull and apply the change.

### Lifecycle of a read request
1. Request hits the load balancer → Spring Boot app.
2. Shard router computes the shard.
3. The service method is `@Transactional(readOnly = true)`, so the read-routing aspect selects one of that shard's **replicas**.
4. MySQL's optimizer applies partition pruning to only scan relevant partitions on that replica.
5. Result returned to the client — potentially a few milliseconds stale if replica lag is present.

---

# 6. Real-World Examples

- **Instagram** famously sharded its Postgres database by user ID early on to handle write volume that a single server couldn't sustain, using a custom ID-generation scheme that encodes the shard directly into each ID.
- **Uber** shards trip and location data geographically/by city, since most queries are naturally scoped to a region, and has publicly discussed moving between different sharding schemes (including a well-known migration from Postgres to a custom sharded MySQL-based system, "Schemaless") as write volume grew.
- **YouTube** (Google) built "Vitess," a MySQL sharding middleware, specifically to horizontally scale MySQL for YouTube's metadata while keeping the MySQL query interface familiar to engineers — Vitess is now an open-source CNCF project widely used elsewhere.
- **Amazon**-style e-commerce catalogs commonly rely heavily on read replicas: product browsing/search reads are served from replicas at massive scale, while order placement writes go to primaries, since browsing volume vastly exceeds purchase volume.
- **Meta/Facebook** popularized "read-after-write consistency" engineering patterns (sticky routing to a "master region" briefly after a write) precisely because their read replica fleets are geographically distributed and lag is unavoidable at that scale.
- **Netflix** relies heavily on time-partitioned tables and dedicated read-replica fleets for its viewing-history and analytics pipelines, isolating heavy analytical reads from latency-sensitive production paths.

---

# 7. Common Interview Questions

1. **What's the difference between sharding and partitioning?**
   Sharding splits data across multiple independent database servers; partitioning splits a table into physical sub-tables within a single server. Sharding is an application/architecture-level concept; partitioning is typically a database-engine feature.

2. **What is a shard key, and what makes a good one?**
   The column used to decide which shard a row belongs to. A good shard key has high cardinality, distributes load evenly, and matches the most common query filter to avoid scatter-gather.

3. **What is replica lag, and how do you mitigate it?**
   The delay between a write landing on the primary and that change appearing on a replica, caused by asynchronous replication. Mitigated via sticky/read-your-own-write routing, monotonic read routing, or lag-aware load balancing.

4. **How do you handle a transaction that spans multiple shards?**
   Ideally you avoid it by shard-key design. If unavoidable, use the saga pattern (sequence of local transactions with compensations) or, rarely, distributed transactions (2PC/XA), accepting the performance and availability costs.

5. **What is partition pruning?**
   The query optimizer's ability to skip partitions that cannot contain rows matching the query's filters, based on the partitioning column, dramatically reducing the data scanned.

6. **When would you choose hash-based vs range-based sharding?**
   Hash-based gives even distribution but makes resharding expensive (most keys move when the shard count changes). Range-based makes it easy to add shards for new ranges without touching existing data, but can create hot spots if traffic isn't uniform across ranges.

7. **How would you scale reads without sharding?**
   Add read replicas and route read-only queries to them (e.g., via `@Transactional(readOnly = true)` and a routing `DataSource`), alongside caching layers like Redis for very hot data.

8. **What breaks when you naively route all reads to replicas?**
   Read-your-own-writes bugs: a user's own recent write may not yet be visible on the replica they're routed to, making it look like their action failed or didn't save.

9. **How do you add a new shard to a hash-sharded system with minimal downtime?**
   Typically via consistent hashing to limit how many keys move, combined with a dual-write + backfill + verify + cutover migration process rather than a hard cutover.

10. **Can you use foreign keys with partitioned tables in MySQL?**
    No — MySQL does not support foreign key constraints referencing or defined on partitioned tables; referential integrity must be enforced at the application level in that case.

---

# 8. Interesting Related Concepts

- **Vertical vs Horizontal Scaling:** Vertical scaling means making one server bigger (more CPU/RAM); horizontal scaling means adding more servers (sharding, replicas). Vertical is simpler but hits a hardware ceiling; horizontal scales further but adds distributed-systems complexity.
- **CAP Theorem:** In the presence of a network partition, a distributed system must choose between Consistency (every read sees the latest write) and Availability (every request gets a response). Asynchronous read replicas are a practical example of choosing availability/performance over strict consistency.
- **Replication vs Backup:** Replication is a live, continuously updated copy for scaling/availability; a backup is a point-in-time snapshot for disaster recovery. Replication does not protect against someone accidentally deleting data — that mistake replicates too.
- **Leader-Follower Replication:** The general term for the primary/replica pattern described here — one node accepts writes (leader) and propagates them to one or more followers.
- **Consistent Hashing:** A hashing technique where adding or removing a node only remaps a small fraction of keys (instead of nearly all of them, as with plain `hash % N`), used to minimize data movement when resharding.
- **Database Federation:** Splitting a database by *function* (e.g., a "users" database, a separate "orders" database) rather than by a key within one table's data — a coarser-grained alternative or precursor to sharding.
- **CQRS (Command Query Responsibility Segregation):** An architectural pattern that separates the write model from the read model, sometimes using entirely different data stores optimized for each — conceptually related to routing writes/reads differently, as with read replicas, but taken further.
- **Event Sourcing:** Instead of storing current state, you store an append-only log of events, and current state is derived by replaying them — often paired with CQRS in high-scale systems.
- **Database Indexing vs Partitioning:** Indexing speeds up lookups within a table via an auxiliary data structure; partitioning physically divides the table itself. They're complementary — partitioned tables still have (local) indexes per partition.
- **Caching vs Read Replicas:** A cache (e.g., Redis) stores precomputed or recently-accessed results in memory for extremely fast reads, entirely bypassing the database; a read replica is still a full database that runs real queries, just distributing load. Caching is faster but must be explicitly invalidated; replicas stay automatically in sync (with lag).

---

# 9. Key Takeaways

- **Sharding** splits data across independent database servers to scale writes and storage horizontally — powerful, but operationally expensive and hard to undo; pick your shard key carefully because it dictates what queries stay cheap.
- **Partitioning** splits a table into physical sub-tables *within one server* — a lower-complexity, high-value optimization for very large tables with range- or category-based query patterns, but it doesn't add compute capacity.
- **Read Replicas** scale read throughput and improve availability by serving reads from asynchronously-updated copies — cheap to adopt relative to sharding, but introduce replica lag that the application must explicitly handle (especially read-your-own-writes).
- These techniques **compose**: large real-world systems commonly shard by tenant/user, partition tables within each shard, and attach read replicas to each shard's primary.
- **Order of adoption matters:** most teams should exhaust replicas, caching, indexing, and partitioning before reaching for sharding, since sharding's operational cost is by far the highest of the three.
- In Spring Boot, both sharding and read-replica routing are commonly implemented with `AbstractRoutingDataSource` plus a `ThreadLocal` context set by an AOP aspect — always clear that `ThreadLocal` in a `finally` block to avoid state leaking across pooled threads.
- Partitioning requires **no application code changes** — it's pure schema/DDL, making it the lowest-risk technique of the three to introduce.
