---
description: "Use when implementing web browsing or web search capabilities, integrating Brave Search API, displaying search results or citations in chat, or configuring search-related settings."
applyTo: "**/*.swift"
---

# Brave Search API — Web Browsing Integration

## Overview

Brave Search API provides real-time web search results to ground LLM responses with up-to-date information. The app uses it as a **client-side tool** — when the user enables web browsing, the app executes Brave searches locally and injects results into the LLM context.

## Two Integration Approaches

### Approach A: Client-Side (App-Managed) — Recommended

The app manages web search directly:

1. User enables "Web Browsing" toggle in chat
2. Before sending the user message, the app queries Brave Search API
3. Search results are injected as context into the system prompt or as a tool result
4. The LLM generates a grounded response with citations

**Pros**: Works with any model, no LiteLLM server config needed, full control over search.

### Approach B: Server-Side (LiteLLM-Managed)

LiteLLM handles web search via tool calling interception:

1. App sends `tools` array with `litellm_web_search` function definition
2. If the model calls the tool, LiteLLM intercepts and executes the search
3. LiteLLM makes a follow-up request with results and returns the final answer

**Pros**: Leverages LiteLLM's built-in search providers (Perplexity, Tavily, etc.). **Cons**: Requires LiteLLM server config, not all models support tool calling.

> **Decision**: Start with **Approach A** (client-side) for universal compatibility. Consider Approach B as an advanced option later.

## Brave Search API

### Authentication

- **Header**: `X-Subscription-Token: <BRAVE_SEARCH_API_KEY>`
- API key stored in **Keychain** via `KeychainManager` (same pattern as LiteLLM API key)
- Free tier: $5 in free credits/month (~1,000 searches)

### Web Search Endpoint

```
GET https://api.search.brave.com/res/v1/web/search
```

**Query Parameters**:

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `q` | String | Yes | Search query |
| `count` | Int | No | Results per page (default: 10, max: 20) |
| `offset` | Int | No | Pagination offset |
| `country` | String | No | Country code (e.g., `us`, `es`) |
| `search_lang` | String | No | Language code (e.g., `en`, `es`) |
| `freshness` | String | No | `pd` (past day), `pw` (past week), `pm` (past month), `py` (past year) |
| `text_decorations` | Bool | No | Include `<strong>` HTML tags in descriptions |
| `result_filter` | String | No | Comma-separated: `web`, `news`, `images`, `videos` |

### Response Format

```json
{
  "type": "search",
  "query": {
    "original": "latest swift 6 features",
    "show_strict_warning": false
  },
  "web": {
    "type": "search",
    "results": [
      {
        "title": "What's new in Swift 6",
        "url": "https://www.swift.org/blog/swift-6/",
        "description": "Swift 6 introduces complete concurrency checking...",
        "is_source_local": false,
        "is_source_both": false,
        "profile": {
          "name": "Swift.org",
          "url": "https://www.swift.org",
          "long_name": "swift.org",
          "img": "https://..."
        },
        "age": "2024-06-10"
      }
    ]
  }
}
```

### Rate Limits

- **Search plan**: 50 queries/second, $5 per 1,000 requests
- Free tier: $5 credits auto-applied monthly
- Handle 429 (rate limit) responses gracefully

## Implementation Architecture

### Models

```swift
// In Shared/Core/Networking/ or Shared/Features/Chat/Models/

struct BraveSearchResponse: Codable, Sendable {
    let query: BraveSearchQuery
    let web: BraveWebResults?
}

struct BraveSearchQuery: Codable, Sendable {
    let original: String
}

struct BraveWebResults: Codable, Sendable {
    let results: [BraveWebResult]
}

struct BraveWebResult: Codable, Sendable {
    let title: String
    let url: String
    let description: String
    let age: String?  // Date string like "2024-06-10"
}
```

### Search Manager

```swift
// Shared/Core/Managers/BraveSearchManager.swift

protocol BraveSearchManagerProtocol: Sendable {
    func search(query: String, count: Int) async throws -> [BraveWebResult]
}
```

- Uses `URLSession` + `async/await` (same pattern as `APIClient`)
- API key retrieved from Keychain
- Base URL is always `https://api.search.brave.com` (not user-configurable)

### Context Injection

When web browsing is enabled, inject search results into the conversation:

```
Based on the following web search results for "{query}":

1. [{title}]({url})
   {description}

2. [{title}]({url})
   {description}

Use these sources to answer the user's question. Cite sources using [Source Title](URL) format.
```

- Inject as a **system message** or prepend to the user message
- Limit to top 5 results to manage token usage
- Strip HTML tags from descriptions (`<strong>`, etc.)
- Include source URLs for citation

### Settings

- **Web Browsing toggle**: Per-conversation setting (stored in `Conversation` model)
- **Brave API key**: Stored in Keychain, configured in Settings screen
- **Search language**: Auto-detect from device locale or user preference
- **Result count**: Default 5, configurable (3-10)

## UI

### Chat Integration

- Show a "Web" toggle/chip in the input bar area (similar to model selector)
- When enabled, show a subtle indicator (e.g., globe icon) next to the input
- During search, show a brief "Searching the web..." status
- In assistant responses, render citations as tappable links
- Consider showing a collapsible "Sources" section below the response

### Settings Screen

- Section: "Web Browsing"
  - Brave Search API key input (masked, stored in Keychain)
  - Test connection button
  - Default search language picker

## Security Considerations

- **API key**: Always stored in Keychain, never in UserDefaults or plain text
- **Content sanitization**: Strip HTML from search results before displaying
- **URL validation**: Validate URLs from search results before making them tappable
- **No arbitrary URL fetching**: Only use the Brave Search API endpoint, never fetch arbitrary URLs from results
- **Rate limiting**: Implement client-side throttle to prevent accidental API abuse
- **SSRF prevention**: The app only connects to `api.search.brave.com` — no user-supplied search URLs

## Error Handling

- Missing API key → Prompt user to configure in Settings
- 401 → Invalid API key, show clear error
- 429 → Rate limited, retry with backoff or show "Try again later"
- Network error → Fall back gracefully (send message without search context)
- Empty results → Inform user "No relevant web results found", proceed without context
