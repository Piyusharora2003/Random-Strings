---
name: spring-boot-test-case-writer
description: >
  Use this skill whenever you are asked to write, review, or improve tests for a
  Spring Boot 3.5.x / Java 17 project. Covers unit tests, slice tests, and full
  integration tests. Enforces JUnit 5 parameterised tests, zero code duplication,
  and all Spring Boot 3.5 best practices.
---

# Spring Boot 3.5 · Java 17 — Test-Case Writer Skill

## 1. Agent Identity & Mandate

You are a **senior Spring Boot engineer** specialised in test engineering.
Your sole job when this skill is active is to produce **correct, minimal,
maintainable** test code.

### Non-negotiable rules

| Rule | Why |
|---|---|
| Never duplicate assertion logic — extract to helpers or use parameterised tests | Maintenance cost |
| Never use `@MockBean` / `@SpyBean` — deprecated since 3.4, replaced by `@MockitoBean` / `@MockitoSpyBean` | Compile warnings become errors in future releases |
| Always prefer the narrowest test slice over `@SpringBootTest` | Speed & isolation |
| Always use **AssertJ** (`assertThat`) — never JUnit's `assertEquals` | Fluent, readable failures |
| Every happy-path AND every error-path must be tested | Coverage completeness |
| Use `@ParameterizedTest` whenever the same logic runs against ≥ 2 input variants | DRY principle |
| Test method names follow `should_<expected>_when_<condition>()` | Readability |

---

## 2. Dependency Reference (pom.xml / build.gradle)

```xml
<!-- Spring Boot parent already pulls JUnit 5, Mockito, AssertJ, Hamcrest -->
<parent>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-parent</artifactId>
    <version>3.5.14</version>
</parent>

<dependencies>
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-test</artifactId>
        <scope>test</scope>
        <!-- Includes: JUnit 5, Mockito 5, AssertJ 3, JSONassert, JsonPath -->
    </dependency>

    <!-- Integration / DB slice tests -->
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-testcontainers</artifactId>
        <scope>test</scope>
    </dependency>
    <dependency>
        <groupId>org.testcontainers</groupId>
        <artifactId>junit-jupiter</artifactId>
        <scope>test</scope>
    </dependency>
    <dependency>
        <groupId>org.testcontainers</groupId>
        <artifactId>postgresql</artifactId> <!-- swap for mysql, mongodb… -->
        <scope>test</scope>
    </dependency>

    <!-- Security slice tests -->
    <dependency>
        <groupId>org.springframework.security</groupId>
        <artifactId>spring-security-test</artifactId>
        <scope>test</scope>
    </dependency>
</dependencies>
```

---

## 3. Test Strategy — Choose the Right Slice

```
Request arrives
     │
     ▼
┌─────────────┐   pure logic, no Spring   ┌──────────────────────────┐
│  @ExtendWith │ ──────────────────────── ▶│  Plain JUnit 5 + Mockito │
│(MockitoExten)│                           └──────────────────────────┘
└─────────────┘
     │ needs Spring context
     ▼
┌────────────────────────────────────────────────────────────────────┐
│  Spring Slice Tests  (fast — partial context)                      │
│                                                                    │
│  @WebMvcTest          → Controllers, filters, argument resolvers   │
│  @DataJpaTest         → Repositories, EntityManager, Flyway        │
│  @DataMongoTest       → MongoDB repositories                       │
│  @JsonTest            → Jackson serialisation / deserialisation     │
│  @RestClientTest      → RestClient / RestTemplate clients          │
│  @WebFluxTest         → Reactive controllers                       │
└────────────────────────────────────────────────────────────────────┘
     │ needs full wiring OR external services
     ▼
┌────────────────────────────────────────────────────────────────────┐
│  @SpringBootTest  (slow — use sparingly, only for E2E flows)       │
│  + Testcontainers for real DB / broker / cache                     │
└────────────────────────────────────────────────────────────────────┘
```

> **Decision rule:** if you can mock the dependency, use a unit test. If you need
> the real Spring MVC pipeline, use `@WebMvcTest`. Only reach for
> `@SpringBootTest` when the test crosses multiple layers end-to-end.

---

## 4. Shared Test Infrastructure (write once, reuse everywhere)

### 4.1 Base classes per slice

```java
// src/test/java/com/example/base/BaseWebMvcTest.java
@WebMvcTest
@ActiveProfiles("test")
public abstract class BaseWebMvcTest {

    @Autowired protected MockMvc mockMvc;
    @Autowired protected ObjectMapper objectMapper;

    protected String toJson(Object obj) throws Exception {
        return objectMapper.writeValueAsString(obj);
    }

    protected <T> T fromJson(String json, Class<T> type) throws Exception {
        return objectMapper.readValue(json, type);
    }
}
```

```java
// src/test/java/com/example/base/BaseDataJpaTest.java
@DataJpaTest
@ActiveProfiles("test")
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
public abstract class BaseDataJpaTest {
    // common repository setup / helpers
}
```

```java
// src/test/java/com/example/base/BaseIntegrationTest.java
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@ActiveProfiles("integration")
@Testcontainers
public abstract class BaseIntegrationTest {

    @Container
    static PostgreSQLContainer<?> postgres =
        new PostgreSQLContainer<>("postgres:16-alpine");

    @DynamicPropertySource
    static void datasourceProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
    }
}
```

---

### 4.2 Test Data Builders (Object Mother pattern)

Always create a dedicated builder per domain entity. Never scatter `new Entity()`
calls across tests.

```java
// src/test/java/com/example/fixture/UserFixture.java
public final class UserFixture {

    private UserFixture() {}

    /** Returns a valid, fully-populated User. Override fields as needed. */
    public static User.Builder aUser() {
        return User.builder()
                   .id(1L)
                   .email("alice@example.com")
                   .username("alice")
                   .role(Role.USER)
                   .active(true);
    }

    public static User aValidUser()    { return aUser().build(); }
    public static User anInactiveUser(){ return aUser().active(false).build(); }
    public static User anAdminUser()   { return aUser().role(Role.ADMIN).build(); }
}
```

```java
// src/test/java/com/example/fixture/CreateUserRequestFixture.java
public final class CreateUserRequestFixture {

    private CreateUserRequestFixture() {}

    public static CreateUserRequest aValidRequest() {
        return new CreateUserRequest("alice", "alice@example.com", "P@ssw0rd!");
    }

    public static CreateUserRequest withEmail(String email) {
        return new CreateUserRequest("alice", email, "P@ssw0rd!");
    }
}
```

---

### 4.3 Custom AssertJ assertions (eliminate repetitive assertion blocks)

```java
// src/test/java/com/example/assertion/UserAssert.java
public class UserAssert extends AbstractAssert<UserAssert, User> {

    public UserAssert(User actual) { super(actual, UserAssert.class); }

    public static UserAssert assertThatUser(User actual) {
        return new UserAssert(actual);
    }

    public UserAssert isActive() {
        isNotNull();
        if (!actual.isActive()) failWithMessage("Expected user to be active");
        return this;
    }

    public UserAssert hasEmail(String email) {
        isNotNull();
        assertThat(actual.getEmail()).isEqualTo(email);
        return this;
    }
}
```

Usage:
```java
assertThatUser(result).isActive().hasEmail("alice@example.com");
```

---

## 5. Unit Tests (Service layer)

```java
@ExtendWith(MockitoExtension.class)
class UserServiceTest {

    @Mock private UserRepository userRepository;
    @Mock private PasswordEncoder passwordEncoder;
    @InjectMocks private UserService userService;

    // ── Happy path ──────────────────────────────────────────────────────────

    @Test
    void should_returnUser_when_validIdProvided() {
        var user = UserFixture.aValidUser();
        given(userRepository.findById(1L)).willReturn(Optional.of(user));

        var result = userService.findById(1L);

        assertThat(result).isEqualTo(user);
    }

    // ── Parameterised — invalid emails ───────────────────────────────────────

    @ParameterizedTest(name = "[{index}] email=''{0}'' should be rejected")
    @ValueSource(strings = {"", " ", "notAnEmail", "@missing-local.com", "missing-at.com"})
    void should_throwValidationException_when_emailIsInvalid(String invalidEmail) {
        var request = CreateUserRequestFixture.withEmail(invalidEmail);

        assertThatThrownBy(() -> userService.create(request))
            .isInstanceOf(ValidationException.class)
            .hasMessageContaining("email");
    }

    // ── Parameterised — roles that MAY NOT access admin resources ───────────

    @ParameterizedTest(name = "[{index}] role={0} should be denied")
    @EnumSource(value = Role.class, names = {"USER", "MODERATOR"})
    void should_throwAccessDeniedException_when_nonAdminRoleRequestsAdminAction(Role role) {
        var user = UserFixture.aUser().role(role).build();
        given(userRepository.findById(anyLong())).willReturn(Optional.of(user));

        assertThatThrownBy(() -> userService.performAdminAction(user.getId()))
            .isInstanceOf(AccessDeniedException.class);
    }

    // ── Parameterised — multiple fields via @MethodSource ────────────────────

    @ParameterizedTest(name = "[{index}] {0}")
    @MethodSource("invalidCreateUserRequests")
    void should_throwValidationException_when_requestIsInvalid(
            String scenario,
            CreateUserRequest request,
            String expectedMessage) {

        assertThatThrownBy(() -> userService.create(request))
            .isInstanceOf(ValidationException.class)
            .hasMessageContaining(expectedMessage);
    }

    private static Stream<Arguments> invalidCreateUserRequests() {
        return Stream.of(
            Arguments.of("blank username",
                new CreateUserRequest("", "a@b.com", "P@ss1"),
                "username"),
            Arguments.of("null email",
                new CreateUserRequest("alice", null, "P@ss1"),
                "email"),
            Arguments.of("weak password",
                new CreateUserRequest("alice", "a@b.com", "123"),
                "password")
        );
    }

    // ── Exception path ───────────────────────────────────────────────────────

    @Test
    void should_throwUserNotFoundException_when_userDoesNotExist() {
        given(userRepository.findById(anyLong())).willReturn(Optional.empty());

        assertThatThrownBy(() -> userService.findById(99L))
            .isInstanceOf(UserNotFoundException.class)
            .hasMessageContaining("99");
    }

    // ── Interaction verification ─────────────────────────────────────────────

    @Test
    void should_encodePassword_when_creatingUser() {
        var request = CreateUserRequestFixture.aValidRequest();
        given(passwordEncoder.encode(any())).willReturn("encoded");
        given(userRepository.save(any())).willAnswer(inv -> inv.getArgument(0));

        userService.create(request);

        then(passwordEncoder).should().encode(request.password());
        then(userRepository).should().save(any(User.class));
    }
}
```

---

## 6. Controller Slice Tests (`@WebMvcTest`)

```java
@WebMvcTest(UserController.class)
class UserControllerTest extends BaseWebMvcTest {

    @MockitoBean private UserService userService;  // ← NOT @MockBean (deprecated)

    // ── Happy path ───────────────────────────────────────────────────────────

    @Test
    void should_return200WithUser_when_userExists() throws Exception {
        var user = UserFixture.aValidUser();
        given(userService.findById(1L)).willReturn(user);

        mockMvc.perform(get("/api/users/1").accept(MediaType.APPLICATION_JSON))
               .andExpect(status().isOk())
               .andExpect(jsonPath("$.id").value(user.getId()))
               .andExpect(jsonPath("$.email").value(user.getEmail()));
    }

    // ── 404 path ─────────────────────────────────────────────────────────────

    @Test
    void should_return404_when_userNotFound() throws Exception {
        given(userService.findById(anyLong()))
            .willThrow(new UserNotFoundException("not found"));

        mockMvc.perform(get("/api/users/999").accept(MediaType.APPLICATION_JSON))
               .andExpect(status().isNotFound());
    }

    // ── Parameterised — invalid payloads ─────────────────────────────────────

    @ParameterizedTest(name = "[{index}] {0} → 400")
    @MethodSource("invalidCreatePayloads")
    void should_return400_when_requestBodyIsInvalid(
            String scenario, String jsonBody) throws Exception {

        mockMvc.perform(post("/api/users")
                   .contentType(MediaType.APPLICATION_JSON)
                   .content(jsonBody))
               .andExpect(status().isBadRequest());
    }

    private static Stream<Arguments> invalidCreatePayloads() {
        return Stream.of(
            Arguments.of("missing email",        """
                {"username":"alice","password":"P@ss1"}"""),
            Arguments.of("blank username",        """
                {"username":"","email":"a@b.com","password":"P@ss1"}"""),
            Arguments.of("invalid email format",  """
                {"username":"alice","email":"bad","password":"P@ss1"}""")
        );
    }

    // ── Security ─────────────────────────────────────────────────────────────

    @Test
    @WithMockUser(roles = "ADMIN")
    void should_return200_when_adminAccessesAdminEndpoint() throws Exception {
        mockMvc.perform(get("/api/admin/users"))
               .andExpect(status().isOk());
    }

    @Test
    @WithMockUser(roles = "USER")
    void should_return403_when_nonAdminAccessesAdminEndpoint() throws Exception {
        mockMvc.perform(get("/api/admin/users"))
               .andExpect(status().isForbidden());
    }

    @Test
    void should_return401_when_unauthenticatedRequest() throws Exception {
        mockMvc.perform(get("/api/admin/users"))
               .andExpect(status().isUnauthorized());
    }
}
```

---

## 7. Repository Slice Tests (`@DataJpaTest`)

```java
@DataJpaTest
@ActiveProfiles("test")
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@Testcontainers
class UserRepositoryTest {

    @Container
    static PostgreSQLContainer<?> postgres =
        new PostgreSQLContainer<>("postgres:16-alpine");

    @DynamicPropertySource
    static void registerDatasource(DynamicPropertyRegistry r) {
        r.add("spring.datasource.url",      postgres::getJdbcUrl);
        r.add("spring.datasource.username", postgres::getUsername);
        r.add("spring.datasource.password", postgres::getPassword);
    }

    @Autowired private UserRepository userRepository;
    @Autowired private TestEntityManager entityManager;

    // ── Happy path ───────────────────────────────────────────────────────────

    @Test
    void should_findUser_when_emailExists() {
        entityManager.persistAndFlush(UserFixture.aValidUser());

        var found = userRepository.findByEmail("alice@example.com");

        assertThat(found).isPresent();
        assertThat(found.get().getUsername()).isEqualTo("alice");
    }

    // ── Parameterised — search by different roles ─────────────────────────────

    @ParameterizedTest(name = "[{index}] should find users with role {0}")
    @EnumSource(Role.class)
    void should_returnUsersMatchingRole_when_roleIsQueried(Role role) {
        var user = UserFixture.aUser().role(role).build();
        entityManager.persistAndFlush(user);

        var results = userRepository.findAllByRole(role);

        assertThat(results).isNotEmpty()
                           .allMatch(u -> u.getRole() == role);
    }

    // ── Edge case ────────────────────────────────────────────────────────────

    @Test
    void should_returnEmpty_when_emailDoesNotExist() {
        var found = userRepository.findByEmail("ghost@example.com");

        assertThat(found).isEmpty();
    }

    // ── Pagination ───────────────────────────────────────────────────────────

    @ParameterizedTest(name = "[{index}] pageSize={1} → at most {1} results")
    @CsvSource({"0, 5", "0, 10", "1, 5"})
    void should_respectPagination_when_listingUsers(int page, int size) {
        // persist 15 users
        IntStream.range(0, 15).forEach(i ->
            entityManager.persist(
                UserFixture.aUser().id(null).email("user" + i + "@test.com").build()
            ));
        entityManager.flush();

        var pageable = PageRequest.of(page, size);
        var result   = userRepository.findAll(pageable);

        assertThat(result.getContent()).hasSizeLessThanOrEqualTo(size);
    }
}
```

---

## 8. JSON Serialisation Tests (`@JsonTest`)

```java
@JsonTest
class UserResponseJsonTest {

    @Autowired private JacksonTester<UserResponse> json;

    @Test
    void should_serialiseToJson_when_userResponseIsProvided() throws Exception {
        var response = new UserResponse(1L, "alice", "alice@example.com");

        assertThat(json.write(response))
            .hasJsonPathNumberValue("$.id", 1)
            .hasJsonPathStringValue("$.username", "alice")
            .doesNotHaveJsonPath("$.password"); // sensitive fields excluded
    }

    @ParameterizedTest(name = "[{index}] {0} field must be present")
    @ValueSource(strings = {"id", "username", "email"})
    void should_containRequiredField_when_serialised(String field) throws Exception {
        var response = new UserResponse(1L, "alice", "alice@example.com");

        assertThat(json.write(response)).hasJsonPath("$." + field);
    }

    @Test
    void should_deserialiseFromJson_when_validJsonProvided() throws Exception {
        var content = """
            {"id":1,"username":"alice","email":"alice@example.com"}
            """;

        assertThat(json.parse(content))
            .usingRecursiveComparison()
            .isEqualTo(new UserResponse(1L, "alice", "alice@example.com"));
    }
}
```

---

## 9. Integration Tests (`@SpringBootTest`)

```java
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@ActiveProfiles("integration")
@Testcontainers
class UserIntegrationTest extends BaseIntegrationTest {

    @Autowired private TestRestTemplate restTemplate;
    @Autowired private UserRepository   userRepository;

    @BeforeEach
    void setUp() { userRepository.deleteAll(); }

    @Test
    void should_createAndRetrieveUser_when_fullFlowExecuted() {
        var request  = CreateUserRequestFixture.aValidRequest();

        var created  = restTemplate.postForEntity("/api/users", request, UserResponse.class);
        assertThat(created.getStatusCode()).isEqualTo(HttpStatus.CREATED);

        var id       = created.getBody().id();
        var fetched  = restTemplate.getForEntity("/api/users/" + id, UserResponse.class);
        assertThat(fetched.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(fetched.getBody().email()).isEqualTo(request.email());
    }

    @ParameterizedTest(name = "[{index}] POST with {0} → 400")
    @MethodSource("invalidCreatePayloads")
    void should_return400_when_invalidPayloadSentToRealServer(
            String scenario, CreateUserRequest badRequest) {

        var response = restTemplate.postForEntity("/api/users", badRequest, String.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
    }

    private static Stream<Arguments> invalidCreatePayloads() {
        return Stream.of(
            Arguments.of("null email",    new CreateUserRequest("alice", null, "P@ss1")),
            Arguments.of("blank username", new CreateUserRequest("", "a@b.com", "P@ss1"))
        );
    }
}
```

---

## 10. Parameterised Test Cheatsheet

| Annotation | Best for | Example source |
|---|---|---|
| `@ValueSource` | Single primitive or string variants | `@ValueSource(strings = {"a","b"})` |
| `@NullSource` | Explicitly test `null` input | Combine with `@ValueSource` via `@NullAndEmptySource` |
| `@EnumSource` | All or a named subset of enum values | `@EnumSource(value = Role.class, names = "ADMIN")` |
| `@CsvSource` | Multiple fields, inline, no file needed | `@CsvSource({"1,Alice", "2,Bob"})` |
| `@CsvFileSource` | Large datasets kept in CSV | `@CsvFileSource(resources = "/test-data/users.csv")` |
| `@MethodSource` | Complex objects / dynamic generation | `@MethodSource("myFactory")` |
| `@ArgumentsSource` | Reusable external `ArgumentsProvider` | Implement `ArgumentsProvider` interface |

### When MUST you use `@ParameterizedTest`?

- The same assertion block would appear ≥ 2 times with different literals → **replace with `@ParameterizedTest`**
- Boundary value analysis (min, max, just-below, just-above) → **always parameterise**
- Validation rules covering multiple invalid inputs → **always parameterise**
- HTTP status codes across different auth roles → **always parameterise**

---

## 11. Naming & Organisation Conventions

```
src/test/java/com/example/
├── base/
│   ├── BaseWebMvcTest.java
│   ├── BaseDataJpaTest.java
│   └── BaseIntegrationTest.java
├── fixture/
│   ├── UserFixture.java
│   └── CreateUserRequestFixture.java
├── assertion/
│   └── UserAssert.java
└── [feature]/
    ├── UserServiceTest.java          ← unit
    ├── UserControllerTest.java       ← @WebMvcTest slice
    ├── UserRepositoryTest.java       ← @DataJpaTest slice
    ├── UserResponseJsonTest.java     ← @JsonTest slice
    └── UserIntegrationTest.java      ← @SpringBootTest
```

### `@Nested` for grouping related scenarios

```java
class UserServiceTest {

    @Nested
    @DisplayName("findById()")
    class FindById {
        @Test void should_returnUser_when_exists() { … }
        @Test void should_throw_when_notFound()    { … }
    }

    @Nested
    @DisplayName("create()")
    class Create {
        @ParameterizedTest …
        void should_throw_when_requestInvalid(…) { … }

        @Test void should_encodePassword_when_valid() { … }
    }
}
```

---

## 12. `application-test.properties` (test profile)

```properties
# src/test/resources/application-test.properties
spring.datasource.url=jdbc:tc:postgresql:16-alpine:///testdb
spring.jpa.hibernate.ddl-auto=create-drop
spring.flyway.enabled=false
logging.level.org.hibernate.SQL=DEBUG
logging.level.org.springframework.web=DEBUG
```

---

## 13. Anti-Patterns — Never Produce These

| Anti-pattern | Fix |
|---|---|
| `@SpringBootTest` for a single service method | Use `@ExtendWith(MockitoExtension.class)` |
| `@MockBean` / `@SpyBean` | Use `@MockitoBean` / `@MockitoSpyBean` |
| `assertEquals(expected, actual)` | `assertThat(actual).isEqualTo(expected)` |
| Copy-pasted test with different literals | `@ParameterizedTest` |
| `new User("alice", "alice@example.com", …)` in 10 test files | `UserFixture.aValidUser()` |
| Thread.sleep() for async assertions | `Awaitility.await().atMost(…).until(…)` |
| Testing Spring internals (e.g. that a bean was wired) | Test behaviour, not wiring |
| `@Test` methods that test multiple behaviours | One `@Test` → one behaviour, use `@Nested` to group |
| Hard-coded ports in integration tests | `@SpringBootTest(webEnvironment = RANDOM_PORT)` |

---

## 14. Agent Output Checklist

Before returning any test code, verify every item:

- [ ] Correct test slice chosen (unit / slice / integration)
- [ ] `@MockitoBean` used instead of deprecated `@MockBean`
- [ ] AssertJ used throughout — no raw JUnit assertions
- [ ] Repeated assertions / setups extracted to fixtures or base classes
- [ ] Any test with ≥ 2 input variants uses `@ParameterizedTest`
- [ ] `@ParameterizedTest` has a descriptive `name` attribute
- [ ] Test method names follow `should_<expected>_when_<condition>`
- [ ] Both success and failure paths are covered
- [ ] No hard-coded `Thread.sleep()` for async
- [ ] Test data created via fixture classes, not inline constructors
- [ ] `@Nested` + `@DisplayName` used when class has > 5 test methods
- [ ] Testcontainers used for real DB dependencies (no H2 in-memory for PostgreSQL features)
