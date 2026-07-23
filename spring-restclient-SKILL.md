---
name: spring-restclient
description: Reference for using Spring's RestClient (Java 21 / Spring Boot 3.2+/4) to call HTTP APIs — GET/POST/PUT/PATCH/DELETE, multipart uploads, streaming, error handling with onStatus, and full configuration (connect/read timeouts, connection pooling, request factories, interceptors for logging/auth/retry, and application.yml properties). Use this whenever the user asks to create, configure, or debug a Java/Spring HTTP client, wants to call a REST API from a Spring Boot service, needs to add interceptors or timeouts to an HTTP client, or mentions RestClient, RestTemplate migration, or WebClient-vs-RestClient choices.
---

# Spring RestClient Reference

`RestClient` is Spring's modern **synchronous** HTTP client (Spring Framework 6.1 / Spring Boot 3.2+). It replaces `RestTemplate` for new code. This skill covers building it, every HTTP verb, configuration, and interceptors.

Use `WebClient` instead only if the app is reactive/non-blocking end-to-end. For plain servlet-based Spring Boot apps, `RestClient` is the default recommendation.

## 1. Creating a RestClient

Prefer injecting the Boot-autoconfigured builder over calling `RestClient.builder()` yourself — it inherits Boot's message converters, observability, and any `RestClientCustomizer` beans.

```java
@Configuration
public class RestClientConfig {

    @Bean
    RestClient restClient(RestClient.Builder builder) {
        return builder
                .baseUrl("https://api.example.com")
                .defaultHeader("Accept", "application/json")
                .build();
    }
}
```

Quick one-off client without DI: `RestClient.create("https://api.example.com")`.

## 2. All HTTP methods

Inject the built `RestClient` (constructor injection) into services and use the fluent API. Pattern: `method()` → `.uri()` → optional headers/body → `.retrieve()` → `.body(Type.class)`.

```java
@Service
public class UserClient {

    private final RestClient restClient;

    UserClient(RestClient restClient) {
        this.restClient = restClient;
    }

    // GET
    public User getUser(String id) {
        return restClient.get()
                .uri("/users/{id}", id)
                .retrieve()
                .body(User.class);
    }

    // GET a list
    public List<User> listUsers() {
        return restClient.get()
                .uri("/users")
                .retrieve()
                .body(new ParameterizedTypeReference<List<User>>() {});
    }

    // POST with a JSON body
    public User createUser(User newUser) {
        return restClient.post()
                .uri("/users")
                .contentType(MediaType.APPLICATION_JSON)
                .body(newUser)
                .retrieve()
                .body(User.class);
    }

    // PUT (full replace)
    public void updateUser(String id, User user) {
        restClient.put()
                .uri("/users/{id}", id)
                .contentType(MediaType.APPLICATION_JSON)
                .body(user)
                .retrieve()
                .toBodilessEntity();
    }

    // PATCH (partial update)
    public User patchUser(String id, Map<String, Object> fields) {
        return restClient.patch()
                .uri("/users/{id}", id)
                .contentType(MediaType.APPLICATION_JSON)
                .body(fields)
                .retrieve()
                .body(User.class);
    }

    // DELETE
    public void deleteUser(String id) {
        restClient.delete()
                .uri("/users/{id}", id)
                .retrieve()
                .toBodilessEntity();
    }

    // HEAD / OPTIONS
    public HttpHeaders headUser(String id) {
        return restClient.head()
                .uri("/users/{id}", id)
                .retrieve()
                .toBodilessEntity()
                .getHeaders();
    }

    // Arbitrary/custom method
    public String customMethod() {
        return restClient.method(HttpMethod.TRACE)
                .uri("/diagnostics")
                .retrieve()
                .body(String.class);
    }
}
```

Query params: `.uri(uriBuilder -> uriBuilder.path("/users").queryParam("active", true).build())`.

Custom headers per-request: `.header("X-Request-Id", id)` or `.headers(h -> h.setBearerAuth(token))`.

### Getting the full ResponseEntity (status + headers + body)

```java
ResponseEntity<User> response = restClient.get()
        .uri("/users/{id}", id)
        .retrieve()
        .toEntity(User.class);

HttpStatusCode status = response.getStatusCode();
User body = response.getBody();
```

### Multipart file upload

```java
MultiValueMap<String, Object> parts = new LinkedMultiValueMap<>();
parts.add("file", new FileSystemResource(file));
parts.add("description", "profile photo");

restClient.post()
        .uri("/uploads")
        .contentType(MediaType.MULTIPART_FORM_DATA)
        .body(parts)
        .retrieve()
        .toBodilessEntity();
```

### Streaming a response

```java
restClient.get()
        .uri("/large-file")
        .exchange((request, response) -> {
            try (InputStream in = response.getBody()) {
                Files.copy(in, Path.of("out.bin"), StandardCopyOption.REPLACE_EXISTING);
            }
            return null;
        });
```

`exchange()` gives full low-level control over request/response and is the escape hatch when `retrieve()` isn't enough.

## 3. Error handling (`onStatus`)

By default, `retrieve()` throws `HttpClientErrorException` (4xx) / `HttpServerErrorException` (5xx). Customize with `onStatus`:

```java
public User getUser(String id) {
    return restClient.get()
            .uri("/users/{id}", id)
            .retrieve()
            .onStatus(HttpStatusCode::is4xxClientError, (req, res) -> {
                throw new NotFoundException("User not found: " + id);
            })
            .onStatus(HttpStatusCode::is5xxServerError, (req, res) -> {
                throw new UpstreamServiceException(res.getStatusCode());
            })
            .body(User.class);
}
```

Read the error body before throwing if you need it: `new String(res.getBody().readAllBytes(), StandardCharsets.UTF_8)`.

## 4. Configuration

### 4a. application.yml (simplest — applies to RestClient, RestTemplate, and WebClient factories)

```yaml
spring:
  http:
    client:
      factory: http-components        # http-components | jetty | reactor | jdk | simple
      connect-timeout: 5s
      read-timeout: 10s
```

- `http-components` needs `org.apache.httpcomponents.client5:httpclient5` on the classpath.
- If nothing is specified, Boot auto-detects: Apache HttpClient5 or Jetty if present, else the JDK's built-in `java.net.http.HttpClient`.

### 4b. Programmatic timeouts

Using `ClientHttpRequestFactorySettings` (works with whichever factory is auto-detected):

```java
@Bean
RestClient restClient(RestClient.Builder builder) {
    ClientHttpRequestFactorySettings settings = ClientHttpRequestFactorySettings.defaults()
            .withConnectTimeout(Duration.ofSeconds(5))
            .withReadTimeout(Duration.ofSeconds(10));

    ClientHttpRequestFactory factory = ClientHttpRequestFactoryBuilder.detect().build(settings);

    return builder.requestFactory(factory).build();
}
```

Using the JDK `HttpClient` directly:

```java
@Bean
RestClient restClient(RestClient.Builder builder) {
    HttpClient httpClient = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(5))
            .build();

    JdkClientHttpRequestFactory requestFactory = new JdkClientHttpRequestFactory(httpClient);
    requestFactory.setReadTimeout(Duration.ofSeconds(10));

    return builder.requestFactory(requestFactory).build();
}
```

### 4c. Connection pooling (Apache HttpClient5)

Defaults are low (5 per route / 25 total) — bump them for production:

```java
@Bean
ClientHttpRequestFactoryBuilderCustomizer<HttpComponentsClientHttpRequestFactoryBuilder> poolCustomizer() {
    return builder -> builder.withConnectionManagerCustomizer(cm -> {
        cm.setMaxTotal(100);
        cm.setDefaultMaxPerRoute(20);
    });
}
```

### 4d. Message converters (custom JSON mapper, etc.)

```java
@Bean
RestClient restClient(RestClient.Builder builder, ObjectMapper objectMapper) {
    return builder
            .messageConverters(converters -> {
                converters.clear();
                converters.add(new MappingJackson2HttpMessageConverter(objectMapper));
            })
            .build();
}
```

## 5. Interceptors

Interceptors wrap every request/response — ideal for logging, auth headers, correlation IDs, or metrics. They run in registration order on the way out, reverse order on the way back.

```java
@Bean
RestClient restClient(RestClient.Builder builder) {
    return builder
            .baseUrl("https://api.example.com")
            .requestInterceptor(loggingInterceptor())
            .requestInterceptor(authInterceptor())
            .build();
}

private ClientHttpRequestInterceptor loggingInterceptor() {
    return (request, body, execution) -> {
        log.info("-> {} {}", request.getMethod(), request.getURI());
        ClientHttpResponse response = execution.execute(request, body);
        log.info("<- {}", response.getStatusCode());
        return response;
    };
}

private ClientHttpRequestInterceptor authInterceptor() {
    return (request, body, execution) -> {
        request.getHeaders().add("Authorization", "Bearer " + tokenSupplier.get());
        return execution.execute(request, body);
    };
}
```

As a reusable `@Component` instead of a lambda (useful when it needs its own dependencies, e.g. trace propagation):

```java
@Component
public class TraceIdInterceptor implements ClientHttpRequestInterceptor {

    @Override
    public ClientHttpResponse intercept(HttpRequest request, byte[] body,
                                         ClientHttpRequestExecution execution) throws IOException {
        request.getHeaders().add("X-Trace-Id", MDC.get("traceId"));
        return execution.execute(request, body);
    }
}
```

Retry-on-failure interceptor sketch:

```java
private ClientHttpRequestInterceptor retryInterceptor(int maxAttempts) {
    return (request, body, execution) -> {
        IOException last = null;
        for (int attempt = 1; attempt <= maxAttempts; attempt++) {
            try {
                return execution.execute(request, body);
            } catch (IOException ex) {
                last = ex;
                log.warn("Attempt {}/{} failed: {}", attempt, maxAttempts, ex.getMessage());
            }
        }
        throw last;
    };
}
```

For production-grade retry/backoff prefer Spring Retry (`@Retryable`) or Resilience4j around the calling method, rather than hand-rolled loops in an interceptor.

## 6. Full example putting it together

```java
@Configuration
public class RestClientConfig {

    @Bean
    RestClient restClient(RestClient.Builder builder) {
        ClientHttpRequestFactorySettings settings = ClientHttpRequestFactorySettings.defaults()
                .withConnectTimeout(Duration.ofSeconds(5))
                .withReadTimeout(Duration.ofSeconds(10));

        return builder
                .baseUrl("https://api.example.com")
                .requestFactory(ClientHttpRequestFactoryBuilder.detect().build(settings))
                .requestInterceptor((request, body, execution) -> {
                    request.getHeaders().add("Authorization", "Bearer " + System.getenv("API_TOKEN"));
                    return execution.execute(request, body);
                })
                .defaultStatusHandler(HttpStatusCode::is4xxClientError, (req, res) -> {
                    throw new ApiClientException(res.getStatusCode());
                })
                .build();
    }
}
```

`defaultStatusHandler` on the builder applies the handler to every request made by this client, so you don't need to repeat `onStatus` per call.

## Quick reference

| Need | How |
|---|---|
| Inject a preconfigured builder | Constructor-inject `RestClient.Builder`, don't call `RestClient.builder()` raw |
| Global timeout via properties | `spring.http.client.connect-timeout` / `read-timeout` |
| Timeout in code | `ClientHttpRequestFactorySettings` + `ClientHttpRequestFactoryBuilder.detect()` |
| Choose HTTP library | `spring.http.client.factory: http-components\|jetty\|reactor\|jdk\|simple` |
| Connection pool size | `HttpComponentsClientHttpRequestFactoryBuilder` customizer |
| Add header/auth to every call | `requestInterceptor(...)` |
| Central error handling | `onStatus(...)` per call, or `defaultStatusHandler(...)` on the builder |
| Low-level access | `.exchange((request, response) -> ...)` |
| List/generic response type | `ParameterizedTypeReference<List<T>>` |
