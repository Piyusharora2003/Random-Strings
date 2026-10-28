**PII TOKENIZATION  
PROXY**

Enterprise system design guide

TypeScript / Node.js • Redis token vault • Multi-tenant platform

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr class="header">
<th><strong>Design thesis<br />
</strong>Build a policy-enforcing tokenization platform with a
reversible vault, not a string-replacement utility. The hard problems
are identity scope, authorization, atomic mapping creation, retention,
failure behavior, and preventing data leakage through logs and proxy
egress.</th>
</tr>
</thead>
<tbody>
</tbody>
</table>

Purpose: a substantial read-ahead document for architecture discussions,
implementation planning, and design reviews. It explains the core
concepts, alternatives, trade-offs, failure cases, and a phased path to
production.

Assumptions: enterprise multi-application service; Node.js with
TypeScript; Redis is the initial low-latency mapping store; some
workflows require reversible tokenization; downstream APIs and LLMs must
not receive original PII unless explicitly permitted.

# How to read this guide

Suggested reading order: sections 1–5 establish the model and
boundaries; sections 6–12 cover the data path and correctness; sections
13–18 cover reliability, security, and operations; sections 19–22 turn
the design into an implementation and review plan.

| **Section** | **Focus**                                                         |
|-------------|-------------------------------------------------------------------|
| 1–3         | Problem statement, terminology, goals and non-goals               |
| 4–7         | Architecture, request flows, API contracts, token semantics       |
| 8–11        | Redis schema, cryptography, concurrency, PII detection            |
| 12–16       | Proxy safety, authorization, reliability, scale and observability |
| 17–20       | Alternatives, testing, rollout, operational readiness             |
| 21–22       | Open questions, decisions, glossary and references                |

# Executive summary

The proposed service accepts sensitive data from trusted applications,
detects or identifies configured PII, substitutes opaque tokens, and
optionally forwards sanitized payloads to approved destinations.
Authorized callers may later resolve tokens. Tokenization and
de-tokenization are separate permissions.

- Use random opaque tokens by default; do not derive them from the PII.

- Store original values encrypted with authenticated encryption; keep
  keys outside Redis.

- Use a keyed HMAC lookup digest only where stable reuse is needed;
  scope it to tenant and purpose.

- Treat tenant identity as derived from authenticated credentials, not
  caller-controlled JSON.

- Make token creation atomic, and define idempotency separately from
  stable token reuse.

- Fail closed before external forwarding when sanitization cannot be
  completed safely.

- Do not claim the system makes data anonymous or automatically makes a
  deployment compliant.

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr class="header">
<th><strong>Recommended first production boundary<br />
</strong>Tokenization-only API first. Add the outbound proxy after token
semantics, authorization, vault recovery, and PII leakage tests are
mature.</th>
</tr>
</thead>
<tbody>
</tbody>
</table>

# 1. Problem statement and threat model

## 1.1 Problem

Multiple applications need to use customer data with systems that should
not see raw identifiers. A centralized service can enforce common
policy, make access auditable, and prevent each application from
implementing its own inconsistent masking logic.

## 1.2 Actors and trust boundaries

| **Actor / component**  | **Trust assumption**                                            | **Design consequence**                                  |
|------------------------|-----------------------------------------------------------------|---------------------------------------------------------|
| Client application     | Authenticated, but may be compromised or misconfigured          | Limit permissions per app; validate all payloads        |
| Tokenization API       | Trusted processing boundary                                     | Minimize raw-value lifetime in memory and logs          |
| Redis vault            | Sensitive infrastructure; not inherently trusted with plaintext | Encrypt values; restrict network and ACLs               |
| KMS / key service      | Separate cryptographic trust boundary                           | Keys are not stored beside ciphertext                   |
| Downstream provider    | May retain or inspect payloads                                  | Forward sanitized data only; use destination allowlists |
| Audit/logging stack    | Broadly accessible operational system                           | Metadata-only logs; no raw request bodies               |
| Platform administrator | Privileged but not universally authorized to resolve PII        | Separate operational administration from data access    |

## 1.3 Threats to design against

- Cross-tenant token lookup or de-tokenization.

- Guessing token IDs or enumerating low-entropy identifiers.

- Redis compromise, snapshot exposure, or backup leakage.

- PII leakage through logs, traces, exceptions, metrics labels, queues,
  and support dumps.

- SSRF or data exfiltration through arbitrary proxy destinations.

- Concurrent requests creating conflicting token mappings.

- Key loss, key rotation mistakes, accidental expiry, and restore
  failures.

- PII detector false negatives, malformed payloads, Unicode edge cases,
  and prompt-injection-like content that attempts to bypass detection.

- Denial of service from large bodies, deeply nested JSON, regex
  backtracking, expensive NLP, or slow downstream APIs.

## 1.4 Out of scope for the first release

- Perfect detection of every kind of PII in arbitrary documents.

- Guaranteeing anonymity against re-identification from context.

- A generic unrestricted HTTP forward proxy.

- Full data catalog, consent-management platform, or legal compliance
  automation.

- Cross-region active-active writes until consistency and key ownership
  are explicitly designed.

# 2. Core terminology and conceptual model

| **Term**             | **Meaning**                                                                                          |
|----------------------|------------------------------------------------------------------------------------------------------|
| PII                  | Information that identifies or can reasonably be linked to a person, directly or in combination.     |
| Token                | Opaque surrogate identifier substituted for a protected value.                                       |
| Token vault          | Protected mapping from token to encrypted original value and required metadata.                      |
| Detokenization       | Authorized resolution of a token to its original value.                                              |
| Scope                | Boundary within which stable token reuse is permitted, such as a workflow or analytics domain.       |
| Tenant               | Enterprise/customer security boundary.                                                               |
| Application identity | Authenticated workload or client calling the service.                                                |
| Lookup digest        | Keyed digest used to find an existing token without storing plaintext as an index.                   |
| Redaction            | Removal or replacement of information without an expectation of recovery.                            |
| Pseudonymization     | Replacing identifiers with pseudonyms while re-linking remains possible with additional information. |

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr class="header">
<th><strong>Key distinction<br />
</strong>A token is not encryption, and tokenization is not
automatically anonymization. If a protected mapping or auxiliary
information can reconnect the token to a person, the result remains
pseudonymous or otherwise sensitive depending on context.</th>
</tr>
</thead>
<tbody>
</tbody>
</table>

# 3. Goals, non-goals and requirements

## 3.1 Functional requirements

- Tokenize structured JSON and configured free-text fields.

- Support tenant/application-scoped policies and configurable PII types.

- Support authorized de-tokenization, including field-level
  restrictions.

- Reuse tokens for repeated values only within explicitly defined scope
  semantics.

- Offer batch operations to reduce round trips.

- Optionally forward sanitized requests to named, approved destinations.

- Support bounded retention, revocation/deletion workflows, and key
  version metadata.

- Produce security audit events without raw PII.

## 3.2 Non-functional requirements

| **Attribute** | **Requirement / design question**                                              |
|---------------|--------------------------------------------------------------------------------|
| Security      | Tenant isolation, least privilege, encrypted mappings, secure key lifecycle    |
| Correctness   | No wrong-value mapping under concurrent writes; no unauthorized resolution     |
| Availability  | Define service and vault SLOs; decide fail-closed behavior                     |
| Latency       | Set p95/p99 budgets by payload size and detection mode                         |
| Throughput    | Bound concurrency; batch Redis operations; load test realistic payloads        |
| Durability    | Decide whether Redis is authoritative or a cache over a durable vault          |
| Privacy       | Data minimization, retention, deletion, metadata-only telemetry                |
| Operability   | Metrics, alerts, backup/restore drills, key rotation, incident runbooks        |
| Portability   | Repository and KMS interfaces; avoid leaking vendor types through domain layer |

## 3.3 Questions that must be answered before production

- Which exact PII types are in scope, and for which data formats?

- Must tokens be stable across requests, applications, or business
  domains?

- What is the maximum mapping lifetime and required recovery point?

- Can any caller restore tokens, and under what purpose and approval?

- Is Redis the system of record or an ephemeral vault?

- What does the system do when detection confidence is low?

- Which destinations may receive tokenized payloads, and what response
  restoration is allowed?

- Are regional residency or tenant-specific key requirements applicable?

# 4. High-level architecture

> CONTROL PLANE  
> Tenant / App Registry Policy Registry Destination Registry  
> \| \| \|  
> +----------- signed/versioned config -----+  
> \|  
> CLIENTS -\> Gateway -\> AuthN/AuthZ -\> Request Limits -\> Policy
> Resolver  
> \|  
> +--------------+--------------+  
> \| \|  
> Structured detector Text detector  
> \| \|  
> +---------- PII spans --------+  
> \|  
> Tokenization engine  
> \|  
> Crypto / Key abstraction  
> \|  
> Token repository interface  
> \|  
> Redis vault / indexes  
> \|  
> Sanitized payload response  
> \|  
> (optional) proxy forward  
> \|  
> Approved external destination  
>   
> Side channels: metadata-only audit, metrics, traces, alerts

Keep the initial deployment modular rather than decomposing each box
into a microservice. Separate modules by security responsibility and
interface. Split deployments only when independent scaling, separate
trust boundaries, or ownership justify the extra operational complexity.

## 4.1 Data plane versus control plane

The data plane processes tokenization and de-tokenization requests. The
control plane manages tenants, application credentials, policies,
destination definitions, quotas, and administrative workflows. It can
initially be a separate module/API in the same codebase, but
administrative endpoints should have stronger authorization and should
not be exposed to ordinary client credentials.

## 4.2 Recommended modules

| **Module**      | **Responsibility**                                                             | **Must not do**                                   |
|-----------------|--------------------------------------------------------------------------------|---------------------------------------------------|
| AuthN/AuthZ     | Authenticate workload; evaluate tenant, operation, scope and field permissions | Trust tenantId from untrusted payload             |
| Policy resolver | Load versioned policy and allowed PII types/destinations                       | Let client self-authorize policy changes          |
| Detector        | Return candidate spans or structured paths with type/confidence                | Log entire input for debugging                    |
| Token service   | Normalize, resolve/create token, coordinate mapping workflow                   | Own HTTP concerns or hardcode Redis               |
| Crypto service  | Encrypt/decrypt mapping records and calculate keyed digests                    | Store key material in Redis                       |
| Repository      | Atomic read/create/expiry operations                                           | Expose plaintext values to unrelated modules      |
| Proxy forwarder | Send to allowlisted destination with limits and timeouts                       | Accept arbitrary URLs                             |
| Audit           | Record operation metadata and outcome                                          | Include tokens or PII as metric labels by default |

# 5. Request flows and sequence decisions

## 5.1 Tokenize request

1.  Gateway enforces TLS, body size, request timeout, and coarse rate
    limits.

2.  Authenticate the caller and derive tenant/application identity.

3.  Authorize operation, policy, scope, PII types, and requested
    retention.

4.  Validate content type and JSON shape; reject unsupported structures.

5.  Detect PII from explicit schema rules and approved recognizers.

6.  Normalize each value under a versioned type-specific rule.

7.  Compute scoped lookup digest if stable reuse is enabled.

8.  Find an existing mapping or generate a cryptographically random
    token.

9.  Encrypt mapping and atomically create token plus lookup index.

10. Replace all identified occurrences and return sanitized payload plus
    request ID.

11. Emit audit metadata and metrics without raw values.

## 5.2 De-tokenize request

12. Authenticate and authorize the specific detokenization operation.

13. Validate token format, batch size, tenant, scope, and permitted PII
    types.

14. Fetch mappings in batches; decrypt only after authorization
    succeeds.

15. Return per-token outcomes or fail the whole batch according to the
    contract.

16. Audit each operation at a safe granularity without storing restored
    values.

Avoid an endpoint that resolves arbitrary tokens solely because a caller
knows the token string. Token secrecy is not authorization.

## 5.3 Proxy-forwarding request

17. Resolve a destination alias from server-side configuration.

18. Apply policy to request fields and text before forwarding.

19. Reject or quarantine if sanitization fails, detection policy cannot
    run, or the vault is unavailable.

20. Use strict connect/read timeouts, bounded retries, response-size
    limits, and egress restrictions.

21. Sanitize response content only when response restoration is
    explicitly requested and authorized.

22. Return a minimized response and safe metadata; never forward raw
    upstream errors with request bodies.

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr class="header">
<th><strong>Retry rule<br />
</strong>Retrying a tokenize request can be made safe with scoped
idempotency and atomic create-or-get. Retrying a downstream POST may
repeat a business action; use downstream idempotency support or avoid
automatic retries for non-idempotent operations.</th>
</tr>
</thead>
<tbody>
</tbody>
</table>

# 6. Token semantics: identity, scope and stability

## 6.1 Random token (default)

Generate token IDs using a cryptographically secure random generator. A
token should not encode the PII, its type, tenant name, sequence number,
or a reversible representation. Include enough random entropy to make
guessing infeasible, and use a format that does not expose sensitive
metadata.

## 6.2 Stable reuse is a policy decision

If the same email appears twice, should it produce the same token? There
is no universal answer. Stable reuse improves deduplication and makes
joins possible, but increases linkability across records. Define the
scope explicitly.

| **Scope strategy**   | **Benefit**                       | **Risk / cost**                                     |
|----------------------|-----------------------------------|-----------------------------------------------------|
| Per occurrence       | Strong unlinkability              | Repeated mentions may be inconsistent; larger vault |
| Per request          | Consistent within one payload     | No automatic cross-request joins                    |
| Per workflow/session | Useful for a support conversation | Records in same workflow are linkable               |
| Per application      | Stable within one app             | App can correlate records over time                 |
| Per tenant           | Convenient enterprise-wide joins  | High linkability and larger breach impact           |
| Global               | Easy cross-customer deduplication | Usually avoid: severe cross-tenant correlation risk |

## 6.3 Idempotency versus token stability

Stable tokenization means a normalized value in a given scope maps to a
stable token. Request idempotency means repeating an operation with the
same idempotency key does not create duplicate logical effects.
Implement and test these separately.

## 6.4 Normalization

Normalization changes the equality definition. Email case-folding,
phone-number canonicalization, Unicode normalization, whitespace
handling, and identifier punctuation rules can all affect whether two
inputs map to the same token. Keep normalization type-specific, version
it, and avoid transformations that change business meaning.

- Never normalize all PII using one generic lowercase-and-trim function.

- Do not silently change a normalization version for existing lookup
  indexes.

- Treat normalization policy changes as migrations with compatibility
  tests.

# 7. API design and contracts

## 7.1 Endpoints

| **Method / route**   | **Purpose**                                                | **Authz boundary**                   |
|----------------------|------------------------------------------------------------|--------------------------------------|
| POST /v1/tokenize    | Tokenize structured or approved text input                 | tokenize + policy + scope            |
| POST /v1/detokenize  | Resolve a batch of tokens                                  | detokenize + type/field restrictions |
| POST /v1/proxy       | Tokenize, forward to named destination, optionally restore | proxy destination + response policy  |
| GET /v1/health/live  | Process liveness                                           | No sensitive details                 |
| GET /v1/health/ready | Dependency readiness                                       | No credentials or internals          |
| Admin routes         | Manage tenants, policies, apps and destinations            | Separate admin identity and audit    |

## 7.2 Example request

> POST /v1/tokenize  
> Authorization: Bearer \<workload-token\>  
> Idempotency-Key: 8b3d...  
> Content-Type: application/json  
>   
> {  
> "scope": "support-session-123",  
> "policy": "llm-safe",  
> "data": {  
> "customerName": "Rahul Sharma",  
> "email": "rahul@example.com",  
> "message": "Contact Rahul at rahul@example.com"  
> }  
> }

## 7.3 Example response

> {  
> "requestId": "req_01J...",  
> "policyVersion": 7,  
> "data": {  
> "customerName": "tok\_...",  
> "email": "tok\_...",  
> "message": "Contact tok\_... at tok\_..."  
> },  
> "summary": {  
> "tokenOccurrences": 3,  
> "uniqueTokens": 2  
> }  
> }

The counts should be defined precisely. Do not expose unnecessary token
metadata to callers; some clients may need only the transformed data and
request ID.

## 7.4 Contract decisions

- Use explicit API versioning and stable error codes.

- Define whether partial success is allowed for batches.

- Set maximum batch size, nesting depth, string length, and total
  request bytes.

- Do not echo the original request in validation errors.

- Use a correlation/request ID, but do not derive it from customer
  identifiers.

- Document token expiry and whether callers may rely on tokens surviving
  a process restart.

- Use structured validation (for example, Zod) and reject unknown
  dangerous options where appropriate.

## 7.5 Error model

| **Code category**    | **Example behavior**                                                       |
|----------------------|----------------------------------------------------------------------------|
| 400 / validation     | Malformed payload, unsupported type, invalid token syntax                  |
| 401 / authentication | Missing or invalid client identity                                         |
| 403 / authorization  | Operation, scope, PII type or destination not allowed                      |
| 409 / conflict       | Idempotency key reused with incompatible request                           |
| 413 / too large      | Body, batch, depth or string exceeds configured limit                      |
| 429 / rate limit     | Tenant or application quota exceeded                                       |
| 502 / upstream       | Approved destination failed; return sanitized error                        |
| 503 / dependency     | Vault or required detector unavailable; fail closed for forwarding         |
| 500 / internal       | Generic response plus safe request ID; details only in protected telemetry |

# 8. Redis vault and data modeling

## 8.1 Logical records

> Mapping record (encrypted value + non-sensitive metadata):  
> tenantId  
> tokenId  
> piiType  
> scopeId  
> ciphertext  
> nonce  
> authenticationTag  
> encryptionKeyVersion  
> normalizationVersion  
> createdAt  
> expiresAt  
>   
> Lookup index:  
> tenant + scope + piiType + HMAC(normalizedValue) -\> tokenId

Avoid plaintext PII in Redis keys, values, command traces, or keyspace
notifications. Tenant and scope identifiers should themselves be
non-sensitive opaque IDs.

## 8.2 Key design

> pii:v1:{tenantOpaqueId}:token:\<tokenId\>  
> pii:v1:{tenantOpaqueId}:lookup:\<scopeOpaqueId\>:\<type\>:\<digest\>  
> pii:v1:{tenantOpaqueId}:idem:\<applicationId\>:\<idempotencyKeyDigest\>

Redis Cluster hash tags control which keys share a hash slot. If an
atomic script must update mapping and lookup keys together, key
placement must support that script in your deployment topology. Design
this deliberately; do not assume a Lua script can atomically touch
arbitrary cluster keys.

## 8.3 Atomic create-or-get

A robust algorithm is: calculate a scoped lookup digest, check for an
existing mapping, generate a candidate token and encrypted record on
miss, then atomically claim the lookup key and create the mapping. If
another request wins the claim, read and return the winner's token.
Clean up or expire orphan records if a failure occurs between
operations.

> Conceptual pseudocode (not production-ready):  
>   
> digest = HMAC(lookupKeyVersion, tenant \|\| scope \|\| type \|\|
> normalizedValue)  
> existing = repository.findByDigest(digest)  
> if existing:  
> return existing.token  
>   
> candidateToken = randomToken()  
> encryptedRecord = encrypt(value, tokenContext)  
>   
> result = repository.createIfAbsentAtomically(  
> digest,  
> candidateToken,  
> encryptedRecord,  
> ttl  
> )  
>   
> if result.created:  
> return candidateToken  
> else:  
> return repository.resolveWinner(digest)

## 8.4 Expiration semantics

A lookup index must not outlive its mapping. Ideally, both share a
retention policy and atomic creation/expiry behavior. If a mapping
expires while an index remains, lookups can return a dead token. If an
index expires first, a duplicate token may be created. Decide whether
that is acceptable and reconcile stale indexes.

## 8.5 Redis deployment decisions

| **Decision** | **Trade-off / recommendation**                                                                       |
|--------------|------------------------------------------------------------------------------------------------------|
| Persistence  | Choose RDB, AOF, or both based on RPO, latency and recovery needs; test restores.                    |
| Replication  | Improves failover, but replication lag and acknowledged-write semantics matter.                      |
| Cluster      | Scales capacity, but atomic multi-key operations require slot-aware design.                          |
| TLS / ACL    | Use private networking, TLS and least-privilege ACLs.                                                |
| Eviction     | Avoid accidental eviction of authoritative mappings; monitor memory and choose policy intentionally. |
| Backups      | Encrypt, restrict access, define retention and test deletion implications.                           |
| TTL          | Useful for bounded lifetimes, not a complete data deletion guarantee.                                |
| Durability   | If Redis loss must never destroy mappings, use a durable authoritative store.                        |

## 8.6 Redis as source of truth versus cache

| **Model**                | **Pros**                                  | **Cons**                                               |
|--------------------------|-------------------------------------------|--------------------------------------------------------|
| Redis is authoritative   | Simple low-latency path                   | Persistence/recovery and operational risk are critical |
| Durable DB + Redis cache | Stronger durable record and recovery path | More moving parts, consistency and invalidation work   |
| Dedicated vault          | May provide purpose-built controls        | Cost, integration and vendor dependency                |

# 9. Cryptography and key management

## 9.1 Encryption

Use authenticated encryption such as AES-256-GCM or a vetted KMS
envelope-encryption design. Each encrypted record needs a unique nonce
for the chosen algorithm, authentication tag, ciphertext, and
key-version metadata. Reusing a GCM nonce with the same key can
catastrophically compromise security.

## 9.2 Envelope encryption

A common design encrypts data with a data-encryption key (DEK), then
protects the DEK with a key-encryption key (KEK) managed by KMS. This
avoids sending every plaintext PII value to a remote KMS for a separate
decrypt call if the architecture safely caches or batches key material.
The cache lifetime and process-memory exposure must be part of the
threat model.

## 9.3 Separate keys by purpose

- Encryption key: decrypts mapping values.

- Lookup HMAC key: derives stable lookup digests.

- Token-signing key, if any: separate from both; random tokens usually
  do not need signatures.

- Audit integrity key, if required: separate from application keys.

## 9.4 Rotation

Store key version with every mapping. New writes use the current key.
Old records remain decryptable using prior key versions until
re-encryption or expiry is complete. For lookup-key rotation, the
problem is harder: new digests differ, so a migration strategy is
required. Options include dual-read/dual-write windows, background
re-indexing, or accepting a new token generation boundary.

## 9.5 Crypto implementation rule

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr class="header">
<th><strong>Do not invent cryptography<br />
</strong>Use platform crypto primitives and established
KMS/envelope-encryption patterns. Have security specialists review nonce
handling, associated data, key rotation, secret distribution, and memory
exposure before production.</th>
</tr>
</thead>
<tbody>
</tbody>
</table>

# 10. PII detection and replacement

## 10.1 Detection strategy

| **Layer**                 | **Best for**                                   | **Limitations**                            |
|---------------------------|------------------------------------------------|--------------------------------------------|
| Schema-based              | Known fields such as email, phone, national ID | Needs maintained schemas                   |
| Pattern-based             | Emails, phone patterns, structured IDs         | False positives/negatives; context matters |
| NER / NLP                 | Names, addresses and entities in prose         | Latency, model errors, language coverage   |
| Custom rules              | Internal account and employee identifiers      | Operational maintenance                    |
| Human review / quarantine | High-impact ambiguous cases                    | Latency and workflow overhead              |

## 10.2 Structured JSON versus free text

Treat JSON paths and text spans as different abstractions. For
structured fields, policies should identify allowed paths and PII types.
For text, detectors return spans \[start,end), type, and confidence. Do
not try to apply text offsets to serialized JSON without a careful
mapping.

## 10.3 Overlapping spans

A text detector may identify a full postal address and also a street
name within it. Define precedence: for example, choose the longest valid
high-confidence span, then apply policy-specific rules. Replace spans
from right to left or build output from untouched segments to avoid
offset shifts.

## 10.4 Repeated references

If a person's name occurs several times in the same scope, the same
token may be used for every occurrence to preserve coherence. That is a
policy choice, not an automatic property of tokenization. A
per-occurrence token offers less linkability but can degrade downstream
meaning.

## 10.5 False-negative strategy

- Use schema allowlists for known structured fields.

- Keep a detector test corpus with realistic, synthetic examples and
  multilingual cases.

- Measure recall as well as precision; a high precision score alone can
  hide dangerous misses.

- Set policy-specific confidence thresholds and behavior for uncertain
  cases.

- Run adversarial tests for malformed Unicode, spacing, punctuation,
  encoded values and prompt-like instructions.

- Treat detector outage as a policy event; do not silently forward raw
  input.

## 10.6 LLM detector caution

An external LLM used to detect PII can itself become a disclosure
channel. Prefer local or contractually approved detection, and never
send the raw payload to an unapproved model to decide whether it is safe
to send the raw payload elsewhere.

# 11. Proxy forwarding and SSRF defense

## 11.1 Destination registry

Callers pass a logical destination alias such as 'support-llm'. The
server resolves it to a fixed host, allowed path set, authentication
method, request/response size limits, timeout, and restoration policy.
Do not accept arbitrary URLs, proxy settings, redirect targets, or
caller-provided credentials.

## 11.2 Required egress controls

- Allowlist hosts and ports; restrict private, loopback, link-local,
  metadata and internal network ranges.

- Disable redirects by default, or revalidate every redirect target
  before following it.

- Validate DNS resolution and protect against DNS rebinding.

- Strip hop-by-hop headers and never forward inbound Authorization or
  Cookie headers blindly.

- Use separate credentials per destination and rotate them through a
  secret manager.

- Set connection, response, and total timeouts; cap response size and
  decompression ratio.

- Enforce outbound network policy outside the application as defense in
  depth.

## 11.3 Response handling

A downstream response may echo tokens, return unexpected content types,
or contain new PII. Define whether response detection is required.
Restoration should be narrowly scoped: do not blindly replace every
token-shaped string in arbitrary output if a malicious or unrelated
value can collide with the token syntax.

## 11.4 Prompt injection is not the same as PII leakage

A downstream LLM may be instructed to reveal context or reconstruct
identity. Tokenization reduces direct exposure but cannot prevent all
inference from surrounding details. Minimize context sent, use
provider-side retention controls where available, and assess whether the
task can work with redacted rather than reversible tokens.

# 12. TypeScript / Node.js implementation choices

| **Choice**     | **Recommendation**                                     | **Reason / alternative**                                                                        |
|----------------|--------------------------------------------------------|-------------------------------------------------------------------------------------------------|
| HTTP framework | Fastify                                                | Good schema/plugin model and performance; Express is also viable if team familiarity dominates. |
| Validation     | Zod or JSON Schema                                     | Validate at boundaries; Fastify can use JSON Schema.                                            |
| Redis client   | Official node-redis or ioredis                         | Pick one based on cluster, scripting and team needs; wrap it behind repository interfaces.      |
| Crypto         | Node crypto + KMS SDK                                  | Use vetted primitives; do not implement algorithms manually.                                    |
| Logging        | Pino or structured logger                              | Redaction must be configured and tested; avoid request-body logging.                            |
| Metrics        | Prometheus-compatible instrumentation or cloud metrics | No raw PII/token values as labels.                                                              |
| Testing        | Vitest/Jest + integration tests                        | Test concurrency and real Redis semantics, not only mocks.                                      |
| Deployment     | Containers on managed compute                          | Horizontal scaling; health checks, graceful shutdown and resource limits.                       |

## 12.1 Suggested module layout

> src/  
> app.ts  
> config/  
> auth/  
> policy/  
> detection/  
> tokenization/  
> detokenization/  
> crypto/  
> repositories/  
> redis/  
> proxy/  
> destinations/  
> audit/  
> telemetry/  
> routes/  
> tests/

## 12.2 Domain interfaces

> type PiiType =  
> \| "EMAIL" \| "PHONE" \| "PERSON"  
> \| "ADDRESS" \| "ACCOUNT_ID";  
>   
> interface Detection {  
> type: PiiType;  
> confidence: number;  
> // Structured path or text span is modeled separately.  
> }  
>   
> interface TokenRepository {  
> findByToken(ctx: TenantContext, token: string):  
> Promise\<EncryptedMapping \| null\>;  
>   
> findByLookupDigest(ctx: TenantContext, digest: string):  
> Promise\<string \| null\>;  
>   
> createIfAbsent(input: CreateMappingInput):  
> Promise\<CreateMappingResult\>;  
> }  
>   
> interface TokenizationService {  
> tokenize(input: TokenizeInput, ctx: RequestContext):  
> Promise\<TokenizeOutput\>;  
>   
> detokenize(input: DetokenizeInput, ctx: RequestContext):  
> Promise\<DetokenizeOutput\>;  
> }

The exact interfaces should express the invariants: tenant context is
required, mapping creation has defined atomic semantics, and callers
cannot invoke decrypt without an authorization decision. Avoid making
raw plaintext mapping objects available to every module.

## 12.3 Concurrency and the Node.js event loop

Node.js handles many concurrent I/O operations well, but synchronous
CPU-heavy detection, large JSON transformations, or expensive regexes
can block the event loop. Use bounded concurrency and profile the
detector. If NLP inference is CPU-heavy, isolate it in worker threads or
a separate service. Avoid one unbounded promise per detected value.

## 12.4 Memory lifecycle

JavaScript strings cannot be reliably zeroized like carefully managed
byte buffers. Minimize copies and lifetime of raw PII, avoid long-lived
caches of plaintext, and never treat garbage collection as a security
erasure guarantee.

# 13. Authorization and tenant isolation

## 13.1 Identity model

Each request should resolve to a trusted tenant ID, application ID, and
permission set. Use OAuth 2.0 client credentials, workload identity,
mTLS, or an appropriate combination. Do not treat a tenant ID or role
supplied in JSON as proof of identity.

## 13.2 Permission matrix

| **Operation**   | **Typical permission** | **Additional constraint**                         |
|-----------------|------------------------|---------------------------------------------------|
| Tokenize        | pii:tokenize           | Allowed PII types, policy and scope               |
| Detokenize      | pii:detokenize         | Purpose, fields/types, tenant and scope           |
| Proxy           | pii:proxy              | Registered destination and outbound policy        |
| Manage policy   | pii:policy:write       | Administrative identity, audit and approval       |
| Rotate keys     | pii:key:manage         | Restricted operator role and controlled procedure |
| Delete mappings | pii:mapping:delete     | Retention/deletion policy and audit               |

## 13.3 Token enumeration

Return consistent errors for unknown and unauthorized tokens where
appropriate. Rate-limit lookup attempts, avoid revealing whether a token
exists across tenants, and audit suspicious enumeration patterns. Random
token entropy is necessary but not a substitute for authorization.

## 13.4 Break-glass access

If emergency restoration is needed, require a separate permission path,
time-bound approval where practical, a reason code, strong audit, and
alerting. Routine operational administrators should not automatically
receive plaintext access.

# 14. Reliability, consistency and failure behavior

| **Failure**                   | **Recommended behavior**                                                | **Why**                                         |
|-------------------------------|-------------------------------------------------------------------------|-------------------------------------------------|
| Redis unavailable             | Fail closed for tokenization and external forwarding                    | Cannot guarantee mapping or safe transformation |
| KMS unavailable               | Use only a reviewed bounded key cache if allowed; otherwise fail closed | Do not bypass encryption or return raw values   |
| Detector unavailable          | Reject or quarantine based on policy; never silently forward raw input  | Prevents safety boundary bypass                 |
| Downstream timeout            | Return sanitized upstream error; bounded retry only when safe           | Avoid duplicate business actions and leakage    |
| Partial batch failure         | Document all-or-nothing vs per-item outcomes                            | Prevents caller ambiguity                       |
| Process crash during creation | Atomic create-or-get and reconciliation                                 | Avoid conflicting token assignments             |
| Key rotation failure          | Keep old key versions available until migration/expiry                  | Avoid permanent loss of mappings                |
| Backup restore                | Reconcile mapping/index TTLs and verify key versions                    | Avoid stale or unresolvable tokens              |

## 14.1 Fail-open versus fail-closed

For a security boundary that protects data before external transmission,
fail closed is the default. A fail-open mode is defensible only for
explicitly approved low-risk operations, with documented risk acceptance
and observability. It must never silently turn a protected request into
a raw request.

## 14.2 Consistency model

Within a tenant/scope/type/value, stable tokenization generally needs a
single winning mapping. Redis atomic operations can coordinate writes
within supported key-slot boundaries. Multi-region active-active
behavior is harder: concurrent regions may independently create
different tokens. Choose one write authority per scope/tenant, or adopt
a globally coordinated durable store if global stable identity is
required.

## 14.3 SLO and recovery objectives

Define SLOs only after workload characterization. Set separate
objectives for API availability, vault availability, p95/p99 latency,
recovery point objective (RPO), recovery time objective (RTO), and
mapping durability. An API uptime metric alone is insufficient if
mappings are unavailable or unrecoverable.

# 15. Capacity planning and performance

## 15.1 Cost model

Approximate work per request depends on payload bytes, detector passes,
number of unique values, mapping hits/misses, encryption operations,
Redis round trips, and downstream latency. Measure these components
separately before selecting instance sizes.

> Tokenize latency budget (conceptual):  
> T = auth + validation + detection + normalization  
> + vault lookup/create + transformation + serialization  
>   
> Proxy latency:  
> T_proxy = T_tokenize + upstream network/service  
> + optional response processing/restoration

## 15.2 Redis round trips

- Batch independent token lookups and mapping reads.

- Use pipelining where operations are independent; do not confuse
  pipelining with atomicity.

- Use a Lua script or transaction/conditional operation for invariants
  requiring atomic updates.

- Avoid one Redis request per repeated occurrence; deduplicate candidate
  values per request first.

- Do not cache decrypted PII in a general application cache by default.

## 15.3 Load-test scenarios

| **Scenario**                             | **What it tests**                              |
|------------------------------------------|------------------------------------------------|
| Small structured payload, all cache hits | Best-case overhead                             |
| Many unique emails / phones              | Miss path, encryption and writes               |
| Large free-text payload                  | Detection CPU and memory                       |
| Concurrent same value/scope              | Atomic create-or-get correctness               |
| Hot tenant                               | Fairness, rate limits and hot-key effects      |
| Redis latency spike                      | Timeouts, queueing and backpressure            |
| Detector CPU saturation                  | Event-loop responsiveness and worker isolation |
| Slow upstream                            | Connection limits and cancellation             |
| Failover / restore                       | RPO, RTO, mapping/index consistency            |

## 15.4 Backpressure

Set concurrency limits per tenant and globally. Reject or queue only
within a bounded budget. Propagate cancellation when clients disconnect,
and make sure abandoned downstream calls do not continue indefinitely.
Monitor event-loop lag, active requests, connection pools, memory, and
queue depth.

# 16. Observability and audit

## 16.1 Metrics

- Request count and latency by operation and outcome.

- Detection duration and number of detections by PII type (aggregate
  only).

- Vault hit/miss/error rates and mapping-create conflicts.

- Crypto/KMS latency and errors.

- Per-tenant quota rejections and unusual lookup patterns.

- Downstream destination latency, timeout, and failure rate.

- Event-loop lag, memory, CPU, Redis connection health, and saturation.

## 16.2 Logging rules

- Never log raw request/response bodies by default.

- Do not place PII, tokens, lookup digests, or credentials in metric
  labels.

- Redact authorization headers, cookies, query strings, and exception
  context.

- Use a request ID for safe correlation.

- Test logger redaction with malicious payloads and thrown exceptions.

## 16.3 Audit event schema

> {  
> "eventId": "evt\_...",  
> "timestamp": "ISO-8601",  
> "tenantId": "tenant_opaque",  
> "applicationId": "app_opaque",  
> "operation": "detokenize",  
> "policyVersion": 7,  
> "outcome": "denied",  
> "reasonCode": "FIELD_NOT_ALLOWED",  
> "requestId": "req\_...",  
> "latencyMs": 12  
> }

Audit events should not include the original value or, unless strictly
necessary, the token itself. Decide how to protect audit integrity,
access, retention, and export.

# 17. Architecture alternatives and trade-offs

| **Option**                      | **Advantages**                                                 | **Costs / risks**                                           | **Choose when**                            |
|---------------------------------|----------------------------------------------------------------|-------------------------------------------------------------|--------------------------------------------|
| Custom Node.js + Redis vault    | Full control; low-latency; flexible policies                   | You own crypto integration, durability, recovery and audits | MVP or specialized enterprise policy layer |
| Node.js proxy + dedicated vault | Purpose-built vault controls; separates mapping trust boundary | Vendor cost, latency, integration dependency                | Sensitive or regulated workloads           |
| Managed cloud components        | Managed identity, KMS, compute and durable storage             | Cloud coupling, cost, distributed components                | Enterprise already standardized on a cloud |
| Redaction-only service          | No reversible vault; simpler lifecycle                         | Original identity cannot be restored                        | Downstream task does not need identity     |
| Deterministic HMAC pseudonyms   | Stable joins without direct plaintext index                    | Linkability; key rotation and migration complexity          | Approved analytics/deduplication           |
| Client-side tokenization        | Raw PII may never enter central proxy                          | Harder policy consistency and key distribution              | Strong data-locality requirement           |

## 17.1 Redis versus PostgreSQL

Redis is strong for low-latency lookup and TTL-oriented access.
PostgreSQL provides durable relational records, transactions,
constraints, and operational queryability. A PostgreSQL-only vault may
be perfectly adequate at moderate throughput and can simplify
authoritative consistency. Redis is not automatically the best choice
simply because the workload is an API.

## 17.2 Monolith versus microservices

Start with a modular monolith: one deployable Node.js service with
strict module boundaries. Splitting detector, vault adapter, policy
service, and proxy into independent services increases network hops,
deployment complexity, failure modes, and identity propagation
requirements. Split only when isolation, scale, or ownership provides
measurable value.

## 17.3 Synchronous versus asynchronous

Most small and medium tokenization calls should be synchronous. Use
asynchronous processing for large files, bulk migrations, backfills, or
expensive NLP. Asynchronous flows need job IDs, bounded queues, status
APIs, retries, idempotency, and a policy for where raw payloads are
temporarily stored.

## 17.4 Vault-based versus deterministic token

Vault-based random tokens are easiest to reason about for reversible
tokenization. Deterministic pseudonyms can be useful when a consumer
needs equality joins, but they leak equality and can become cross-record
identifiers. Prefer explicit separate token domains over a universal
stable token.

# 18. Testing strategy

## 18.1 Unit tests

- Normalization by PII type and version.

- Detector span ordering and overlap resolution.

- Text replacement preserving non-PII text and Unicode.

- Crypto round trip, wrong-key rejection, tamper detection and nonce
  uniqueness.

- Policy authorization for tenant, app, scope, field and operation.

- Error response redaction.

## 18.2 Integration and concurrency tests

- Real Redis integration tests for TTL, Lua scripts, cluster slot
  assumptions, and atomic creation.

- Many concurrent requests for the same value and scope return the same
  token when policy requires it.

- Same input across tenants produces isolated mappings and cannot be
  cross-resolved.

- Expired mapping and stale index cases are handled safely.

- Redis restart/failover and backup restore preserve the declared
  durability guarantee.

- Key rotation and dual-read migrations work across old/new mapping
  versions.

## 18.3 Security tests

- Tenant A attempts to resolve tenant B's token.

- Caller has tokenize permission but attempts detokenization.

- Caller supplies an unauthorized policy or arbitrary destination URL.

- SSRF attempts target localhost, cloud metadata, private IPs and
  redirects.

- Large/deep JSON, oversized batches, regex worst cases and
  slowloris-style requests.

- Logs and traces are inspected for raw PII, tokens and credentials.

- Malformed tokens and lookup floods do not leak mapping existence or
  exhaust resources.

## 18.4 Detector quality

Build a synthetic corpus with labeled spans and expected output. Measure
precision, recall, false-negative rate by PII type and language, and
transformation correctness. Synthetic data is safer for tests and
reproducible load generation than production customer records.

# 19. Deployment and operations

## 19.1 Deployment baseline

- Run multiple stateless API instances behind a load balancer.

- Keep Redis private and restrict connections to service identities.

- Store KMS and destination credentials in a managed secret system.

- Set CPU/memory requests and limits; use graceful shutdown.

- Use liveness and readiness checks that do not leak internal details.

- Pin dependencies, scan images, produce an SBOM, and patch runtime
  dependencies.

- Use infrastructure-as-code for network policy, Redis, KMS, roles and
  alerting.

## 19.2 Rollout

23. Start in non-production with synthetic data and no downstream
    forwarding.

24. Run detection in shadow mode against synthetic or approved test
    data; compare expected detections.

25. Enable tokenization for one low-risk application and a small set of
    PII types.

26. Validate access controls, audit, retention and restore drills.

27. Enable a single allowlisted destination with forwarding disabled by
    default elsewhere.

28. Expand by tenant and policy version; keep a fast disable switch for
    forwarding.

## 19.3 Incident runbooks

| **Incident**             | **First response**                                                                                           |
|--------------------------|--------------------------------------------------------------------------------------------------------------|
| Suspected vault exposure | Restrict network/credentials, preserve evidence, assess snapshots/backups, rotate access and keys as advised |
| Cross-tenant access bug  | Disable affected endpoint, preserve audit, investigate all reads, notify incident/security leads             |
| KMS outage               | Follow approved cached-key policy or fail closed; do not disable encryption                                  |
| Detector regression      | Disable affected policy or forwarding, roll back detector/model version                                      |
| Mapping loss             | Stop operations that assume recoverability; restore and reconcile under controlled procedure                 |
| Unexpected egress        | Disable destination, block network path, inspect sanitized audit metadata and outbound logs                  |

# 20. Implementation plan and deliverables

| **Phase**                | **Deliverables**                                                                       | **Exit criteria**                                      |
|--------------------------|----------------------------------------------------------------------------------------|--------------------------------------------------------|
| 0\. Design               | Threat model, data classification, token scope semantics, SLO/RPO/RTO                  | Security and product decisions recorded                |
| 1\. Core                 | Auth, policy, random tokens, crypto abstraction, Redis repository, tokenize/detokenize | Unit/integration tests and tenant isolation tests pass |
| 2\. Safety               | PII detector, schema policy, audit, quotas, idempotency                                | False-negative evaluation and abuse tests reviewed     |
| 3\. Proxy                | Destination registry, egress controls, timeout and response handling                   | SSRF suite and failure-path tests pass                 |
| 4\. Production hardening | HA, backup/restore, rotation, dashboards, alerts, runbooks                             | Recovery drill and security review completed           |
| 5\. Expansion            | Additional PII types, NER, bulk workflows, dedicated vault evaluation                  | Measured benefit justifies added complexity            |

## 20.1 MVP acceptance checklist

- [ ] Every request has authenticated tenant and application context.

- [ ] Token IDs are random and do not encode PII.

- [ ] Mapping values are encrypted; keys are not stored in Redis.

- [ ] Stable lookup is scoped and uses a keyed digest.

- [ ] Concurrent create-or-get behavior is correct.

- [ ] De-tokenization requires separate authorization.

- [ ] Detector failures cannot trigger raw forwarding.

- [ ] Destination URLs are server-configured and allowlisted.

- [ ] Logs, traces, metrics and errors are tested for leakage.

- [ ] TTL, backup, restore and key rotation behavior is documented and
  tested.

- [ ] Rate limits and payload limits prevent trivial resource
  exhaustion.

# 21. Open design decisions to record

| **Decision**         | **Options**                                                | **Default recommendation**                                 |
|----------------------|------------------------------------------------------------|------------------------------------------------------------|
| Stable token scope   | Per request / workflow / app / tenant                      | Per workflow or application; avoid global                  |
| Vault authority      | Redis authoritative / durable DB + Redis / dedicated vault | Redis for prototype; prove durability before production    |
| PII detection        | Schema / patterns / NER / hybrid                           | Schema + patterns first; add NER only where needed         |
| Unknown detection    | Allow / reject / quarantine                                | Reject or quarantine for sensitive forwarding              |
| Proxy destination    | Arbitrary URL / registered alias                           | Registered alias only                                      |
| Response restoration | Always / never / policy-controlled                         | Never by default; explicit allowlist                       |
| Retention            | Fixed TTL / policy-specific / durable                      | Policy-specific and documented                             |
| Region strategy      | Single region / active-passive / active-active             | Single write authority initially                           |
| Batch semantics      | All-or-nothing / per-item                                  | Choose explicitly; all-or-nothing is simpler for core API  |
| Key rotation         | Re-encrypt / dual-read / expiry boundary                   | Versioned keys plus tested migration plan                  |
| Audit granularity    | Per request / per token / both                             | Per request by default; per-token events only if justified |

## 21.1 Decision record template

> ADR-XXX: \<decision title\>  
> Status: Proposed \| Accepted \| Superseded  
> Context:  
> Options considered:  
> Decision:  
> Why:  
> Security/privacy consequences:  
> Operational consequences:  
> Rollback/migration plan:  
> Owner and review date:

# 22. Glossary and reading list

| **Term** | **Short definition**                                                                     |
|----------|------------------------------------------------------------------------------------------|
| AAD      | Additional authenticated data: metadata authenticated with ciphertext but not encrypted. |
| AES-GCM  | Authenticated encryption mode; nonce uniqueness is critical.                             |
| HMAC     | Keyed message authentication code; used here for scoped lookup digests.                  |
| KMS      | Key management service.                                                                  |
| NER      | Named-entity recognition.                                                                |
| RPO      | Recovery point objective: acceptable data loss window.                                   |
| RTO      | Recovery time objective: acceptable recovery duration.                                   |
| SSRF     | Server-side request forgery.                                                             |
| TTL      | Time to live / expiry duration.                                                          |
| SLO      | Service-level objective.                                                                 |

## Recommended primary references

Use current vendor documentation and security guidance during
implementation; exact APIs and managed-service behavior can change.

- OWASP API Security Top 10 — authorization, resource consumption, SSRF
  and API inventory risks.

- OWASP Cryptographic Storage Cheat Sheet — encryption choices and
  key-management principles.

- OWASP Logging Cheat Sheet — event logging without leaking sensitive
  data.

- Redis Security documentation — network exposure, ACLs, TLS,
  persistence and operational hardening.

- Node.js crypto documentation — randomBytes, authenticated encryption
  and supported primitives.

- Fastify documentation — request validation, hooks, plugins and
  lifecycle.

- Your cloud provider's KMS and Redis-compatible service documentation —
  envelope encryption, IAM, failover, backup and restore.

- Applicable privacy/security standards and legal guidance for the
  jurisdictions and data categories in scope.

# Closing perspective

The proxy is a security product, not just an infrastructure wrapper. Its
correctness depends on explicit token identity semantics, authorization,
cryptographic key lifecycle, detector quality, and safe failure
behavior. Build the smallest system that preserves those invariants,
test failure paths before adding destinations, and treat reversibility
as a privileged capability.

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr class="header">
<th><strong>One-line design summary<br />
</strong>TypeScript modular service + strict workload identity +
policy-driven detection + random scoped tokens + encrypted vault
mappings + keyed lookup indexes + separately authorized restoration +
allowlisted proxy egress + metadata-only audit.</th>
</tr>
</thead>
<tbody>
</tbody>
</table>
