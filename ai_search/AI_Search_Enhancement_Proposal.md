# AI Search UI & Autocomplete Enhancement Proposal

## Objectives

### Existing (Already Implemented)

-   AI mode toggle
-   Natural language query -\> Spring Boot
-   LLM converts query into `FilterDTO`
-   Angular receives `FilterDTO`
-   Existing List API fetches results using `FilterDTO`

No changes are required in the List API.

------------------------------------------------------------------------

# Proposed UI Changes

## Normal Mode

-   Existing single-line search bar
-   Existing filter panel
-   Existing search workflow

## AI Mode

Replace the single-line input with: - Multi-line auto-growing textarea
(3--5 rows) - AI Mode toggle - "Generate Filters" button - Suggestion
chips / autocomplete below the textarea - Character counter (optional)

Suggestions should represent query templates instead of user-specific
values.

Example: - Find users with name `<name>` - Find users with company
`<company>` - Find inactive users - Find users created after `<date>`

------------------------------------------------------------------------

# Architecture

``` text
                Angular

AI Textarea
      |
      +--> Suggestion API (debounced)
      |
      +--> Resolve Query API
                    |
              FilterDTO
                    |
             Existing List API
                    |
                 Database
```

The List API remains the single source of truth.

------------------------------------------------------------------------

# Frontend Structure

``` text
search/

├── components/
│   ├── search-toolbar.component
│   ├── ai-search.component
│   ├── suggestion-list.component
│   └── result-grid.component
│
├── services/
│   ├── search.service
│   ├── ai-search.service
│   └── suggestion.service
│
└── models/
    ├── filter.dto.ts
    ├── suggestion.dto.ts
    └── ai-query-request.ts
```

## Request Flow

Typing

``` text
User
  |
Textarea
  |
debounce(300 ms)
  |
Suggestion API
  |
Suggestions
```

Search

``` text
User
  |
Resolve Query API
  |
LLM
  |
FilterDTO
  |
Existing List API
  |
Results
```

------------------------------------------------------------------------

# Backend Structure

``` text
controller/

├── SearchController
├── AISearchController
└── SuggestionController

service/

├── SearchService
├── AIQueryResolverService
└── SuggestionService

repository/

├── SuggestionRepository
└── RecentSearchRepository (optional)

dto/

├── FilterDTO
├── SuggestionDTO
└── AIQueryRequest
```

## Responsibilities

### SearchController

Owns existing List API.

### AISearchController

Accepts natural language queries and returns FilterDTO.

### SuggestionController

Returns query suggestions/templates for autocomplete.

### SuggestionService

Loads matching suggestions from PostgreSQL.

------------------------------------------------------------------------

# API Design

## Existing

    POST /api/search/resolve-query

Response

    FilterDTO

------------------------------------------------------------------------

## Existing

    POST /api/list

No changes.

------------------------------------------------------------------------

## New

    GET /api/search/suggestions?q=<partial>

Example Response

``` json
[
  {
    "text": "Find users with name <name>",
    "type": "TEMPLATE"
  },
  {
    "text": "Find users with company <company>",
    "type": "TEMPLATE"
  }
]
```

------------------------------------------------------------------------

# Database

## ai_search_template

``` sql
CREATE TABLE ai_search_template
(
    id BIGSERIAL PRIMARY KEY,
    text VARCHAR(300) NOT NULL,
    display_order INT DEFAULT 0,
    enabled BOOLEAN DEFAULT TRUE
);
```

Example rows

  text
  --------------------------------------------
  Find users with name `<name>`{=html}
  Find users with company `<company>`{=html}
  Find inactive users
  Find users created after `<date>`{=html}

------------------------------------------------------------------------

## Optional: Recent Searches

``` sql
CREATE TABLE ai_recent_search
(
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT,
    query TEXT,
    created_at TIMESTAMP
);
```

This can be added later if recent search history is required.

------------------------------------------------------------------------

# Future Improvements (Not Required for MVP)

## Dynamic Value Suggestions

When the user types:

    Find users with name pi

the backend may detect that a value is being entered and query:

``` sql
SELECT DISTINCT name
FROM users
WHERE LOWER(name) LIKE LOWER('pi%')
LIMIT 5;
```

This enables suggestions like:

-   Piyush
-   Pintu
-   Priya

without involving the LLM.

------------------------------------------------------------------------

# Scope for 5--6 Hour Implementation

-   Redesign AI search area (textarea + chips)
-   Add Suggestion API
-   Add `ai_search_template` table
-   Implement debounced autocomplete
-   Keep existing AI resolver unchanged
-   Keep existing List API unchanged

This delivers an MVP that is simple, maintainable, and extensible while
requiring minimal backend and database changes.
