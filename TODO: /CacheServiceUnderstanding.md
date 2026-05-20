You are a principal distributed systems engineer and low-latency infrastructure architect.

I want to design and eventually build an ultra-fast in-memory cache service that will run on Linux containers hosted in AWS ECS.

The primary objective is:
- MAXIMUM runtime performance and throughput
- MINIMUM latency
- MINIMUM lock contention
- MINIMUM concurrency overhead
- HIGH parallel request handling capability

The development speed is NOT important.
Implementation complexity is acceptable if performance improves significantly.

I want a deep technical exploration and architecture recommendation.

-----------------------------------
SYSTEM CONTEXT
-----------------------------------

Deployment target:
- Linux containers
- AWS ECS
- Likely EC2-backed ECS, but discuss Fargate tradeoffs too
- Internal service communication
- Low-latency environment

Potential use cases:
- API cache
- Distributed shared cache
- Fast key-value access
- Possibly 50k to millions of keys
- High read throughput
- Concurrent reads/writes
- Potential future horizontal scaling

-----------------------------------
CORE QUESTIONS TO ANSWER
-----------------------------------

1. LANGUAGE + RUNTIME ANALYSIS

Compare:
- Rust
- C++
- Go
- Java (Netty/virtual threads)
- Node.js
- Zig (optional)
- C

For EACH:
- raw throughput
- memory efficiency
- GC impact
- lock contention behavior
- event-loop efficiency
- NUMA friendliness
- epoll/io_uring compatibility
- async runtime overhead
- multi-core scalability
- implementation complexity
- operational stability

Explain:
- which language is best for an ultra-fast cache
- which is easiest to optimize at kernel/network level
- which gives the best p99 latency

Do NOT give generic answers.

-----------------------------------
2. SINGLE-THREAD CONCURRENCY MODEL
-----------------------------------

I want to understand if a cache service can:
- handle massive simultaneous requests
- using a single-threaded event loop
- similar to Node.js

Explain in depth:
- how Node.js handles massive concurrency on one thread
- epoll
- non-blocking sockets
- kernel event notification
- event loops
- async state machines

Then explain:
- whether a cache server can realistically scale this way
- when single-threaded architecture is superior
- when it becomes a bottleneck
- how Redis handles this internally
- how Redis evolved beyond single-threading

Compare:
- single-thread event loop
- thread-per-request
- worker pool
- sharded single-thread architecture
- actor model

-----------------------------------
3. LOCK-FREE / LOW-CONTENTION DESIGN
-----------------------------------

Explore:
- lock-free hash maps
- RCU
- atomic operations
- CAS
- striped locking
- sharded cache partitions
- per-core ownership
- actor-style ownership

Explain:
- cache-line contention
- false sharing
- memory barriers
- CPU cache coherence costs
- ABA problems
- compare-and-swap retry overhead

I want practical advice, not academic-only theory.

-----------------------------------
4. MEMORY ARCHITECTURE
-----------------------------------

Explain the fastest possible approaches for:
- key storage
- memory allocation
- object pooling
- slab allocators
- arena allocators
- zero-copy reads
- avoiding heap fragmentation

Compare:
- hashmap implementations
- open addressing
- robin hood hashing
- hopscotch hashing
- cuckoo hashing

Discuss:
- CPU cache locality
- pointer chasing penalties
- SIMD opportunities

-----------------------------------
5. NETWORK STACK OPTIMIZATION
-----------------------------------

Deep dive into:
- epoll
- io_uring
- Netty
- Tokio
- libuv
- DPDK (optional)
- kernel bypass concepts

Explain:
- which networking architecture gives best throughput
- batching strategies
- backpressure handling
- connection handling
- request parsing efficiency

-----------------------------------
6. CACHE ARCHITECTURE OPTIONS
-----------------------------------

Compare these architectures:
A. Pure single-thread cache
B. Multi-thread shared memory cache
C. Sharded per-core cache
D. Actor-based cache
E. Redis-style architecture
F. LSM-style persistence hybrid
G. Shared-nothing architecture

For each:
- advantages
- disadvantages
- latency profile
- scalability ceiling
- implementation complexity
- ECS deployment suitability

-----------------------------------
7. ECS + LINUX OPTIMIZATION
-----------------------------------

Explain:
- CPU pinning
- NUMA awareness
- huge pages
- transparent huge pages
- cgroups impact
- ECS networking overhead
- container overhead
- ECS EC2 vs Fargate
- kernel tuning
- IRQ balancing
- SO_REUSEPORT
- TCP tuning

-----------------------------------
8. RECOMMENDED FINAL DESIGN
-----------------------------------

Based on all tradeoffs:
- propose the BEST architecture for ultra-low latency
- propose the BEST language/runtime
- propose thread model
- propose memory layout
- propose network stack
- propose concurrency strategy

Then provide:
- high-level architecture diagram (ASCII acceptable)
- request lifecycle
- read path
- write path
- eviction strategy
- persistence strategy (if needed)

-----------------------------------
9. IMPLEMENTATION ROADMAP
-----------------------------------

Provide a phased roadmap:
Phase 1:
- simplest benchmarkable MVP

Phase 2:
- low-contention concurrency

Phase 3:
- sharding

Phase 4:
- distributed scaling

Phase 5:
- advanced kernel/network optimization

-----------------------------------
10. BENCHMARKING + PROFILING
-----------------------------------

Explain:
- how to benchmark correctly
- p50/p95/p99 latency
- throughput metrics
- flamegraphs
- perf
- eBPF
- cache miss analysis
- lock contention analysis

-----------------------------------
IMPORTANT REQUIREMENTS
-----------------------------------

- Avoid generic textbook explanations
- Focus on real-world systems engineering
- Use Redis, DragonflyDB, Aerospike, Memcached, ScyllaDB, and NGINX as comparison references
- Explain tradeoffs deeply
- Include failure scenarios
- Include CPU-level considerations
- Include memory-level considerations
- Include kernel-level considerations
- Include practical implementation advice
- Include anti-patterns to avoid

The response should feel like guidance from a senior systems architect designing infrastructure for very high throughput systems.
