# AI Search — Implementation Task Summary (v4)

Context: Angular + Spring Boot 3 + PostgreSQL admin portal. AI search mode already exists (textarea -> LLM resolve -> FilterDTO -> existing List API). This task adds: redesigned AI search UI, autocomplete suggestions backed by real query history, and a fire-and-forget confirm/error flow to track only genuinely successful searches.

Do not modify the existing List API contract or behavior. Do not modify the existing LLM resolver logic itself — only extend its response payload.

> **Changes from v3:** v3 split storage into an audit-trail table (`ai_search_query_log`) and a separate aggregate table (`ai_search_phrase`) to avoid double-counting and to let `llm_summary` rank independently. v4 merges these back into **one table** and does the "both `query_text` and `llm_summary` are searchable" aggregation at query time instead of maintaining a second table. It also adds a **tap-to-resolve** flow: clicking a suggestion calls `resolve-query` with `previousReqId`, which reuses the cached LLM response (no LLM call) and bumps that phrase's frequency immediately on tap.

---

## 1. Database

### Normalization rule (unchanged from v3)
`normalized(text) = LOWER(TRIM(text))` — nothing else. Used only for matching/dedup, never rewrites stored data.

### Single table: `ai_search_query_log`

```sql
CREATE TABLE ai_search_query_log (
    id BIGSERIAL PRIMARY KEY,
    req_id UUID NOT NULL UNIQUE,
    previous_req_id UUID REFERENCES ai_search_query_log(req_id),
    query_text VARCHAR(300) NOT NULL,
    llm_summary VARCHAR(300) NOT NULL,
    llm_response JSONB NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING', -- PENDING | CONFIRMED | ERROR
    search_count INT NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT now(),
    confirmed_at TIMESTAMP
);

COMMENT ON TABLE ai_search_query_log IS 'One row per resolve-query request. Doubles as the audit trail (status lifecycle) and the source of popularity data for suggestions (search_count), aggregated at read time across both query_text and llm_summary.';

COMMENT ON COLUMN ai_search_query_log.req_id IS 'Unique identifier for this specific resolve call. Returned to the frontend and used to confirm/mark-error this request.';
COMMENT ON COLUMN ai_search_query_log.previous_req_id IS 'NULL for an organic (typed) search. Set to the req_id of the suggestion that was tapped, when this request was triggered by clicking a suggestion chip rather than typing a fresh query. Rows with this set never independently accumulate search_count in suggestions — the tap already credited the original row (see confirm endpoint below); this column exists purely for audit/lineage.';
COMMENT ON COLUMN ai_search_query_log.query_text IS 'Raw natural language query exactly as typed/tapped, stored verbatim (not normalized).';
COMMENT ON COLUMN ai_search_query_log.llm_summary IS 'Normalized/cleaned version of the query as returned by the LLM resolver.';
COMMENT ON COLUMN ai_search_query_log.llm_response IS 'The resolver output for this request (what the frontend calls filterDTO), stored so a tap-to-resolve request can reuse it without re-invoking the LLM.';
COMMENT ON COLUMN ai_search_query_log.status IS 'PENDING (resolved, outcome not yet known), CONFIRMED (List API returned non-empty results), ERROR (resolve or list call failed). PENDING rows may persist indefinitely with no cleanup required.';
COMMENT ON COLUMN ai_search_query_log.search_count IS 'Number of times this row''s phrase (query_text or llm_summary) has been credited as a successful search. Incremented on confirm for organic rows, and incremented immediately at tap time on the ORIGIN row for tap-triggered rows (see confirm endpoint).';
COMMENT ON COLUMN ai_search_query_log.confirmed_at IS 'Timestamp of the most recent confirmation credited to this row. Used as a tiebreaker when ranking suggestions.';

CREATE INDEX idx_query_log_query_prefix ON ai_search_query_log (LOWER(TRIM(query_text)) text_pattern_ops);
COMMENT ON INDEX idx_query_log_query_prefix IS 'Speeds up prefix matching on normalized query_text for the suggestions endpoint.';

CREATE INDEX idx_query_log_summary_prefix ON ai_search_query_log (LOWER(TRIM(llm_summary)) text_pattern_ops);
COMMENT ON INDEX idx_query_log_summary_prefix IS 'Speeds up prefix matching on normalized llm_summary for the suggestions endpoint.';

CREATE INDEX idx_query_log_status ON ai_search_query_log (status);
COMMENT ON INDEX idx_query_log_status IS 'Speeds up filtering to CONFIRMED rows for suggestions, and PENDING rows for confirm/mark-error lookups.';
```

### Optional seed data
Insert rows directly with `status = 'CONFIRMED'`, `search_count = 1`, a synthetic `req_id`, and a plausible `llm_response`. Add `is_seed BOOLEAN DEFAULT FALSE` if you want to deprioritize them later (`ORDER BY is_seed ASC, search_count DESC`).

### No cleanup job
Unconfirmed `PENDING` rows are left in place; they're excluded from suggestions by the `status = 'CONFIRMED'` filter.

---

## 2. Backend — Spring Boot 3

### Modify: AI Resolve endpoint
`POST /api/search/resolve-query`

Request:
```json
{ "query": "find assets in us that are released", "previousReqId": null }
```

Behavior:
- **`previousReqId` absent/null** (organic search — user typed and submitted):
  1. Call the LLM resolver as today -> `llmResponse` (formerly `filterDTO`), `llmSummary`.
  2. Insert a `PENDING` row: new `req_id`, `previous_req_id = NULL`, `query_text` = raw input, `llm_summary`, `llm_response`.
  3. Return `{ reqId, llmResponse, llmSummary }`.

- **`previousReqId` present** (user tapped a suggestion chip):
  1. Look up the row where `req_id = previousReqId AND status = 'CONFIRMED'`.
     - **Not found / not CONFIRMED** (edge case — e.g. stale suggestion, row since changed): fall back to the organic flow above as if `previousReqId` were absent. Do not error.
  2. **Found:** skip the LLM call entirely — reuse that row's `llm_response` and `llm_summary` directly.
  3. Insert a new `PENDING` row: new `req_id`, `previous_req_id = previousReqId`, `query_text` = the tapped text, `llm_summary`/`llm_response` copied from the origin row.
  4. **Immediately** credit the origin row: `search_count = search_count + 1`, `confirmed_at = now()` on the row identified by `previousReqId` (it's already `CONFIRMED`, so its status doesn't change — only the count/timestamp do). This happens at tap time, independent of whether the List API call that follows succeeds.
  5. Return `{ reqId, llmResponse, llmSummary }` — same response shape either way, so the frontend doesn't need to branch.

  > Trade-off worth flagging: crediting on tap (rather than waiting for this request's own List API result) means a suggestion's count can grow even if the data has since changed and this particular tap returns empty results. That's the behavior you asked for — the suggestion was already proven historically, so tapping it counts immediately. If you'd rather stay conservative, the alternative is to skip step 4 and instead confirm-on-list-success like an organic row (still getting the LLM-call skip from step 2, just not the immediate credit) — happy to switch to that if you'd prefer.

### New: Confirm endpoint
`POST /api/search/confirm?reqId=<uuid>`

- Frontend calls this fire-and-forget after List API returns a **non-empty** result set.
- Logic: find row by `req_id` where `status = 'PENDING'`.
  - Not found / already terminal: no-op.
  - Found and `previous_req_id IS NULL` (organic): `status = 'CONFIRMED'`, `confirmed_at = now()`, `search_count = search_count + 1`.
  - Found and `previous_req_id IS NOT NULL` (tap-triggered): `status = 'CONFIRMED'`, `confirmed_at = now()`, **`search_count` left untouched** — it was already credited to the origin row at tap time; incrementing here too would double-count.
- Returns 204 regardless of outcome.

### New: Mark-error endpoint
`POST /api/search/mark-error?reqId=<uuid>`

- Unchanged from v3: find `PENDING` row by `req_id`, set `status = 'ERROR'`. No `search_count` changes ever (applies the same whether the row is organic or tap-triggered — a tap's own row failing doesn't undo the credit already given to the origin row).
- Returns 204 regardless of outcome.

### New: Suggestions endpoint — matching on both `query_text` and `llm_summary`
`GET /api/search/suggestions?q=<partial>`

This is the piece that needs the merged-table aggregation. Since a phrase's popularity is only tracked on whichever row(s) it appeared as `query_text` and/or `llm_summary`, and those can be different rows for the same normalized phrase, ranking has to sum across both fields and roll up by normalized text:

```sql
WITH combined AS (
    SELECT LOWER(TRIM(query_text)) AS norm,
           query_text              AS text,
           search_count            AS cnt,
           confirmed_at
    FROM ai_search_query_log
    WHERE status = 'CONFIRMED'
      AND previous_req_id IS NULL                          -- tap-triggered rows never carry their own count
      AND LOWER(TRIM(query_text)) LIKE LOWER(TRIM(:prefix)) || '%'

    UNION ALL

    SELECT LOWER(TRIM(llm_summary)) AS norm,
           llm_summary              AS text,
           search_count             AS cnt,
           confirmed_at
    FROM ai_search_query_log
    WHERE status = 'CONFIRMED'
      AND previous_req_id IS NULL
      AND LOWER(TRIM(llm_summary)) LIKE LOWER(TRIM(:prefix)) || '%'
      AND LOWER(TRIM(llm_summary)) <> LOWER(TRIM(query_text))   -- don't count the same row twice when its query_text and llm_summary are identical after normalization
),
agg AS (
    SELECT norm, SUM(cnt) AS total_count, MAX(confirmed_at) AS last_confirmed
    FROM combined
    GROUP BY norm
),
display AS (
    -- pick one representative casing per normalized group: highest-count row wins, most recent as tiebreaker
    SELECT DISTINCT ON (norm) norm, text
    FROM combined
    ORDER BY norm, cnt DESC, confirmed_at DESC
)
SELECT display.text, agg.total_count AS count
FROM agg
JOIN display USING (norm)
ORDER BY agg.total_count DESC, agg.last_confirmed DESC
LIMIT 5;
```

Response (unchanged shape):
```json
[
  { "text": "Find assets in production state", "count": 42 },
  { "text": "US Assets that are released", "count": 17 }
]
```

Why `previous_req_id IS NULL` in both branches: tap-triggered rows are duplicates of an existing phrase by construction (their text was copied from the origin row), so including them would double-count the same phrase alongside the origin row they were credited to.

**Scale note:** this UNION+GROUP BY runs at request time rather than reading a pre-aggregated table. For an admin-portal-scale `ai_search_query_log` (thousands–low millions of rows) with the two prefix indexes above, this is fine. If it ever shows up as slow, the fix is a materialized view refreshed periodically (`REFRESH MATERIALIZED VIEW CONCURRENTLY`) — not a schema change, so it can be deferred.

### List API
`POST /api/list` — **no changes**.

### New classes/files
```
controller/
  └── SearchConfirmController        (confirm + mark-error, or fold into existing AISearchController)
  └── SuggestionController

service/
  └── SearchQueryLogService          (insert on resolve — organic or tap; confirm; mark-error)
  └── SuggestionService              (runs the combined/agg/display query)

repository/
  └── AiSearchQueryLogRepository     (JPA repo + native query for suggestions)

entity/
  └── AiSearchQueryLog

dto/
  └── ResolveQueryRequest  (query, previousReqId?)
  └── ResolveQueryResponse (reqId, llmResponse, llmSummary)
  └── SuggestionDTO (text, count)
```

---

## 3. Frontend — Angular

### Request flow
1. **Organic search:** user types and submits -> `resolve-query({ query })` (no `previousReqId`) -> `{ reqId, llmResponse, llmSummary }` -> call `/api/list` with `llmResponse` as today.
2. **Suggestion tap:** user clicks a chip -> fill textarea with the chip's `text` -> `resolve-query({ query: text, previousReqId: <reqId of the suggestion the chip came from> })` -> same response shape -> call `/api/list` with `llmResponse` exactly as in the organic path. The frontend doesn't need to know or care that the LLM call was skipped server-side.
3. List API result handling — unchanged from v3: non-empty -> fire-and-forget `confirm(reqId)`; empty -> nothing; error -> fire-and-forget `markError(reqId)`.

This means the suggestions endpoint's response needs to carry each suggestion's own `reqId` (not just `text`/`count`) so the frontend has something to pass back as `previousReqId` on tap:

```json
[
  { "reqId": "b7e1...", "text": "Find assets in production state", "count": 42 },
  { "reqId": "9ac4...", "text": "US Assets that are released", "count": 17 }
]
```

That means the suggestions query needs to also surface a representative `req_id` per group — extend the `display` CTE above to select `req_id` alongside `text` (same `DISTINCT ON (norm) ... ORDER BY norm, cnt DESC, confirmed_at DESC` picks a consistent single row, so just add `req_id` to its SELECT list).

### New/modified files
```
services/
  ├── ai-search.service.ts     (resolveQuery(query, previousReqId?), confirmSearch(reqId), markError(reqId))
  └── suggestion.service.ts    (getSuggestions(prefix): Observable<SuggestionDTO[]>)

models/
  ├── resolve-query-request.ts    (query, previousReqId?)
  ├── resolve-query-response.ts   (reqId, llmResponse, llmSummary)
  └── suggestion.dto.ts           (reqId, text, count)

components/
  ├── ai-search.component        (textarea, debounce logic, calls suggestion + resolve + confirm/mark-error)
  └── suggestion-list.component  (renders chips; on click emits the chip's reqId + text)
```

---

## 4. Explicit non-goals for this task
- No changes to List API contract or internals.
- No changes to existing LLM prompt/resolver logic beyond returning `llmSummary` + `reqId`/`previousReqId` handling.
- No semantic/trigram similarity search — prefix match only, on top of lowercase+trim normalization.
- No per-user personalization of suggestions — global popularity only.
- No synchronous coupling between List API and analytics/counting.
- No scheduled cleanup job.
- No normalization beyond `LOWER(TRIM(...))`.

## 5. Acceptance criteria
- [ ] Single `ai_search_query_log` table created via migration, with column/index comments as specified.
- [ ] Organic resolve inserts a PENDING row with `previous_req_id = NULL` and calls the LLM as today.
- [ ] Tap resolve (`previousReqId` set, origin CONFIRMED) skips the LLM call, copies `llm_response`/`llm_summary`, inserts a PENDING row with `previous_req_id` set, and immediately increments `search_count` on the origin row.
- [ ] Tap resolve with a stale/missing/non-CONFIRMED `previousReqId` falls back to a full organic resolve without erroring.
- [ ] Confirm increments `search_count` only for organic PENDING rows; tap-triggered rows are marked CONFIRMED but don't double-increment.
- [ ] Mark-error never touches `search_count`, for either row type.
- [ ] Suggestions endpoint returns top 5 by combined `search_count` across `query_text` and `llm_summary`, correctly deduplicated by `LOWER(TRIM(...))`, excluding tap-triggered rows from the aggregation, each with a representative `reqId` for tap-to-resolve.
- [ ] Two confirmations of the same phrase differing only by case/whitespace roll into the same suggestion count.
- [ ] List API code untouched.
