---
description: "Use when implementing web browsing or web search capabilities, integrating web search via LiteLLM, displaying search results or citations in chat, or configuring search-related settings."
applyTo: "**/*.swift"
---

# Web Search — Integration via LiteLLM

## References

- LiteLLM Search Overview: https://docs.litellm.ai/docs/search/
- LiteLLM Brave Search: https://docs.litellm.ai/docs/search/brave
- LiteLLM Web Search Interception: https://docs.litellm.ai/docs/integrations/websearch_interception

## Overview

Web search is implemented **entirely through LiteLLM**. The app never calls any search provider API directly — it delegates all search requests to the user's LiteLLM proxy server, which handles the search provider configuration, API keys, and result fetching transparently.

**Default provider**: Brave Search (configured in the user's LiteLLM server). Any LiteLLM-supported search provider works without changes to the app: Perplexity, Tavily, Exa AI, Google PSE, DuckDuckGo, SearXNG, etc. The app is agnostic to which provider the server uses.

- **No search API keys in the app** — keys live in LiteLLM's server environment
- **No direct calls to `api.search.brave.com`** or any other search API
- The LiteLLM base URL is the same one already configured by the user for chat

## Two Modes

The app implements **both modes** simultaneously. They are complementary, not mutually exclusive.

### Mode A — Manual Search (globe button, any model)

The user activates a **globe button** in the chat input bar (inspired by LibreChat). When active:

1. App calls `POST /v1/search/{search_tool_name}` on LiteLLM to fetch results
2. Results are injected as context into the chat request
3. App calls `POST /chat/completions` with the enriched context

```
User taps 🌐  →  /v1/search  →  inject results  →  /chat/completions  →  response with citations
```

**Works with any model** — no function calling required. The user controls web search explicitly.

### Mode B — Automatic Interception (transparent, capable models)

When the selected model supports function calling (`supports_function_calling: true` from `/model/info`), the app automatically includes the `litellm_web_search` tool in the `tools` array of every `POST /chat/completions` request. LiteLLM intercepts the tool call, executes the search, and returns the final answer — all transparently.

```
/chat/completions  →  LiteLLM detects tool call  →  executes search  →  follow-up completion  →  final answer
```

**Requires**: model supports function calling AND LiteLLM server has `websearch_interception` callback configured with a `search_tool_name`.

**The user does nothing** — no globe button needed when this mode is active.

### Decision logic

```
if model.supportsFunctionCalling && webSearchInterceptionEnabled {
    // Mode B: include litellm_web_search in tools array automatically
} else if userToggledWebSearch {
    // Mode A: call /v1/search first, then inject context into /chat/completions
}
```

`webSearchInterceptionEnabled` is a setting the user configures in the app (matches whether their LiteLLM server has the callback configured).

Both modes can coexist: Mode B is transparent and automatic; Mode A is explicit and user-controlled as a fallback.

---

## Mode A — Implementation Details

### LiteLLM Search Endpoint

```
POST {litellm_base_url}/v1/search/{search_tool_name}
Authorization: Bearer {litellm_api_key}
Content-Type: application/json
```

**Request body**:

```json
{
  "query": "latest Swift 6 features",
  "max_results": 5,
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

### Models

```swift
// Shared/Core/Networking/SearchModels.swift

struct LiteLLMSearchRequest: Codable, Sendable {
    let query: String
    let maxResults: Int
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

- Calls `APIClient` with the LiteLLM base URL (already known)
- The search tool name is read from `SettingsManager` (e.g. `"brave-search"`)
- Uses the same `Authorization: Bearer` header as chat requests
- **Never** constructs URLs to external search providers

### Context Injection

Inject results as a system message before the user message:

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

## Mode B — Implementation Details

### Tool Definition

When Mode B is active, include this entry in the `tools` array of every `/chat/completions` request:

```json
{
  "type": "function",
  "function": {
    "name": "litellm_web_search",
    "description": "Search the web for current information",
    "parameters": {
      "type": "object",
      "properties": {
        "query": { "type": "string", "description": "Search query" }
      },
      "required": ["query"]
    }
  }
}
```

LiteLLM intercepts the `litellm_web_search` tool call automatically and returns the final grounded answer. The app does not need to handle the tool call response — LiteLLM resolves the full agentic loop on the server side.

### When to inject

- Read `model.supportsFunctionCalling` from the model info already fetched
- Read `webSearchInterceptionEnabled` from `SettingsManager`
- Only inject the tool if both are `true`
- Do **not** show the globe button in the input bar when Mode B is active (it's invisible to the user)

---

## LiteLLM Server Configuration (reference for users)

### For Mode A — `search_tools` in config.yaml

```yaml
search_tools:
  - search_tool_name: brave-search
    litellm_params:
      search_provider: brave
      api_key: os.environ/BRAVE_API_KEY
```

### For Mode B — `websearch_interception` callback in config.yaml

```yaml
litellm_settings:
  callbacks:
    - websearch_interception:
        enabled_providers:
          - openai
          - anthropic
          - ollama
        search_tool_name: brave-search

search_tools:
  - search_tool_name: brave-search
    litellm_params:
      search_provider: brave
      api_key: os.environ/BRAVE_API_KEY
```

Both modes share the same `search_tools` definition — only one `BRAVE_API_KEY` needed on the server.

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

---

## Settings

- **Search tool name**: Stored in `SettingsManager` (UserDefaults), default: `"brave-search"` — must match `search_tool_name` in the LiteLLM config
- **Web Search Interception enabled**: Bool in `SettingsManager` — user enables this if their server has the `websearch_interception` callback configured (enables Mode B)
- **Result count** (Mode A): Default 5, configurable (3–10)
- **No search API key in the app** — key management is the server's responsibility

---

## UI

### Globe button in chat input bar

- **SF Symbol**: `globe` (inactive) / `globe.badge.chevron.backward` or filled variant (active)
- Placed in the input bar alongside the model selector and other action buttons
- **Only visible when Mode B is NOT active** (i.e., the current model does not support function calling, or interception is disabled in settings)
- When tapped: toggles `webSearchEnabled` on the current conversation
- When active: show globe with accent color tint
- During search (Mode A): show a brief "Searching the web..." inline status below the input bar

### Response rendering

- Render citations as tappable `Link` views: `[Source Title](URL)`
- Show a collapsible "Sources" section below the assistant response when Mode A results are available
- Mode B citations appear inline in the LLM response text — no special handling needed

---

## Security Considerations

- **No external API keys in the app** — all credentials live on the user's LiteLLM server
- **Content sanitization**: Strip HTML from snippets before displaying
- **URL validation**: Validate URLs from results before making them tappable
- **No arbitrary URL fetching**: Never fetch content from result URLs, only display them as links
- **SSRF prevention**: The app only connects to the user-configured LiteLLM base URL — same trust boundary as chat

---

## Error Handling

- Search tool not configured on server (Mode A 404) → Show: "Web search is not configured on your LiteLLM server. Add a `search_tools` entry to your config.yaml."
- 401 → LiteLLM API key invalid or missing
- 404 → `search_tool_name` in Settings does not match any tool on the server
- 429 → Rate limited by the search provider, show "Try again later"
- Network error → Fall back gracefully: send the message without search context
- Empty results → Inform user "No relevant web results found", proceed without context
- Mode B: if LiteLLM returns a raw `tool_calls` response without resolving it (interception not configured on server) → log warning, do not show broken tool call to user, fall back to sending without tools
