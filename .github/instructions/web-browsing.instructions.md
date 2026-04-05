---
description: "Use when implementing web browsing or web search capabilities, integrating web search via LiteLLM, displaying search results or citations in chat, or configuring search-related settings."
applyTo: "**/*.swift"
---

# Web Search — Integration via LiteLLM Search API

## References

- LiteLLM Search Overview: https://docs.litellm.ai/docs/search/
- LiteLLM ≥ v1.78.7 required for the `/v1/search` endpoint

## Overview

Web search is implemented **exclusively through the LiteLLM Search API**. The app never calls any search provider API directly and never uses function calling / tool interception for search. All search requests go to the user's LiteLLM proxy via `POST /v1/search/{search_tool_name}`. LiteLLM handles provider selection, API keys, and result fetching transparently on the server side.

- **No search API keys in the app** — keys live in LiteLLM's server environment
- **No direct calls to any search provider** (Brave, Perplexity, Tavily, etc.)
- **No function calling / `litellm_web_search` tool** — the dedicated `/v1/search` endpoint is used instead
- Works with **any model** — no function calling support required
- The LiteLLM base URL is the same one already configured by the user for chat

### Flow

```
User taps 🌐  →  POST /v1/search/{tool_name}  →  inject results as context  →  POST /chat/completions  →  response with citations
```

---

## LiteLLM Search Endpoint

```
POST {litellm_base_url}/v1/search/{search_tool_name}
Authorization: Bearer {litellm_api_key}
Content-Type: application/json
```

**Request body**:

```json
{
  "query": "latest Swift 6 features",
  "max_results": 10,
  "max_tokens_per_page": 1024,
  "country": "US"
}
```

**Response** (Perplexity-compatible format):

```json
{
  "object": "search",
  "results": [
    {
      "title": "What's new in Swift 6",
      "url": "https://www.swift.org/blog/swift-6/",
      "snippet": "Swift 6 introduces complete concurrency checking...",
      "date": "2024-06-10"
    }
  ]
}
```

### Request Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `query` | String | Yes | Search query |
| `max_results` | Int | No | Results to return (1–20, default: 10) |
| `search_domain_filter` | [String] | No | Restrict to specific domains |
| `country` | String | No | Country code filter (e.g., `"US"`, `"ES"`) |
| `max_tokens_per_page` | Int | No | Max tokens per result page (default: 1024) |

### Response Fields

| Field | Type | Description |
|-------|------|-------------|
| `object` | String | Always `"search"` |
| `results` | Array | List of search results |
| `results[].title` | String | Title of the result |
| `results[].url` | String | URL of the result |
| `results[].snippet` | String | Text snippet |
| `results[].date` | String? | Optional publication date |

---

## Implementation

### Models

```swift
// Shared/Core/Networking/SearchModels.swift

struct LiteLLMSearchRequest: Codable, Sendable {
    let query: String
    let maxResults: Int?          // optional, API default: 10 (range 1–20)
    let maxTokensPerPage: Int?    // optional, API default: 1024
    let country: String?
    let searchDomainFilter: [String]?
}

struct LiteLLMSearchResponse: Codable, Sendable {
    let object: String
    let results: [LiteLLMSearchResult]
}

struct LiteLLMSearchResult: Codable, Sendable {
    let title: String
    let url: String
    let snippet: String
    let date: String?
}
```

### UseCase

```swift
// Shared/Features/Chat/UseCases/WebSearchUseCase.swift

protocol WebSearchUseCaseProtocol: Sendable {
    func search(query: String) async throws -> [LiteLLMSearchResult]
}
```

- Calls `APIClient` using the LiteLLM base URL already configured
- The search tool name is read from `SettingsManager` (e.g. `"brave-search"`)
- Uses the same `Authorization: Bearer` header as chat requests
- **Never** constructs URLs to external search providers

### Context Injection

Inject results as a system message prepended before the user message:

```
Based on the following web search results for "{query}":

1. [{title}]({url})
   {snippet}

2. [{title}]({url})
   {snippet}

Use these sources to answer the user's question. Cite sources using [Source Title](URL) format.
```

- Limit to top 5 results to manage token usage
- Include source URLs for citation

---

## LiteLLM Server Configuration (reference for users)

Add `search_tools` to the LiteLLM proxy `config.yaml`. The `search_tool_name` value must match what is configured in the app's settings.

```yaml
search_tools:
  - search_tool_name: brave-search
    litellm_params:
      search_provider: brave
      api_key: os.environ/BRAVE_API_KEY
```

### Supported providers (agnostic to the app)

| Provider | `search_provider` value | Server env var |
|----------|------------------------|----------------|
| Brave Search | `brave` | `BRAVE_API_KEY` |
| Perplexity | `perplexity` | `PERPLEXITYAI_API_KEY` |
| Tavily | `tavily` | `TAVILY_API_KEY` |
| Exa AI | `exa_ai` | `EXA_API_KEY` |
| DuckDuckGo | `duckduckgo` | `DUCKDUCKGO_API_BASE` |
| SearXNG | `searxng` | `SEARXNG_API_BASE` |
| Google PSE | `google_pse` | `GOOGLE_PSE_API_KEY` + `GOOGLE_PSE_ENGINE_ID` |
| Firecrawl | `firecrawl` | `FIRECRAWL_API_KEY` |
| Linkup | `linkup` | `LINKUP_API_KEY` |
| Serper | `serper` | `SERPER_API_KEY` |

---

## Settings

- **Search tool name**: Stored in `SettingsManager` (UserDefaults), default: `"brave-search"` — must match `search_tool_name` in the LiteLLM `config.yaml`
- **Result count**: Default 10 (matches API default), configurable (1–20)
- **No search API key in the app** — key management is the server's responsibility

---

## UI

### Globe button in chat input bar

- **SF Symbol**: `globe` (inactive) / filled or tinted variant (active)
- Placed in the input bar alongside the model selector and other action buttons
- Always visible — works with any model, no capability check required
- When tapped: toggles `webSearchEnabled` on the current conversation
- When active: show globe with accent color tint
- During search: show a brief "Searching the web…" inline status below the input bar while the `/v1/search` request is in flight

### Response rendering

- Render citations as tappable `Link` views: `[Source Title](URL)`
- Show a collapsible "Sources" section below the assistant response when search results are available
- Display result count (e.g. "3 sources") in the collapsed header

---

## Security Considerations

- **No external API keys in the app** — all credentials live on the user's LiteLLM server
- **Content sanitization**: Strip HTML from snippets before displaying
- **URL validation**: Validate URLs from results before making them tappable
- **No arbitrary URL fetching**: Never fetch content from result URLs, only display them as links
- **SSRF prevention**: The app only connects to the user-configured LiteLLM base URL — same trust boundary as chat

---

## Error Handling

- Search tool not configured on server (404) → Show: "Web search is not configured on your LiteLLM server. Add a `search_tools` entry to your config.yaml."
- 401 → LiteLLM API key invalid or missing
- 404 → `search_tool_name` in Settings does not match any configured tool on the server
- 429 → Rate limited by the search provider — show "Try again later"
- Network error → Fall back gracefully: send the message without search context
- Empty results → Inform user "No relevant web results found", proceed without context
