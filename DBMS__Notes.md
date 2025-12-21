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

# Deep Dive: Log-Structured Merge-Trees (LSM Trees)

**Log-Structured Merge-Trees (LSM Trees)** are the foundational data structure behind modern write-heavy databases (e.g., RocksDB, Cassandra, HBase, BigTable).

## 1. The Core Philosophy
Traditional databases (like B-Trees used in MySQL/Postgres) are optimized for **Reads**. They attempt to keep data perfectly organized on disk at all times, often resulting in slow "random I/O" for writes.

LSM Trees are optimized for **Writes**.
* **Philosophy:** "Never modify a file on disk. Always append."
* **Benefit:** By treating the disk like a log, LSM trees achieve write throughputs orders of magnitude higher than B-Trees because sequential I/O is significantly faster than random I/O (even on SSDs).

---

## 2. The Architecture
An LSM Tree is not a single tree; it is a layered collection of components spanning Memory and Disk.

### A. The MemTable (Memory Table)
* **Location:** RAM.
* **Structure:** Usually a SkipList or Red-Black Tree.
* **Role:** Buffers incoming writes. Because it lives in RAM, inserts are extremely fast ($O(\log n)$).
* **Ordering:** Keeps data sorted by Key.

### B. The WAL (Write-Ahead Log)
* **Location:** Disk (Sequential Append).
* **Role:** Durability.
* **Mechanism:** Before writing to the MemTable, the database appends the command to a log file. If the server crashes, the MemTable (RAM) is lost, but the database can rebuild it by replaying the WAL.

### C. SSTables (Sorted String Tables)
* **Location:** Disk.
* **Role:** Long-term storage. When a MemTable is full, it is flushed to disk as an SSTable.
* **Properties:**
    * **Immutable:** Once written, an SSTable is never modified.
    * **Sorted:** Keys are sorted, allowing for efficient Binary Search and merging.

---

## 3. The Lifecycle of a Query

### The Write Path (Fast)
1.  **Append to WAL:** Sequential write to disk (ensures safety).
2.  **Insert into MemTable:** Update the in-memory structure.
3.  **Ack:** The client receives "Success."
    * *Note:* No disk seeking occurs here, making writes incredibly fast.

### The Flush (MemTable $\rightarrow$ SSTable)
When the MemTable reaches a threshold (e.g., 64MB):
1.  It becomes immutable (read-only).
2.  A new MemTable is created for incoming traffic.
3.  The old MemTable is flushed to disk as a **Level 0 SSTable**.
4.  The old WAL is deleted.

### The Read Path (Complex)
Because data is fragmented across the MemTable and multiple SSTable files, reading is slower than writing. To find `Key: user_123`:

1.  **Check MemTable:** Is it in memory? (If yes, return).
2.  **Check SSTables (Newest $\rightarrow$ Oldest):**
    * Search `SSTable_L0_Latest`
    * Search `SSTable_L0_Older`
    * Search `SSTable_L1`
3.  **Return:** The first instance found is the current truth.

---

## 4. Critical Optimization: Bloom Filters
Checking 1,000 SSTables for a key that doesn't exist is expensive.

* **Solution:** Every SSTable has a **Bloom Filter** (a probabilistic memory structure).
* **Mechanism:** Before accessing the disk, the DB asks the Bloom Filter: *"Does this file contain Key X?"*
    * **"No":** 100% accurate. We skip the file (saving I/O).
    * **"Maybe":** We read the file to verify.

---

## 5. Updates and Deletes
Since SSTables are immutable, we cannot physically delete or overwrite a row.

* **Updates:** The DB writes a new record with the same key and a newer timestamp. During a read, the system sees the newer version first (in a newer SSTable or MemTable) and stops searching.
* **Deletes (Tombstones):** The DB writes a special marker called a **Tombstone** for that key.
    * *Example:* `Key: user_123, Value: [TOMBSTONE]`
    * When the read path hits a Tombstone, it returns "Not Found" and ignores older data.

---

## 6. Compaction: The "Merge" Phase
Over time, disk usage grows with old data and Tombstones. **Compaction** runs in the background to clean this up.

1.  **Selection:** The system picks several overlapping SSTables.
2.  **Merge Sort:** It merges them into a single, new SSTable.
    * *Since files are already sorted, this is very efficient.*
3.  **Purge:** It discards overwritten values and physically removes data marked by old Tombstones.
4.  **Replace:** The old input SSTables are deleted.

### Strategies
* **Leveled Compaction (RocksDB):** Aggressive merging to minimize the number of files. Good for read performance.
* **Size-Tiered Compaction (Cassandra):** Delays merging until files are similar sizes. Better for write performance but read performance varies.

---

## 7. Summary: LSM vs. B-Tree

| Feature | LSM Tree (e.g., RocksDB) | B-Tree (e.g., MySQL InnoDB) |
| :--- | :--- | :--- |
| **Write Pattern** | Sequential (Append-only) | Random (Update-in-place) |
| **Write Performance** | **High** | Moderate |
| **Read Performance** | Moderate (Check multiple files) | **High** (Single structure lookup) |
| **Space Efficiency** | Moderate (Stores multiple versions) | High (Overwrites data) |
| **Best For** | High Ingestion, Logs, IoT | Read-Heavy, Transactional |
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

- **Question:**
  > Why count(*) is slow or why do seq scan?
  There is no variable size for each transaction this variable can be different. 
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
