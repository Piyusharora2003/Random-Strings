# 02: Memory Layer - Context and State Management

## 1. Concept Overview

LLMs are inherently stateless. Each request to an LLM API starts with a blank slate, disconnected from the past. The **Memory Layer** is responsible for providing the necessary context to make the LLM appear intelligent, aware of the user, and informed about enterprise data. 

**What problem it solves:**
Without memory, an AI cannot hold a coherent multi-turn conversation, cannot remember user preferences (like a shipping address), and cannot answer questions about private company data that wasn't included in its training set.

**Why it exists in production:**
A production system must dynamically inject the *right* context at the *right* time. Simply stuffing the entire chat history and all company documents into a massive context window will result in extreme costs, high latency, and "lost in the middle" hallucination issues. The Memory Layer selectively retrieves relevant context.

---

## 2. Responsibilities of the Layer

The Memory Layer manages three distinct domains of state:

1. **Conversation Memory (Short-Term):** The immediate back-and-forth buffer of the current session.
2. **User Memory (Long-Term):** Extracted facts, preferences, and metadata tied to a persistent user ID.
3. **Knowledge Memory (RAG):** Enterprise data stores accessed via Retrieval-Augmented Generation (knowledge bases, product catalogs).

It must retrieve context rapidly and inject it into the prompt in a structured, token-optimized format.

---

## 3. Workflow Placement

The Memory Layer sits parallel to the Orchestrator. When the Orchestrator has an intent, it queries the Memory Layer to build the context payload before invoking the LLM.

```text
User Input → Intent Layer 
   ↓
[ Orchestrator Layer ] ◄───────► [ Memory Layer ]
   ↓                             │ 1. Fetch Chat History
   ↓                             │ 2. Fetch User Profile
   ↓                             │ 3. Execute Vector Search (RAG)
   ↓                             └───────────────────────────────
[ LLM Reasoning Layer ]
```

---

## 4. Internal Architecture

### The Three Pillars of Memory

1. **Conversation Memory Store:** Typically a fast, in-memory KV store (like Redis) tracking the `session_id`. It stores the recent N message turns.
2. **User Memory Graph / SQL DB:** A persistent database storing key-value pairs of extracted user preferences (e.g., `user_id: 123 -> preferred_language: Spanish`).
3. **Knowledge Memory (RAG Pipeline):**
   * **Ingestion:** Documents → Chunking → Embeddings → Vector DB.
   * **Retrieval:** User Query → Query Embedding → Vector Search → Re-ranking → Context Injection.

### Context Window Management
The Memory Layer runs algorithms to manage allowable context size. If the token limit is 8k, and RAG returns 6k, the Conversation memory must be truncated or summarized to fit within the remaining 2k, minus the safety buffer.

---

## 5. Implementation Approaches

### Simple Startup Version
All three types of memory are lumped into a single PostgreSQL database. Conversation history is sliced to the last 5 turns. RAG is done by passing the entire context blindly to the LLM.

### Scalable Production Version
Conversation memory is moved to Redis with a TTL of 24 hours. User memory is stored in a NoSQL DB (DynamoDB or MongoDB). Knowledge memory utilizes a dedicated Vector DB like Pinecone, with semantic chunking strategies replacing naive overlapping chunks.

### Enterprise Version
Context is dynamically compressed using dedicated fast SLMs. The RAG pipeline features hybrid search (BM25 lexical + dense vector search), followed by a Cross-Encoder Re-ranker (e.g., Cohere Rerank) to present only the top 3 most relevant snippets to the expensive generative model.

---

## 6. Example Implementation

```python
class MemoryLayer:
    def __init__(self, kv_store, user_db, vector_db):
        self.kv_store = kv_store
        self.user_db = user_db
        self.vector_db = vector_db

    def build_context(self, user_id, session_id, user_query):
        # 1. Conversation Memory
        chat_history = self.kv_store.get_recent_messages(session_id, limit=6)
        
        # 2. User Memory
        user_profile = self.user_db.get_preferences(user_id)
        
        # 3. Knowledge Memory (RAG)
        query_embedding = embed_text(user_query)
        rag_results = self.vector_db.search(query_embedding, top_k=3)
        reranked_docs = rerank(user_query, rag_results)
        
        # 4. Context Window Management
        final_context = optimize_tokens(
            history=chat_history,
            profile=user_profile,
            docs=reranked_docs,
            max_tokens=4000
        )
        return final_context
        
def optimize_tokens(history, profile, docs, max_tokens):
    # Pseudo-code for token budgeting
    return f"[USER_PROFILE]\n{profile}\n[DOCS]\n{docs}\n[HISTORY]\n{history}"
```

---

## 7. Technology Options

* **Conversation Memory:** Redis, Memcached, DynamoDB.
* **User Memory:** PostgreSQL, MongoDB, Neo4j (for complex graph relationships).
* **Knowledge Memory (RAG):**
  * Vector Stores: Pinecone, Qdrant, Weaviate, Milvus.
  * Embedding Models: OpenAI, Cohere, BGE.
  * Re-rankers: Cohere Rerank API, open-source Cross-Encoders.

**When to use each:** Use Redis for anything ephemeral (sessions). Use specialized Vector DBs only when corpus size exceeds 100k chunks; otherwise, `pgvector` in PostgreSQL is radically cheaper and simpler.

---

## 8. Scaling Considerations

* **At 1k Users:** Simple `pgvector` lookups and SQL row fetching work flawlessly.
* **At 10k Users:** Redis is mandatory for chat history to prevent database connection exhaustion. RAG indexing pipelined via message queues (Kafka/RabbitMQ) becomes necessary to handle document updates without blocking the main event loops.
* **At 100k Users:** The Vector DB becomes a massive cost center. You must implement semantic caching (caching exact vector search results for common queries) and deploy Read Replicas for the user database.

---

## 9. Failure Handling

* **Database Timeouts:** If the Redis instance holding conversation history goes down, the system should catch the timeout and gracefully degrade to a stateless response: *"I'm having trouble retrieving our past messages, could you clarify?"*
* **Empty RAG Results:** If the vector search returns results with sub-threshold similarity, the memory layer must *explicitly* return empty context. Passing irrelevant documents forces the LLM to hallucinate connections.

---

## 10. Cost Optimization

1. **Semantic Caching:** If 100 users ask "What is the return policy?", the vector search should only happen *once*. Subsequent queries hit a semantic cache.
2. **Summarization over Concatenation:** Periodically run a cheap SLM to summarize old chats and replace the verbose logs with a single paragraph of dense context.
3. **Tiered Embeddings:** Use cheap embeddings for initial wide net filtering, use more expensive Re-rankers only on the final 10 documents.
