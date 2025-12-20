# Deep Dive: SQL Database Internals & Systems Design

---

## I. Storage Engine & Indexing

At the lowest level, the database must make decisions about how to arrange data on a physical disk to optimize for either fast reads or fast writes.

### 1. Data Structures: B-Trees vs. LSM Trees

Almost all storage engines rely on one of these two structures.

#### B-Trees  
*(e.g., PostgreSQL, standard MySQL InnoDB)*

- **Design:**  
  A balanced tree data structure that maintains sorted data and allows searches, sequential access, insertions, and deletions in logarithmic time (O(log n)).  
  Data is stored in fixed-size pages (usually 4KB or 8KB).

- **Use Case:**  
  **Read-heavy workloads.**  
  Because the tree is balanced, looking up any specific key is very fast.

- **Trade-off:**  
  Random writes can be slow because updating a row may require:
  - Re-balancing the tree
  - Random I/O to update specific pages on disk

---

#### LSM Trees (Log-Structured Merge Trees)  
*(e.g., RocksDB, Cassandra, modern NewSQL systems)*

- **Design:**  
  Optimized for writes.
  - Incoming writes are buffered in memory (**MemTable**)
  - When full, data is flushed to disk as immutable **SSTables (Sorted String Tables)**
  - Background **compaction** merges SSTables

- **Use Case:**  
  **Write-heavy workloads.**  
  Converts random writes into sequential disk writes (append-only).

- **Trade-off:**  
  Reads can be slower because:
  - Multiple SSTables
  - MemTable
  must be checked to find the latest version of a key.

---

### 2. Durability: The Write-Ahead Log (WAL)

How does a database guarantee durability even if the system crashes immediately after a commit?

- **Mechanism:**  
  Before modifying actual data files (e.g., B-Tree pages), changes are first written to a **Write-Ahead Log (WAL)**.

- **Why it works:**  
  - WAL writes are sequential (fast)
  - The database acknowledges a commit **only after** the log entry is safely written to disk

- **Crash Recovery:**  
  On restart, the database:
  - Reads the WAL
  - Replays committed changes that were not yet applied to data files

---

## II. Concurrency Control

When thousands of clients access the same data concurrently, the database must prevent conflicts such as **lost updates**.

### 1. Locking Mechanisms

- **Shared Lock (S-Lock):**
  - Used for **reads**
  - Multiple transactions can hold S-Locks on the same resource simultaneously
  - Readers do not block other readers

- **Exclusive Lock (X-Lock):**
  - Used for **writes**
  - Only one transaction can hold the lock
  - Blocks both readers and writers on the same resource

---

### 2. Multi-Version Concurrency Control (MVCC)

Lock contention severely degrades performance.  
Modern databases (PostgreSQL, MySQL InnoDB) use **MVCC** to reduce locking.

- **Core Idea:**  
  Updates do not overwrite existing rows.  
  Instead, a **new version** of the row is created.

- **Snapshot Isolation:**
  - **Readers:**  
    See the database state as of the moment their transaction started
  - **Writers:**  
    Create new versions without blocking readers

- **Result:**  
  > Readers never block writers, and writers never block readers.

---

## III. Scaling Strategies: Sharding & Partitioning

When a single node reaches limits in CPU, memory, or I/O, scaling is required.

### 1. Partitioning (Single Node)

Splitting a table into smaller pieces **within the same database instance**.

- **Horizontal Partitioning:**  
  - Partition by rows  
  - Example:  
    - Rows 1–1M → Partition A  
    - Rows 1M–2M → Partition B

- **Vertical Partitioning:**  
  - Partition by columns  
  - Useful for rarely accessed or large columns (e.g., BLOBs)
  - Keeps frequently used data hot in memory

---

### 2. Sharding (Multi-Node / Distributed)

Sharding is **horizontal partitioning across multiple physical servers**.

#### Key-Based (Hash) Sharding

- **Logic:**  
  `shard_id = hash(customer_id) % total_shards`

- **Pros:**  
  - Even data distribution

- **Cons:**  
  - Resharding is expensive
  - Adding shards requires moving large amounts of data

---

#### Range-Based Sharding

- **Logic:**  
  - IDs 1–1000 → Shard A  
  - IDs 1001–2000 → Shard B

- **Pros:**  
  - Easy to split large ranges

- **Cons:**  
  - **Hotspots**
  - Sequential keys (timestamps, auto-increment IDs) overload a single shard

---

## IV. Replication & Consistency

### 1. Read Replicas & Replication Logs

To scale reads, databases use **Leader–Follower replication**.

- **Primary (Leader):**
  - Handles all writes
  - Produces a replication stream (Binlog / Replication Log)

- **Replicas (Followers):**
  - Consume the replication log
  - Replay events locally
  - Serve read traffic

---

### 2. Asynchronous Replication & Eventual Consistency

#### Synchronous Replication (Strong Consistency)

- Primary waits for replica acknowledgment
- Guarantees up-to-date reads
- **Trade-off:** High latency

---

#### Asynchronous Replication (Eventual Consistency)

- Primary commits locally and returns success immediately
- Replication happens in the background

- **Replication Lag:**  
  - Replicas may temporarily serve stale data
  - Typical delay: milliseconds to seconds

- **Trade-off:**  
  Performance and availability vs. immediate consistency

---

## V. Distributed Transactions & Systems Theory

### 1. Two-Phase Commit (2PC)

Used when a transaction spans multiple shards.

1. **Prepare Phase**
   - Coordinator asks each shard if it can commit
   - Shards lock data and validate constraints

2. **Commit Phase**
   - If all vote YES → Commit
   - If any vote NO or timeout → Rollback

- **Critique:**
  - Blocking protocol
  - Coordinator is a bottleneck
  - Poor performance at scale

---

### 2. CAP Theorem

In a distributed system, you can only guarantee **two out of three**:

1. **Consistency (C):**  
   Every read sees the most recent write or fails

2. **Availability (A):**  
   Every request gets a response (may be stale)

3. **Partition Tolerance (P):**  
   System continues operating despite network failures

- **Reality:**  
  Network partitions are unavoidable → **P is mandatory**

- **Trade-off:**
  - **CP systems:** Favor correctness (many SQL databases)
  - **AP systems:** Favor availability (many NoSQL databases)

---
