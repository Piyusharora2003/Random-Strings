```json
[
  {
    "name": "Test Media Upload",
    "endpoint": "/api/media",
    "method": "POST",
    "request": {
      "body": {
        "id": "123",
        "name": "Sample Asset",
        "url": "example.com",
        "imageUrl": "example.com/img",
        "country": "US"
      }
    },
    "validations": [
      {
        "target": "dynamodb",
        "query": { "id": "123" },
        "expectedResult": { "state": "uploaded" }
      },
      {
        "target": "postgres",
        "query": "SELECT * FROM media_history WHERE id = '123'",
        "expectedResult": { "action": "created" }
      },
      {
        "target": "oracle",
        "query": "SELECT * FROM media_assets WHERE id = '123'",
        "expectedResult": { "name": "Sample Asset" },
        "delaySeconds": 20
      }
    ]
  }
]

```

api-test-runner/
├── src/main/java
│   └── com.company.testrunner
│       ├── runner/
│       │   └── TestRunnerApplication.java
│       ├── suite/
│       │   ├── TestSuiteLoader.java
│       │   ├── TestCase.java
│       │   └── ValidationSpec.java
│       ├── executor/
│       │   ├── TestExecutor.java
│       │   └── ApiExecutor.java
│       ├── validation/
│       │   ├── ValidationEngine.java
│       │   ├── DatabaseValidator.java
│       │   ├── DynamoValidator.java
│       │   ├── PostgresValidator.java
│       │   └── OracleValidator.java
│       ├── retry/
│       │   └── RetryPolicy.java
│       └── report/
│           └── TestReport.java
└── src/main/resources
    ├── test-suites/
    │   └── media-tests.json
    └── application.yml



┌────────────────────────┐
│   TestRunner (main)    │
└───────────┬────────────┘
            │
┌───────────▼────────────┐
│  TestSuiteLoader       │  ← loads JSON
└───────────┬────────────┘
            │
┌───────────▼────────────┐
│  TestExecutor          │
│  - API Executor        │
│  - Validation Engine   │
└───────┬───────┬────────┘
        │       │
 ┌──────▼───┐ ┌─▼────────┐
 │ API Call │ │ Validators│
 └──────────┘ │ Dynamo    │
              │ Postgres  │
              │ Oracle    │
              └───────────┘






Build a standalone Spring Boot test runner that:
Reads API test cases from JSON
Executes API calls (via API Gateway)
Handles async/eventual consistency (SQS → consumer)
Validates final state across:
DynamoDB (state)
Postgres (history)
Oracle (asset – eventual consistency)
Produces human-readable + machine-readable test reports
Runs on-demand (CLI / main method)


🧠 Core Design Principles (tell your agent)
Configuration over code (JSON drives everything)
Pluggable validations (DBs are interchangeable)
Retry-based eventual consistency, not fixed sleep
Fail fast, but report everything
No Spring MVC / Controllers – this is a runner, not an API

🔄 Execution Flow (Step-by-Step)
1️⃣ Bootstrap
Start Spring context
Load DB configs + AWS creds
2️⃣ Load Suite
Read JSON
Deserialize into TestCase objects
3️⃣ Execute API
Call API Gateway
Validate HTTP status
Extract correlation IDs (optional)
4️⃣ Run Validations
Immediate:
DynamoDB
Postgres
Eventual:
Oracle via retry loop
5️⃣ Retry Strategy (Key Insight)
Never Thread.sleep()
Use polling until success or timeout