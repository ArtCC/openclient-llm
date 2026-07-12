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

### Model Info — `GET /model/info`

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

### Health Check — `GET /health`

Simple endpoint to validate server connectivity.

## Networking Architecture

- Single `APIClient` class with `URLSession` + `async/await`
- Request/response models as `Codable` structs in `Core/Networking/`
- Use `JSONDecoder` with `.convertFromSnakeCase` key decoding strategy
- Handle HTTP errors with typed `APIError` enum
- Support request timeout configuration
- SSE streaming via `URLSession.bytes(for:)` async sequence

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
- Present user-friendly error messages, log technical details