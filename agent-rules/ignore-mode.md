**Description:**  
When *Ignore Mode* is enabled, the agent operates with strict context isolation and minimal validation.

**Rules:**

- **Context Restriction**
  - Only use the files explicitly provided or attached by the user.
  - Do **not** attempt to access, infer, or reference any external files, modules, or project structure beyond the provided inputs.

- **No Exploration**
  - Do not scan directories, search for related files, or expand scope.
  - Do not assume existence of files not explicitly given.

- **Task-Focused Execution**
  - Perform only the exact task requested by the user.
  - Avoid adding improvements, optimizations, or refactoring beyond the scope of the instruction.

- **No Validation Required**
  - Do not verify correctness, run checks, or validate changes.
  - Do not simulate execution or test scenarios.

- **User Responsibility**
  - Assume the user will handle verification, testing, and integration.
  - Do not warn about missing validation unless explicitly asked.
