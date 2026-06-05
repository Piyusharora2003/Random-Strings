# Spring Boot 3.5 · Java 17 — Test-Case Writer Agent Workflow

> **How to use:** paste this document alongside `spring-boot-test-skill.md` into
> the agent's system prompt. This file governs **execution order**; the skill
> file governs **code rules**. The agent must complete every phase gate before
> advancing. It must never skip a phase, even for "simple" classes.

---

## Workflow Overview

```
 SOURCE CODE IN
       │
       ▼
 ┌─────────────┐
 │  PHASE 0    │  Understand the source
 │  Analyse    │
 └──────┬──────┘
        │ Gate 0 passed
        ▼
 ┌─────────────┐
 │  PHASE 1    │  Build a test plan (no code yet)
 │  Plan       │
 └──────┬──────┘
        │ Gate 1 passed
        ▼
 ┌─────────────┐
 │  PHASE 2    │  Create shared infrastructure first
 │  Infra      │
 └──────┬──────┘
        │ Gate 2 passed
        ▼
 ┌─────────────┐
 │  PHASE 3    │  Generate tests layer by layer
 │  Generate   │
 └──────┬──────┘
        │ Gate 3 passed
        ▼
 ┌─────────────┐
 │  PHASE 4    │  Compilation safety review
 │  Compile    │
 └──────┬──────┘
        │ Gate 4 passed
        ▼
 ┌─────────────┐
 │  PHASE 5    │  Coverage mapping (≥ 90 %)
 │  Coverage   │
 └──────┬──────┘
        │ Gate 5 passed
        ▼
 ┌─────────────┐
 │  PHASE 6    │  Deduplication sweep
 │  DRY        │
 └──────┬──────┘
        │ Gate 6 passed
        ▼
 ┌─────────────┐
 │  PHASE 7    │  Final output & report
 │  Deliver    │
 └─────────────┘
```

---

## PHASE 0 — Source Code Analysis

**Input:** one or more source files (or file paths) provided by the user.

### Steps

**0-A — Inventory every element that needs testing**

For each class provided, build this table internally (no output yet):

| Element | Type | Visibility | Has branches? | Throws? | Returns? |
|---|---|---|---|---|---|
| `UserService.create()` | method | public | yes (if/else) | ValidationException | UserResponse |
| `UserService.findById()` | method | public | no | UserNotFoundException | User |
| … | … | … | … | … | … |

Rules:
- Include `public` and `package-private` methods.
- Skip `private` methods — they are covered transitively.
- Skip auto-generated equals/hashCode/toString unless custom logic exists.
- Skip `main()`.

**0-B — Identify the dependency graph**

List every collaborator (field injected or constructor injected):
```
UserService
  └── UserRepository        (Spring Data JPA)
  └── PasswordEncoder       (Spring Security)
  └── ApplicationEventPublisher
```

**0-C — Classify each class by test slice**

| Class | Slice required |
|---|---|
| `*Service`, `*Component`, `*Util` | Plain unit (`MockitoExtension`) |
| `*Controller`, `*RestController`, `*Advice` | `@WebMvcTest` |
| `*Repository` (custom queries) | `@DataJpaTest` + Testcontainers |
| `*Response`, `*Request`, `*Dto` with Jackson | `@JsonTest` |
| Cross-layer flow (e.g. full API call) | `@SpringBootTest` |

**0-D — Spot duplication risks before writing a single line**

Ask:
- Do multiple methods share the same invalid-input logic? → one `@ParameterizedTest`
- Do multiple controllers share authentication rules? → one parameterised security test
- Do multiple repository tests need the same entity fixtures? → one fixture class

### Gate 0 ✅

> Agent must be able to state: "I have identified **N** classes, **M** public
> methods, **K** dependency types, and **P** shared logic groups that will be
> parameterised."
> If any class is ambiguous, ask the user ONE clarifying question before
> proceeding.

---

## PHASE 1 — Test Plan (no code)

**Input:** Gate 0 output.
**Output:** a structured plan the agent shows to the user for confirmation.

### Steps

**1-A — Produce the Test Plan table**

Print this markdown table before writing any test code:

```
## Test Plan

| # | Class under test | Test class | Slice | Scenarios |
|---|---|---|---|---|
| 1 | UserService | UserServiceTest | Unit (Mockito) | create-valid, create-invalid×4(param), findById-found, findById-notFound, encodePassword |
| 2 | UserController | UserControllerTest | @WebMvcTest | GET-200, GET-404, POST-201, POST-400×3(param), auth-roles×3(param) |
| 3 | UserRepository | UserRepositoryTest | @DataJpaTest | findByEmail-found, findByEmail-empty, findAllByRole×N(param), pagination×3(param) |
| 4 | UserResponse | UserResponseJsonTest | @JsonTest | serialise-fields×3(param), deserialise-roundtrip |
| 5 | — | UserIntegrationTest | @SpringBootTest | full CRUD flow, invalid POST×2(param) |
```

**1-B — Identify shared infrastructure needed**

List every shared artifact that must be created in Phase 2:

```
Infrastructure to create:
  ☐ BaseWebMvcTest.java        (if ≥ 1 @WebMvcTest class)
  ☐ BaseDataJpaTest.java       (if ≥ 1 @DataJpaTest class)
  ☐ BaseIntegrationTest.java   (if ≥ 1 @SpringBootTest class)
  ☐ UserFixture.java           (if ≥ 2 test classes use User)
  ☐ CreateUserRequestFixture   (if ≥ 2 test classes use CreateUserRequest)
  ☐ UserAssert.java            (if ≥ 3 assertions repeat the same User fields)
  ☐ application-test.properties
```

**1-C — Mark every parameterisation point**

For each group of ≥ 2 scenarios that share the same assertion shape, label it:

```
Parameterisation points:
  P1 → invalid emails          (5 values)  → @ValueSource(strings=…)
  P2 → invalid request bodies  (3 objects) → @MethodSource
  P3 → roles denied admin      (2 enums)   → @EnumSource
  P4 → pagination combos       (3 rows)    → @CsvSource
  P5 → required JSON fields    (3 strings) → @ValueSource
```

**1-D — Estimate coverage**

For each class, list which branches will be hit:
```
UserService.create():
  ✔ username blank  → ValidationException        (P2)
  ✔ email null      → ValidationException        (P2)
  ✔ email invalid   → ValidationException        (P1)
  ✔ weak password   → ValidationException        (P2)
  ✔ valid request   → save + encode called
  → Estimated line coverage: ~95%
```

### Gate 1 ✅

> The plan must show ≥ 90 % estimated branch coverage for every class.
> Every scenario group with ≥ 2 variants must have a `P-label`.
> **Wait for user approval of the plan before proceeding to Phase 2.**
> If the user does not respond, proceed after stating "Proceeding with plan as shown."

---

## PHASE 2 — Infrastructure First

**Rule:** never write a test class before its required infrastructure exists.
**Order:** base classes → fixtures → custom assertions → properties.

### Steps

**2-A — Base test classes**

Generate only the base classes identified in 1-B.

Template rules:
```java
// Every base class must:
// 1. Be abstract
// 2. Carry the slice annotation (@WebMvcTest, @DataJpaTest, …)
// 3. Carry @ActiveProfiles("test")
// 4. Expose only what subclasses genuinely share (MockMvc, ObjectMapper, etc.)
// 5. Never contain test methods
```

**2-B — Fixture classes (Object Mother)**

For each domain object used in ≥ 2 test classes:

```java
// Fixture rules:
// 1. final class, private constructor
// 2. One aXxx() builder method returning a pre-filled builder
// 3. Named factory methods for every common variant (aValidUser, anAdminUser…)
// 4. Parameter overrides as static factory methods withXxx(value)
// 5. NEVER use random data (UUID.randomUUID, Math.random) — tests must be deterministic
```

**2-C — Custom AssertJ assertions**

Generate `XxxAssert extends AbstractAssert<XxxAssert, Xxx>` only when
the same multi-field assertion block appears ≥ 3 times across test classes.

**2-D — Test configuration**

```
src/test/resources/application-test.properties       ← unit + slice profile
src/test/resources/application-integration.properties ← @SpringBootTest profile
```

### Gate 2 ✅

> Every infrastructure file must compile standalone (no references to
> test-class-specific mocks). Mentally trace each import — if any is
> unresolvable, fix it now.

---

## PHASE 3 — Test Generation (layer by layer)

**Order:** Unit → Slice → Integration (never reverse).
Generate one complete file at a time; finish it before starting the next.

---

### 3-U — Unit Tests

For each `*Service` / `*Component` / `*Util`:

```
Step 3-U-1  Open the fixture for the class under test.
Step 3-U-2  Write the class shell:
              @ExtendWith(MockitoExtension.class)
              class XxxServiceTest { … }
Step 3-U-3  Declare @Mock fields (one per collaborator).
Step 3-U-4  Declare @InjectMocks field.
Step 3-U-5  For EACH public method:
              a) Write the happy-path @Test.
              b) Write each error-path @Test.
              c) IF ≥ 2 scenarios share the same assertion shape → convert
                 to @ParameterizedTest using the P-label from Phase 1.
              d) Write interaction-verification @Test (verify mock calls).
Step 3-U-6  Group methods with @Nested + @DisplayName when > 4 methods.
Step 3-U-7  Check: does any @Test body exceed 25 lines? If yes, extract
              a private helper or refactor with AssertJ soft assertions.
```

---

### 3-W — WebMvc Slice Tests

For each `*Controller`:

```
Step 3-W-1  Extend BaseWebMvcTest.
Step 3-W-2  Declare @MockitoBean for each service dependency.
             ⚠ NEVER use @MockBean — it is deprecated in Spring Boot 3.4+.
Step 3-W-3  For each endpoint:
              a) Happy-path: verify status + response body fields (jsonPath).
              b) 404 / 4xx paths.
              c) IF multiple invalid payloads → @ParameterizedTest + @MethodSource.
              d) Security: @WithMockUser(roles="ADMIN"), roles="USER", anonymous.
                 IF multiple roles → @EnumSource or @MethodSource.
Step 3-W-4  Never assert on full response body equality — assert on
              specific jsonPath fields to avoid brittleness.
```

---

### 3-D — DataJpa Slice Tests

For each `*Repository` that has custom query methods:

```
Step 3-D-1  Extend BaseDataJpaTest (which carries Testcontainers wiring).
Step 3-D-2  Inject @Autowired repository + TestEntityManager.
Step 3-D-3  @BeforeEach: call entityManager.flush() after persisting,
             use deleteAll() cautiously (only when test isolation requires it).
Step 3-D-4  For each custom query method:
              a) Persist the minimum data needed via fixtures.
              b) Test found + not-found + edge (empty table, boundary values).
              c) IF multiple similar queries or roles → @ParameterizedTest.
Step 3-D-5  Never test Spring Data's built-in methods (findById, save, etc.)
             — only test CUSTOM @Query / derived query logic.
```

---

### 3-J — JSON Slice Tests

For each DTO that has Jackson customisation (`@JsonProperty`, `@JsonIgnore`,
custom serialiser, date format):

```
Step 3-J-1  @JsonTest class (does NOT extend any base).
Step 3-J-2  @Autowired JacksonTester<XxxDto>.
Step 3-J-3  Test:
              a) All required fields present after serialise.
              b) Sensitive fields ABSENT (password, secret, token…).
              c) Field name aliases correct (camelCase ↔ snake_case).
              d) Date/time format matches API contract.
              e) Deserialise roundtrip.
              f) IF ≥ 2 fields to check presence → @ParameterizedTest @ValueSource.
```

---

### 3-I — Integration Tests

Write at most ONE integration test class per feature (e.g., `UserIntegrationTest`).

```
Step 3-I-1  Extend BaseIntegrationTest.
Step 3-I-2  Use @Autowired TestRestTemplate (or WebTestClient for reactive).
Step 3-I-3  @BeforeEach: clean the database via repository.deleteAll()
             to guarantee test isolation.
Step 3-I-4  Write ONLY cross-layer scenarios that CANNOT be tested in slices:
              - Full CRUD flow (create → read → update → delete).
              - Business transaction rollback.
              - Event publishing verified via @RecordApplicationEvents.
Step 3-I-5  IF multiple invalid payloads → @ParameterizedTest.
Step 3-I-6  Keep total integration test count low (aim < 10 per feature).
             Everything else belongs in slices.
```

### Gate 3 ✅

> Every generated test file must:
> - Reference only types that exist in the production code or infrastructure created in Phase 2.
> - Have zero copy-pasted assertion or setup blocks of > 3 lines.
> - Have every parameterisation point from Phase 1 implemented.

---

## PHASE 4 — Compilation Safety Review

The agent performs a **line-by-line compilation mental trace** on every
generated file before presenting the output.

### Checklist — run against EVERY test file

#### 4-A: Imports

```
For each type used in the file:
  ☐ Is it in java.lang?               → no import needed
  ☐ Is it from Spring Boot Test?      → org.springframework.boot.test.*
  ☐ Is it from JUnit Jupiter?         → org.junit.jupiter.api.*
                                         org.junit.jupiter.params.*
                                         org.junit.jupiter.params.provider.*
  ☐ Is it a Mockito type?             → org.mockito.* / org.mockito.junit.jupiter.*
  ☐ Is it AssertJ?                    → org.assertj.core.api.*
  ☐ Is it a Testcontainers type?      → org.testcontainers.*
  ☐ Is it a fixture / base class?     → com.example.fixture.* / com.example.base.*
  ☐ Is it a production class?         → verify package matches actual source
```

If any import is uncertain, add a comment `// TODO: verify package` — do not guess.

#### 4-B: Annotations

```
  ☐ @MockitoBean used (NOT @MockBean)
  ☐ @MockitoSpyBean used (NOT @SpyBean)
  ☐ @ExtendWith(MockitoExtension.class) on all plain unit tests
  ☐ @ParameterizedTest always paired with a source annotation
  ☐ @MethodSource value matches an existing static method name (exact spelling)
  ☐ @CsvSource row column count matches method parameter count
  ☐ @EnumSource value class matches the parameter type
  ☐ @Nested classes are non-static inner classes
  ☐ @DynamicPropertySource method is static
  ☐ @Container field is static
```

#### 4-C: Method signatures

```
  For every @MethodSource factory method:
    ☐ Is it private static?        → allowed in JUnit 5.10+
    ☐ Return type Stream<Arguments> or compatible?
    ☐ Arguments.of() column count matches test method param count?
    ☐ Types compatible (String, int, Class, not Object where typed expected)?

  For every @CsvSource test:
    ☐ Row string has correct comma-separated columns?
    ☐ Method parameter types match (String, int, long, boolean, Enum)?
    ☐ Enum parameter: add @ConvertWith or rely on implicit name conversion?
```

#### 4-D: Mock stubbing

```
  For every given(…).willReturn(…):
    ☐ Method being stubbed exists on the mocked interface/class?
    ☐ Return type of willReturn matches method's return type?
    ☐ willThrow exception type has a no-arg or message constructor?

  For every then(mock).should().method(…):
    ☐ Method exists?
    ☐ Argument matchers consistent? (no mix of raw values + matchers in same call)
```

#### 4-E: Assertions

```
  ☐ assertThat(actual) — actual is the real result, not the expected
  ☐ isEqualTo / isInstanceOf / hasMessage used correctly
  ☐ jsonPath("$.field") strings start with "$"
  ☐ status().isOk() / isCreated() etc. match HTTP semantics of the endpoint
  ☐ Custom AssertJ assert class compiled (extends AbstractAssert correctly)
```

### Gate 4 ✅

> Zero compilation issues found. If any item was marked `// TODO: verify package`,
> surface it to the user as a warning before delivering output.

---

## PHASE 5 — Coverage Mapping

The agent maps every branch in the source to the test that hits it.
This is a textual analysis — no tool required.

### Steps

**5-A — Branch coverage matrix**

For each class under test:

```
UserService.create(request)
  Branch                                  Covered by
  ─────────────────────────────────────── ──────────────────────────────────
  request == null                         should_throw_when_requestIsNull
  request.username() blank                P2 → should_throw_when_invalid[0]
  request.email() null                    P2 → should_throw_when_invalid[1]
  request.email() invalid format          P1 → should_throw_when_emailInvalid
  request.password() weak                 P2 → should_throw_when_invalid[2]
  email already exists (duplicate)        should_throw_when_emailAlreadyExists
  all valid → save called                 should_encodePassword_when_valid
  all valid → encode called               should_encodePassword_when_valid
  all valid → return mapped response      should_returnUser_when_validRequest
```

**5-B — Coverage calculation**

```
Total branches identified : N
Branches covered by tests  : M
Coverage %                 : M / N × 100

Target: ≥ 90 %
```

**5-C — Gap resolution**

If coverage < 90 %:
1. Identify uncovered branches.
2. Determine whether a new `@Test` or an extra row in an existing
   `@ParameterizedTest` is the right fix.
3. Prefer adding a row to an existing `@ParameterizedTest` over
   creating a new standalone `@Test` for the same method.
4. Add the missing case and re-run the matrix.

### Gate 5 ✅

> Coverage matrix shows ≥ 90 % for every class. Any class below 90 % blocks
> delivery until Gap Resolution is complete.

---

## PHASE 6 — Deduplication Sweep

Final pass before output. The agent reads all generated files together.

### Deduplication rules

**6-A — Identical setup blocks**

```
IF the same ≥ 3-line setup appears in ≥ 2 @Test methods within the same class:
  → Extract to a @BeforeEach setUp() method or a private helper.

IF the same setup appears across ≥ 2 test classes:
  → Move it to the relevant Base class or Fixture.
```

**6-B — Repeated fixture construction**

```
IF new XxxEntity(field1, field2, …) appears more than once:
  → Replace with XxxFixture.aValidXxx() or XxxFixture.aXxx().field(val).build()
```

**6-C — Repeated assertion chains**

```
IF assertThat(result.getX()).isEqualTo(…);
   assertThat(result.getY()).isEqualTo(…);
   assertThat(result.getZ()).isEqualTo(…);
appears ≥ 2 times:
  → Extract to XxxAssert.assertThatXxx(result).hasX(…).hasY(…).hasZ(…)
  → Or use assertThat(result).usingRecursiveComparison().isEqualTo(expected)
```

**6-D — Repeated @MethodSource factories**

```
IF two test classes define a static factory that returns the same data:
  → Move it to a shared TestDataProviders utility class in the fixture package.
```

**6-E — Repeated Testcontainers wiring**

```
IF @Container + @DynamicPropertySource appear in ≥ 2 test classes:
  → They must already be in BaseDataJpaTest / BaseIntegrationTest.
  → Remove from individual test classes.
```

**6-F — Test count sanity check**

```
IF a single test method body contains ≥ 2 unrelated assertions on different
   behaviours (e.g., checks both status AND database state AND event publishing):
  → Split into separate @Test methods.
  → Exception: AssertJ soft assertions (SoftAssertions) for related field checks.
```

### Gate 6 ✅

> No block of ≥ 3 lines is duplicated across any two files.
> No `new XxxEntity(…)` call appears more than once.
> No `@Container` / `@DynamicPropertySource` outside a base class.

---

## PHASE 7 — Final Delivery

### 7-A — Output format

Deliver files in this order:

```
1. Infrastructure files  (base classes, fixtures, assertions, properties)
2. Unit test files       (alphabetical by class name)
3. Slice test files      (@WebMvcTest, @DataJpaTest, @JsonTest)
4. Integration test files
5. Delivery report       (see 7-B)
```

Each file is presented as a complete, self-contained code block with
its full package declaration and all imports.

### 7-B — Delivery report

Append this summary after all code:

```markdown
## Test Delivery Report

### Files generated
| File | Type | Tests |
|---|---|---|
| UserServiceTest.java | Unit | 8 (3 parameterised) |
| UserControllerTest.java | @WebMvcTest | 7 (2 parameterised) |
| UserRepositoryTest.java | @DataJpaTest | 6 (2 parameterised) |
| UserResponseJsonTest.java | @JsonTest | 4 (1 parameterised) |
| UserIntegrationTest.java | @SpringBootTest | 3 (1 parameterised) |

### Coverage summary
| Class | Branches identified | Branches covered | % |
|---|---|---|---|
| UserService | 9 | 9 | 100 % |
| UserController | 7 | 7 | 100 % |
| UserRepository (custom queries) | 6 | 6 | 100 % |
| **Overall** | **22** | **22** | **100 %** |

### Parameterisation summary
| Point | Annotation | Variants |
|---|---|---|
| P1 – invalid emails | @ValueSource | 5 |
| P2 – invalid requests | @MethodSource | 3 |
| P3 – denied roles | @EnumSource | 2 |
| P4 – pagination | @CsvSource | 3 |
| P5 – JSON fields | @ValueSource | 3 |

### Shared infrastructure
- BaseWebMvcTest, BaseDataJpaTest, BaseIntegrationTest
- UserFixture, CreateUserRequestFixture
- UserAssert

### Compilation warnings
- None
  (or list any // TODO: verify package items)
```

### Gate 7 ✅ — Delivery complete

---

## Quick Reference — Decision Cards

```
┌────────────────────────────────────────────────────────────────┐
│ DUPLICATE DETECTED                                             │
│                                                                │
│ Same literals, different @Test?                                │
│   └─► @ParameterizedTest                                       │
│                                                                │
│ Same setup in multiple tests in the same class?                │
│   └─► @BeforeEach / private helper                             │
│                                                                │
│ Same setup across multiple test classes?                       │
│   └─► Base class or Fixture                                    │
│                                                                │
│ Same assertion chain > 2 times?                                │
│   └─► Custom AssertJ assert or recursiveComparison             │
│                                                                │
│ Same factory data in two files?                                │
│   └─► TestDataProviders utility class                          │
└────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────┐
│ COMPILATION ERROR PREVENTION                                   │
│                                                                │
│ @MockitoBean vs @MockBean?  → always @MockitoBean              │
│ @MethodSource name typo?    → copy-paste the method name       │
│ @CsvSource column mismatch? → count commas = params - 1        │
│ Missing import?             → trace each type to its artifact  │
│ Argument matcher mix?       → all matchers OR all raw values   │
│ @DynamicPropertySource?     → must be static                   │
│ @Container?                 → must be static                   │
└────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────┐
│ COVERAGE BELOW 90 %                                            │
│                                                                │
│ Missing branch is a variant of existing input?                 │
│   └─► Add row to existing @ParameterizedTest                   │
│                                                                │
│ Missing branch is a new scenario (different exception type)?   │
│   └─► New @Test                                                │
│                                                                │
│ Missing branch is only reachable via full stack?               │
│   └─► Add scenario to IntegrationTest, NOT a new slice test    │
└────────────────────────────────────────────────────────────────┘
```

---

## Forbidden Actions (agent must never do these)

```
✖ Write any test code before completing Phase 0 and Phase 1.
✖ Use @MockBean or @SpyBean (deprecated — use @MockitoBean / @MockitoSpyBean).
✖ Use H2 in-memory DB as a substitute for PostgreSQL-specific query tests.
✖ Use Thread.sleep() for async assertions (use Awaitility).
✖ Use assertEquals / assertTrue (use AssertJ assertThat).
✖ Skip the Gate check at the end of any phase.
✖ Write a test that tests Spring's own wiring (e.g., "@Autowired works").
✖ Write two @Test methods with identical bodies that differ only in a literal.
✖ Inline new Entity() constructor calls in test bodies — use fixtures.
✖ Use random/non-deterministic data (UUID.randomUUID, Math.random, LocalDate.now()).
✖ Assert on the full serialised JSON string — use jsonPath field-by-field.
✖ Produce a delivery report showing any class with < 90 % branch coverage.
```
