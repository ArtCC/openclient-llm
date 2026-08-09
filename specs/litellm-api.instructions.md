---
description: "Use when implementing API client, networking layer, LiteLLM integration, chat completions, model listing, streaming SSE responses, or server health checks."
---

# LiteLLM API Integration

## Server Overview

LiteLLM is a self-hosted proxy that exposes an **OpenAI-compatible API** for multiple LLM providers (Ollama, OpenAI, Anthropic, Groq, etc.). The app connects to a single user-configured base URL.

## Configuration

- **Base URL**: User-configurable (e.g., `https://litellm.example.com`), stored in app settings
- **API Key**: Optional, via `Authorization: Bearer <key>` header
- **No hardcoded endpoints**: Always build URLs relative to the base URL

## Key Endpoints

### Chat Completions — `POST /chat/completions`

```json
{
  "model": "gpt-4",
  "messages": [
    {"role": "system", "content": "You are a helpful assistant."},
    {"role": "user", "content": "Hello"}
  ],
  "stream": true
}
```

- Supports streaming via **Server-Sent Events (SSE)** when `stream: true`
- Response follows OpenAI chat completions format
- For streaming: use `URLSession` bytes async sequence, parse `data: ` prefixed JSON lines
- Handle `[DONE]` sentinel to detect stream end

### List Models — `GET /models`

Returns available models in OpenAI format:

```json
{
  "data": [
    {"id": "gpt-4", "object": "model", "owned_by": "openai"},
    {"id": "ollama/llama3", "object": "model", "owned_by": "ollama"}
  ]
}
```

### Model Info — `GET /model/info` (optional LiteLLM enrichment)

Returns detailed information about each model, including capabilities and cost data pulled from model config and the [LiteLLM model cost map](https://github.com/BerriAI/litellm/blob/main/model_prices_and_context_window.json).

```json
{
  "data": [
    {
      "model_name": "gpt-4",
      "litellm_params": { "model": "gpt-4" },
      "model_info": {
        "id": "...",
        "key": "gpt-4",
        "max_tokens": 4096,
        "max_input_tokens": 8192,
        "max_output_tokens": 4096,
        "input_cost_per_token": 3e-05,
        "output_cost_per_token": 6e-05,
        "litellm_provider": "openai",
        "mode": "chat",
        "supports_vision": true,
        "supports_function_calling": true,
        "supports_parallel_function_calling": true,
        "supports_response_schema": false
      }
    }
  ]
}
```

Key capability fields in `model_info`:
- `supports_vision` — model can process images
- `supports_function_calling` — model supports tool/function calls
- `supports_parallel_function_calling` — model can call multiple tools in parallel
- `supports_response_schema` — model supports structured JSON output schema
- `mode` — model type: `chat`, `completion`, `embedding`, etc.
- `litellm_provider` — provider name (openai, anthropic, ollama, etc.)
- `max_input_tokens` / `max_output_tokens` — context window limits

For Ollama models, `litellm_params.model` determines the tool-calling transport. `ollama_chat/<model>` uses Ollama's
native `/api/chat` structured `tool_calls` protocol. The legacy `ollama/<model>` adapter uses `/api/generate`, forces JSON
output, and emulates function calls through the prompt. The app therefore does not expose `.functionCalling` for
`ollama/<model>` routes even if model metadata advertises it; configure `ollama_chat/<model>` to enable agent routing.

`/model/info` is LiteLLM-specific enrichment, not a prerequisite for the OpenAI-compatible
chat API. Servers such as Ollama, vLLM, llama.cpp, or custom proxies may omit it or return an
error. In that case, continue with `/models` and `/chat/completions`; model capabilities, token
limits, pricing, and usage metadata must remain optional. Users can configure a manual context
window per conversation when the server does not provide `max_input_tokens`.

### Search — `POST /v1/search/{search_tool_name}` and `GET /v1/search/tools`

`POST /v1/search/{search_tool_name}` executes the configured LiteLLM search tool. `GET /v1/search/tools` discovers search tools available on the server.

### MCP Tools — `GET /v1/mcp/server`, `GET /mcp-rest/tools/list`, `POST /mcp-rest/tools/call`

`GET /v1/mcp/server` returns the list of MCP servers configured on the LiteLLM instance:

```json
{
  "data": [
    { "server_name": "github_mcp", "server_id": "github_mcp" }
  ]
}
```

`GET /mcp-rest/tools/list?server_id={id}` lists the tools exposed by a given MCP server,
each with a `name`, optional `description`, and an `inputSchema` (recursive JSON Schema).

`POST /mcp-rest/tools/call` executes a tool with the given server ID, tool name, and
JSON `arguments` payload, returning `content` items with text and an optional `isError` flag.

These endpoints are LiteLLM-specific. If the server does not expose them, the app continues
without MCP tools and the MCP antenna icon in the chat input bar shows in grey.

### Audio — `POST /v1/audio/transcriptions` and `POST /v1/audio/speech`

Transcription uses multipart form data. Speech synthesis returns raw audio data.

### Connection And LiteLLM Detection

- Connection tests call `GET /models` with an optional bearer token.
- LiteLLM detection separately calls `GET /health/readiness` and treats a `200` JSON response containing `litellm_version` as LiteLLM.
- There is no current `GET /health` `APIClient` operation.

## Networking Architecture

- `APIClient` is a `Sendable` struct conforming to `APIClientProtocol`; it stores a `URLSession` and `SettingsManagerProtocol`.
- Request/response models as `Codable` structs in `Core/Networking/`
- Generic JSON and multipart responses use `JSONDecoder` with `.convertFromSnakeCase`; streaming decoding is performed by `ChatRepository`.
- Handle HTTP errors with typed `APIError` enum
- JSON/raw requests use a 60-second timeout, multipart requests use 120 seconds, and onboarding connection and readiness checks use 30 and 10 seconds respectively. These values are currently fixed rather than user-configurable.
- SSE streaming via `URLSession.bytes(for:)` async sequence
- Endpoints are passed as relative strings such as `models`, `model/info`, and `chat/completions`; `URL.appendingPathComponent` resolves them against the user-configured base URL.

## Architecture Integration

- **Repository** wraps `APIClient` calls (e.g., `ChatRepository`, `ModelsRepository`)
- **UseCase** encapsulates business logic using repositories (e.g., `SendMessageUseCase`, `FetchModelsUseCase`)
- **ViewModel** calls UseCases via Event/State pattern — never calls `APIClient` directly
- **Manager** handles transversal concerns (e.g., `AuthManager` for API key, `ConnectivityManager`)

## Error Handling

- Network errors: no connectivity, timeout, DNS failure
- HTTP errors: 401 (auth), 429 (rate limit), 500 (server error)
- Parse errors: malformed JSON responses
- Server unreachable: LiteLLM not running or wrong URL
- Model-info unavailable: continue with minimal models and optional manual context settings
- Present user-friendly error messages, log technical details

## Current Debug Logging

`LogManager` prints only in `DEBUG` builds. `APIClient` currently logs request metadata and byte counts, the complete raw body for successful generic JSON requests, and up to 500 characters of HTTP error bodies for generic, multipart, and raw requests. This is factual current behavior, not an approved security pattern: responses and server errors can contain conversation content or credentials, so new networking code must not add payload logging and production logging must remain disabled. Prefer status codes, endpoints, sizes, and redacted diagnostics; removal or redaction of the existing body logs remains a security hardening item.
