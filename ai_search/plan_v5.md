# AI Search — Implementation Task Summary (v5)

## 1. Database

### Normalization Rule

`normalized(text) = LOWER(TRIM(text))`

### Single Table: `ai_search_query_log`

```sql
CREATE TABLE ai_search_query_log (
    req_id UUID PRIMARY KEY,
    query_text VARCHAR(300) NOT NULL,
    llm_summary VARCHAR(300) NOT NULL,
    llm_response JSONB NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    search_count INT NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT now(),
    confirmed_at TIMESTAMP
);

CREATE INDEX idx_query_log_query_prefix ON ai_search_query_log (LOWER(TRIM(query_text)) text_pattern_ops);

CREATE INDEX idx_query_log_summary_prefix ON ai_search_query_log (LOWER(TRIM(llm_summary)) text_pattern_ops);

CREATE INDEX idx_query_log_status ON ai_search_query_log (status);

```

---

## 2. Backend — Spring Boot 3

### Resolve Endpoint (Organic Search)

`POST /api/search/resolve-query`

**Request:**

```json
{ "query": "find assets in us that are released" }

```

**Behavior:**

1. Call the LLM resolver.
2. Insert a `PENDING` row: `req_id`, `query_text` = raw input, `llm_summary`, `llm_response`.
3. Return `{ reqId, llmResponse, llmSummary }`.

### Resolve Endpoint (Tap-to-Resolve Cached Search)

`GET /api/search/resolve-query/{reqId}`

**Behavior:**

1. Look up the row where `req_id = {reqId}`.
2. Return `{ reqId, llmResponse, llmSummary }`.

### Confirm Endpoint

`POST /api/search/confirm?reqId=<uuid>`

**Behavior:**

1. Execute: `UPDATE ai_search_query_log SET status = 'CONFIRMED', search_count = search_count + 1, confirmed_at = now() WHERE req_id = :reqId AND status = 'PENDING'`
2. Return HTTP 204.

### Mark-Error Endpoint

`POST /api/search/mark-error?reqId=<uuid>`

**Behavior:**

1. Execute: `UPDATE ai_search_query_log SET status = 'ERROR' WHERE req_id = :reqId AND status = 'PENDING'`
2. Return HTTP 204.

### Suggestions Endpoint

`GET /api/search/suggestions?q=<partial>`

**Query:**

```sql
WITH combined AS (
    SELECT LOWER(TRIM(query_text)) AS norm,
           query_text              AS text,
           search_count            AS cnt,
           confirmed_at,
           req_id
    FROM ai_search_query_log
    WHERE status = 'CONFIRMED'
      AND LOWER(TRIM(query_text)) LIKE LOWER(TRIM(:prefix)) || '%'

    UNION ALL

    SELECT LOWER(TRIM(llm_summary)) AS norm,
           llm_summary              AS text,
           search_count             AS cnt,
           confirmed_at,
           req_id
    FROM ai_search_query_log
    WHERE status = 'CONFIRMED'
      AND LOWER(TRIM(llm_summary)) LIKE LOWER(TRIM(:prefix)) || '%'
      AND LOWER(TRIM(llm_summary)) <> LOWER(TRIM(query_text))
),
agg AS (
    SELECT norm, SUM(cnt) AS total_count, MAX(confirmed_at) AS last_confirmed
    FROM combined
    GROUP BY norm
),
display AS (
    SELECT DISTINCT ON (norm) norm, text, req_id
    FROM combined
    ORDER BY norm, cnt DESC, confirmed_at DESC
)
SELECT display.req_id AS "reqId", display.text, agg.total_count AS count
FROM agg
JOIN display USING (norm)
ORDER BY agg.total_count DESC, agg.last_confirmed DESC
LIMIT 5;

```

**Response:**

```json
[
  { "reqId": "b7e1-...", "text": "Find assets in production state", "count": 42 },
  { "reqId": "9ac4-...", "text": "US Assets that are released", "count": 17 }
]

```

---

## 3. Frontend — Angular

### Request Flow

1. **Organic Search:** User types and submits -> `POST /api/search/resolve-query` -> `{ reqId, llmResponse, llmSummary }` -> call `/api/list` with `llmResponse`.
2. **Suggestion Tap:** User clicks a chip -> `GET /api/search/resolve-query/{reqId}` -> `{ reqId, llmResponse, llmSummary }` -> call `/api/list` with `llmResponse`.
3. **List API Result Handling:**
* Non-empty -> `POST /api/search/confirm?reqId=<uuid>`
* Error -> `POST /api/search/mark-error?reqId=<uuid>`
