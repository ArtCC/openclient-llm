---
description: "Use when implementing web browsing or web search capabilities, integrating web search via LiteLLM, displaying search results or citations in chat, or configuring search-related settings."
applyTo: "**/*.swift"
---

# Web Search — Integration via LiteLLM

## References

- LiteLLM Web Search (native): https://docs.litellm.ai/docs/completion/web_search
- LiteLLM Web Search Interception: https://docs.litellm.ai/docs/integrations/websearch_interception
- LiteLLM Search API (`/v1/search`): https://docs.litellm.ai/docs/search/
- LiteLLM Function Calling: https://docs.litellm.ai/docs/completion/function_call

## Overview

Web search uses **three LiteLLM mechanisms** depending on the model's capabilities. The app never calls any search provider API directly — LiteLLM handles provider selection, API keys, and result fetching on the server side.

- **No search API keys in the app** — keys live in LiteLLM's server environment
- **No direct calls to any search provider** (Brave, Perplexity, Tavily, etc.)
- **No manual context injection** — results are never fetched client-side and injected as system messages
- The LiteLLM base URL is the same one already configured by the user for chat

### Web Search Flow Table

| Condition | Globe Color | Behavior |
|-----------|------------|----------|
| Web search OFF | Grey | No search — regular streaming |
| Web search ON + `.nativeWebSearch` | Accent | `web_search_options` sent in request body (streaming) |
| Web search ON + `.functionCalling` | Accent | Agent loop with tool `web_search` → executed via `/v1/search` endpoint |
| Web search ON + no capabilities | Red | **No search. Ignored.** Falls through to regular streaming |

### Mechanism Details

#### 1. Native Web Search (`web_search_options`)

For models that natively support web search (e.g., `gpt-4o-search-preview`, `gpt-5-search-api`, Perplexity models, xAI Grok, Anthropic Claude with web search, Gemini). The app sends `web_search_options` in the chat completions request body:

```json
{
  "model": "gpt-4o-search-preview",
  "messages": [...],
  "stream": true,
  "web_search_options": {
    "search_context_size": "medium"
  }
}
```

LiteLLM passes this to the provider. Results and citations are embedded in the response by the model itself. The app uses regular streaming (`performStreaming` with `webSearchOptions` parameter).

**Model detection**: `model_info.supports_web_search == true` → `.nativeWebSearch` capability.

#### 2. Agent Loop with `/v1/search` (Function Calling models)

For models with function calling but without native web search. The app registers a tool named `web_search` and runs an **agentic loop**:

1. App sends request with `tools: [web_search]` + `tool_choice: "auto"`
2. Model responds with `tool_calls: [{"function": {"name": "web_search", ...}}]`
3. App's `AgentStreamUseCase` → `WebSearchTool.execute()` → calls `POST /v1/search/{search_tool_name}` (e.g., `/v1/search/brave-search`)
4. Search results sent back to model as tool result
5. Model generates final grounded response

This works with **any model from any provider** (Ollama, OpenAI, Anthropic, Groq, etc.) as long as the model returns structured `tool_calls` (not text-plain JSON). The `/v1/search` endpoint is completely model-agnostic.

**Model detection**: `model_info.supports_function_calling == true` → `.functionCalling` capability.

**Known limitation**: Some small/specialized models (e.g., `qwen2.5-coder`) may emit tool calls as plain text in `content` instead of structured `tool_calls` in the response. In this case the agent loop cannot intercept them and the raw JSON is displayed as the assistant message.

#### 3. Web Search Interception (Server-Side, Optional)

LiteLLM supports `websearch_interception` as a server-side callback. However, it uses the reserved tool name `litellm_web_search` for interception, which **conflicts with some providers like Ollama** — LiteLLM may attempt server-side interception even when not explicitly configured, causing unexpected behavior.

The app intentionally uses the generic tool name `web_search` to **avoid triggering interception**, ensuring the agent loop always works reliably across all providers. If you want server-side interception for specific providers, you would need to configure it separately on the LiteLLM server with a matching tool name.

#### 4. No Capabilities — No Search

Models without `.nativeWebSearch` and without `.functionCalling` **cannot search the web**. The globe button appears red to indicate this. When the user sends a message, web search is silently ignored and regular streaming proceeds.

---

## LiteLLM Server Configuration (reference for users)

### Search Tools (required for `/v1/search` and interception)

```yaml
search_tools:
  - search_tool_name: brave-search
    litellm_params:
      search_provider: brave
      api_key: os.environ/BRAVE_API_KEY
```

### Web Search Interception (optional, server-side)

LiteLLM offers `websearch_interception` as a callback that intercepts tool calls named `litellm_web_search`. The app does **NOT** use this mechanism — it uses the generic tool name `web_search` instead to avoid interference with providers like Ollama.

If you want to experiment with server-side interception for specific providers (OpenAI, Anthropic, etc.), configure it under `litellm_settings.callbacks` with `enabled_providers`. Note: this is independent from the app’s agent loop and requires the tool name `litellm_web_search`:

```yaml
# NOT used by the app — reference only
litellm_settings:
  callbacks:
    - websearch_interception:
        enabled_providers:
          - openai
          - anthropic
        search_tool_name: brave-search

search_tools:
  - search_tool_name: brave-search
    litellm_params:
      search_provider: brave
      api_key: os.environ/BRAVE_API_KEY
```

**Note**: `enabled_providers` lists the **LLM providers** (openai, anthropic, groq, etc.), NOT search providers. Ollama is NOT supported and using `litellm_web_search` tool name with Ollama may cause unexpected behavior (raw JSON responses, server-side interception attempts). The app avoids this by using `web_search` as the tool name.

### Supported Search Providers (agnostic to the app)

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
| SearchAPI.io | `searchapi` | `SEARCHAPI_API_KEY` |

---

## Implementation

### Decision Logic (`streamWithWebSearch`)

```swift
func streamWithWebSearch(_ context: SendMessageContext) async {
    let supportsNativeWebSearch = context.webSearchEnabled
        && context.modelCapabilities.contains(.nativeWebSearch)
    let supportsAgentMode = context.webSearchEnabled
        && context.modelCapabilities.contains(.functionCalling)
        && !supportsNativeWebSearch
    if supportsAgentMode {
        // Agent loop: tool web_search → /v1/search endpoint
        await performAgentStreaming(...)
    } else if supportsNativeWebSearch {
        // web_search_options in request body
        await performStreaming(..., webSearchOptions: WebSearchOptions())
    } else {
        // No search (disabled or no capabilities) → regular streaming
        await performStreaming(...)
    }
}
```

### Key Types

- `WebSearchOptions` — Sent in request body for native web search models
- `WebSearchTool` — Implements `ChatToolProtocol`, defines `web_search` function. On execution, calls `WebSearchUseCase` which hits `/v1/search/{search_tool_name}`
- `ToolRegistry` — Registers `WebSearchTool` when agent mode is used
- `AgentStreamUseCase` — Manages the agentic loop (see `agent-tool-calling.instructions.md`)
- `WebSearchUseCase` — Calls `APIClient.searchRequest()` → `POST /v1/search/{search_tool_name}`

### Tool Result Messages

When the agent loop handles `web_search`, tool result messages include the `name` field per OpenAI spec:

```json
{
  "role": "tool",
  "tool_call_id": "call_abc123",
  "name": "web_search",
  "content": "{\"results\": [...]}"
}
```

The `name` field is stored in `ChatMessage.toolName` and serialized via `ChatCompletionMessage.name`.

---

## Settings

- **Search tool name**: Stored in `SettingsManager` (UserDefaults), default: `"brave-search"` — must match a `search_tool_name` in the LiteLLM `config.yaml`
- **Result count**: Default 10 (matches API default), configurable (1–20)
- **No search API key in the app** — key management is the server's responsibility

---

## UI

### Globe Button in Chat Input Bar

- **SF Symbol**: `globe` (inactive) / filled or tinted variant (active)
- Placed in the input bar alongside the model selector and other action buttons
- **Always visible** — but appearance varies by model capability:
  - **Grey**: Web search OFF → no search
  - **Accent color**: Web search ON + model supports search (native or function calling)
  - **Red**: Web search ON + model has no capabilities → search not possible
- When tapped: toggles `webSearchEnabled` on the current conversation
- During search: show a brief "Searching the web…" inline status (for agent mode tool calls)

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
