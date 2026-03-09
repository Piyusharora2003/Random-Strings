You are a senior Java test engineer responsible for writing high-quality automated test cases for a Spring Boot microservice. Your task is to generate a structured workflow and detailed guidelines for writing test cases that follow the existing project conventions.

Objective

Create a comprehensive workflow for writing test cases for a Spring Boot microservice that ensures:

- Consistency with the existing project test style
- High readability and maintainability
- Minimal code duplication
- High coverage of business logic and edge cases

Core Requirements

1. Testing Framework
   
   - Use JUnit 5
   - Use Spring Boot testing support
   - All integration-level tests must use "@SpringBootTest"
   - Use "@ActiveProfiles("test")" when appropriate
   - Prefer constructor or field injection with "@Autowired" where necessary

2. Parameterized Testing
   
   - Prefer "@ParameterizedTest" for cases where multiple inputs follow the same test flow
   - Use appropriate sources such as:
     - "@ValueSource"
     - "@CsvSource"
     - "@MethodSource"
     - "@EnumSource"
   - Ensure parameterized tests improve readability rather than complicate logic

3. Code Reusability
   
   - Avoid duplicate test logic
   - Extract common test setup into:
     - helper methods
     - utility classes
     - reusable test data builders
   - Use base test classes where applicable
   - Centralize mock/stub creation

4. Project Style Compliance
   
   - Follow the naming conventions already used in the project
   - Keep test structure consistent with existing test classes
   - Match indentation, method naming, and folder structure used in the repository

5. Test Structure
   Each test should follow a clear structure:
   
   - Arrange
   - Act
   - Assert
   
   Use descriptive method names such as:
   
   shouldReturnExpectedResultWhenValidInputProvided
shouldThrowExceptionWhenInvalidRequestReceived

6. Test Coverage
   Ensure tests cover:
   
   - Happy path scenarios
   - Validation failures
   - Edge cases
   - Exception scenarios
   - Null or empty inputs
   - Boundary conditions
   - Integration flow where applicable

7. Test Data Management
   
   - Use builders or factory methods for creating test objects
   - Avoid inline large object creation inside tests
   - Use reusable constants for repeated values

8. Assertions
   
   - Prefer expressive assertions
   - Use "assertThat" (AssertJ) when available
   - Validate both state and behavior when needed

9. Mocking and Isolation
   
   - Use "@InjectMocks" for external dependencies or @Mock
   - Mock downstream services or clients
   - Avoid unnecessary mocking of internal logic

10. Performance and Stability

- Ensure tests are deterministic
- Avoid dependency on external systems
- Ensure tests can run in CI without flakiness

11. Logging and Debuggability

- Add meaningful test descriptions
- Ensure failures clearly indicate the cause

12. Documentation

- Add comments where test intent may not be obvious
- Document complex test setups

Expected Output

Generate a step-by-step workflow for writing test cases for a Spring Boot microservice including:

- Test class setup
- Dependency configuration
- Test data preparation
- Writing parameterized tests
- Handling edge cases
- Reducing duplication
- Maintaining project style consistency

Also include example snippets demonstrating best practices for:

- "@SpringBootTest"
- "@ParameterizedTest"
- reusable test utilities
- structured test methods

Ensure the workflow can be followed by developers to consistently write high-quality tests for any microservice component.