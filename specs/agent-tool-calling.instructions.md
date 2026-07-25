---
description: "Use when implementing agent mode, tool/function calling, building the agentic loop, registering tools, parsing tool_calls responses, or showing tool execution UI in chat."
applyTo: "**/*.swift"
---

# Agent Mode — Tool Calling Integration

## Overview

Agent mode allows the LLM to call **tools** (functions) that the app executes locally, then returns results to the model for continued reasoning. This enables multi-step workflows where the model can search the web, perform calculations, or interact with external services.

## OpenAI-Compatible Tool Calling Protocol

LiteLLM exposes the standard OpenAI tool calling format. The protocol works identically whether the backend is OpenAI, Anthropic, Ollama, or any other provider.

### Tool Definition Format

Tools are defined as JSON in the `tools` array of the chat completions request:

```json
{
  "model": "gpt-4",
  "messages": [...],
  "tools": [
    {
      "type": "function",
      "function": {
        "name": "web_search",
        "description": "Search the web for current information",
        "parameters": {
          "type": "object",
          "properties": {
            "query": {
              "type": "string",
              "description": "The search query"
            }
          },
          "required": ["query"]
        }
      }
    }
  ],
  "tool_choice": "auto"
}
```

### `tool_choice` Values

| Value | Behavior |
|-------|----------|
| `"auto"` | Model decides whether to call tools (default) |
| `"none"` | Model will not call any tools |
| `"required"` | Model must call at least one tool |
| `{"type": "function", "function": {"name": "..."}}` | Force a specific tool |

## The Agentic Loop

The core of agent mode is a **request → tool_calls → execute → result → continue** loop:

```
┌─────────────────────────────────────────────────────────┐
│ 1. Send messages + tools to /chat/completions           │
│                                                         │
│ 2. Response has finish_reason = "tool_calls"?           │
│    ├── YES → Parse tool_calls, execute each tool        │
│    │         Append assistant message (with tool_calls) │
│    │         Append tool result messages (role: "tool")  │
│    │         → Go back to step 1                        │
│    └── NO  → finish_reason = "stop"                     │
│              Display final response to user             │
└─────────────────────────────────────────────────────────┘
```

### Step-by-Step

**Step 1 — Send request with tools**

```json
POST /chat/completions
{
  "model": "gpt-4",
  "messages": [
    {"role": "user", "content": "What's the latest news about Swift?"}
  ],
  "tools": [/* tool definitions */],
  "tool_choice": "auto"
}
```

**Step 2 — Model responds with tool_calls**

```json
{
  "choices": [{
    "finish_reason": "tool_calls",
    "message": {
      "role": "assistant",
      "content": null,
      "tool_calls": [
        {
          "id": "call_abc123",
          "type": "function",
          "function": {
            "name": "web_search",
            "arguments": "{\"query\": \"Swift programming language latest news 2026\"}"
          }
        }
      ]
    }
  }]
}
```

Key fields:
- `finish_reason`: `"tool_calls"` indicates the model wants to call tools (not `"stop"`)
- `tool_calls[].id`: Unique ID that must be referenced in the tool result
- `tool_calls[].function.name`: Which tool to execute
- `tool_calls[].function.arguments`: JSON string with arguments (must be parsed)

**Step 3 — Execute tools and send results back**

Append the assistant message (with tool_calls) and tool results to the conversation:

```json
POST /chat/completions
{
  "model": "gpt-4",
  "messages": [
    {"role": "user", "content": "What's the latest news about Swift?"},
    {
      "role": "assistant",
      "content": null,
      "tool_calls": [
        {
          "id": "call_abc123",
          "type": "function",
          "function": {
            "name": "web_search",
            "arguments": "{\"query\": \"Swift programming language latest news 2026\"}"
          }
        }
      ]
    },
    {
      "role": "tool",
      "tool_call_id": "call_abc123",
      "name": "web_search",
      "content": "1. Swift 6.1 released with improved concurrency... 2. ..."
    }
  ],
  "tools": [/* same tool definitions */]
}
```

**Step 4 — Model generates final response (or calls more tools)**

```json
{
  "choices": [{
    "finish_reason": "stop",
    "message": {
      "role": "assistant",
      "content": "Here are the latest news about Swift:\n\n1. Swift 6.1..."
    }
  }]
}
```

If `finish_reason` is `"tool_calls"` again, repeat steps 2-3. If `"stop"`, display the response.

### Parallel Tool Calls

Some models can request multiple tool calls in a single response:

```json
"tool_calls": [
  {"id": "call_1", "function": {"name": "web_search", "arguments": "..."}},
  {"id": "call_2", "function": {"name": "web_search", "arguments": "..."}}
]
```

- `AgentStreamUseCase` executes accepted calls concurrently with a throwing task group, then restores model-request order when constructing tool messages.
- Send ALL results back in one request, each with its matching `tool_call_id`
- The current loop does not consult `supports_parallel_function_calling`; it concurrently executes multiple calls whenever the model returns them. Treat that as current behavior when changing capability handling.

### Loop Safety

- **Maximum iterations**: Cap the loop at 10 iterations to prevent infinite loops
- **Tool-call budget**: Cap the total number of calls at 20 and a single tool round at 8 calls.
- **Final-response round**: On the tenth iteration, after exhausting the total tool-call budget, or after rejecting excess calls from a round, send the next request without tools to force a final response.
- **Tool-result budget**: Rebuild the request context after every tool round and bound each result from the remaining input budget so tool output cannot consume the final-response space.
- **Continuous context**: Preserve the latest complete user turn and its assistant/tool messages atomically; never skip a recent turn to include an older one.
- **Transcript persistence**: Emit and persist every assistant `tool_calls` message and matching tool result before continuing the loop.
- **Timeout**: Overall timeout for the entire agentic flow (e.g., 120 seconds)
- **User cancellation**: Allow the user to stop the loop at any point
- **Error in tool execution**: Return error message as tool content, let the model handle it

## Model Compatibility

### Checking Support

The `GET /model/info` endpoint provides capability flags:

```json
{
  "model_info": {
    "supports_function_calling": true,
    "supports_parallel_function_calling": true
  }
}
```

- Route every message for a model with `supports_function_calling: true` through `AgentStreamUseCase`; agent routing is automatic and is not controlled by a separate agent-mode toggle.
- Preserve `supports_parallel_function_calling` as model metadata. The current agent loop does not use it to gate concurrent local execution.
- Models without function calling use regular streaming. The web-search control is unavailable for those models.

### Provider Notes

| Provider | Tool Calling | Parallel | Notes |
|----------|-------------|----------|-------|
| OpenAI (GPT-4, GPT-4o) | ✅ | ✅ | Full support |
| Anthropic (Claude 3.5+) | ✅ | ✅ | Uses OpenAI format via LiteLLM |
| Ollama (Llama 3.1+, Qwen 2.5+) | ✅ | ❌ | Depends on model; check model_info |
| Groq | ✅ | ✅ | Full support |
| Mistral | ✅ | ✅ | Full support |

## Implementation Architecture

### Models

```swift
// Extend the existing ChatMessage and API models

// Tool call in assistant response
struct ToolCall: Codable, Sendable, Equatable, Identifiable {
    let id: String
    let type: String  // Always "function"
    let function: ToolCallFunction
}

struct ToolCallFunction: Codable, Sendable, Equatable {
    let name: String
    let arguments: String  // JSON string, must be parsed
}

// Tool result message (role: "tool")
// Extend ChatMessage.Role to include .tool
// Add toolCallId property to ChatMessage for role == .tool
// Add toolCalls property to ChatMessage for assistant messages with tool calls
```

### Tool Registry

```swift
// Shared/Features/Chat/Models/ChatTool.swift

nonisolated struct ToolExecutionResult: Sendable {
    let text: String
    let searchResults: [LiteLLMSearchResult]?

    init(text: String, searchResults: [LiteLLMSearchResult]? = nil) {
        self.text = text
        self.searchResults = searchResults
    }
}

protocol ChatToolProtocol: Sendable {
    var definition: ToolDefinition { get }
    func execute(arguments: String) async throws -> ToolExecutionResult
}

struct ToolDefinition: Codable, Sendable {
    let type: String  // "function"
    let function: ToolFunctionDefinition
}

struct ToolFunctionDefinition: Codable, Sendable {
    let name: String
    let description: String
    let parameters: ToolParameters
}
```

The default registry always includes `get_current_datetime`. Outside Private Chat it also includes `save_memory` and `delete_memory`. It includes `web_search` only while web search is enabled. When MCP tools are configured on the LiteLLM server and enabled by the user, each enabled tool is wrapped in an `MCPTool` instance (conforming to `ChatToolProtocol`) and added to the registry. `ToolRegistry.execute` returns an "Unknown tool" result rather than throwing when a name is not registered.

### Agentic UseCase

```swift
// Shared/Features/Chat/UseCases/AgentStreamUseCase.swift

protocol AgentStreamUseCaseProtocol: Sendable {
    func execute(
        messages: [ChatMessage],
        model: String,
        parameters: ModelParameters,
        contextWindowTokens: Int?,
        toolRegistry: ToolRegistry
    ) -> AsyncThrowingStream<AgentEvent, Error>
}

enum AgentEvent: Sendable {
    case token(String)
    case reasoning(String)
    case toolCallStarted(ToolCall)
    case toolCallCompleted(toolCallId: String, result: String, searchResults: [LiteLLMSearchResult]?)
    case transcriptAppended([ChatMessage])
    case usage(TokenUsage)
    case promptUsage(Int)
    case image(Data)
    case completed
}
```

The use case manages non-streaming completion requests for the full loop, then emits final content and reasoning in small chunks for the existing streaming UI. Failures terminate the `AsyncThrowingStream`; there is no `.error` event. Assistant tool-call messages and matching tool messages are emitted through `.transcriptAppended` and persisted before the next round.

### ViewModel Integration

`ChatViewModel.streamWithWebSearch` uses `AgentStreamUseCase` whenever the selected model has `.functionCalling`, whether or not web search is enabled. It uses `StreamMessageUseCase` only for models without that capability. Web search changes the registry contents; it does not select agent routing.

## Streaming Considerations

Tool calling and streaming can interact in two ways:

### Current Behavior

- Agent rounds use non-streaming chat completions.
- Final content and reasoning are chunked locally into `AgentEvent` values.
- Tools remain present after a normal tool round, allowing multiple rounds. They are omitted only when forcing a final response because of iteration or tool-call safeguards, or when an empty/`{}` model response requires a final retry.

### Streaming Tool Calls (Advanced)

- LiteLLM streams tool call deltas: `delta.tool_calls[0].function.arguments` builds up incrementally
- Must accumulate argument fragments before parsing JSON
- More complex but provides real-time feedback

Do not implement streamed tool-call deltas unless the repository and event contract are deliberately changed and covered by tests.

## UI Design

### Automatic Agent Routing

- There is no separate Tools or Agent toggle.
- Function-calling models automatically receive the default registry.
- The globe control independently adds or removes `web_search` and requires both a configured search tool and a function-calling model.

### Tool Execution Feedback

During an agentic loop, show the user what's happening:

```
┌─────────────────────────────────────────────┐
│ 🔍 Searching the web...                     │
│    "Swift programming latest news 2026"     │
│ ✅ Found 5 results                          │
│                                              │
│ 🤖 Generating response...                   │
│    Based on the search results, here are... │
└─────────────────────────────────────────────┘
```

- Show each tool call as a collapsible step in the message
- Use icons: 🔍 for search, ⚙️ for tools, ✅ for completed
- Allow expanding to see tool arguments and results
- Show a "thinking" indicator during each loop iteration

### Message Display

- Assistant messages with `tool_calls` should show a "Used tools" indicator
- Tool result messages are internal — don't display them directly, but show a summary
- The final assistant message displays normally with the grounded response

## Conversation Persistence

When persisting conversations with tool calling:

- Store `tool_calls` array in assistant messages (already `Codable`)
- Store tool result messages with `role: "tool"` and `tool_call_id`
- On reload, the full message history (including tool results) must be preserved
- Do NOT resend tools array when loading historical conversations (no new tool calls on old messages)

## Error Handling

- **Invalid JSON in arguments**: Return error to model as tool result, let it retry
- **Tool execution failure**: Return error description as tool content
- **Model doesn't support tools**: Fall back to regular chat (no tools parameter)
- **Loop stuck**: The final iteration omits tools; another tool-call response throws `AgentStreamError.iterationLimitReached`, while an invalid forced-final response throws `.invalidResponse`.
- **Network error during tool execution**: Show error, allow retry
- **Unknown tool name**: Return "Unknown tool" as result, model can self-correct

## Security

- **Argument validation**: Parse and validate tool arguments before execution
- **No arbitrary code execution**: Tools are predefined, no dynamic tool loading
- **Rate limiting**: Apply rate limits to tool executions (especially web search)
- **Content sanitization**: Sanitize tool results before injecting into messages
- **Tool scope**: Function-calling models receive built-in datetime and, outside Private Chat, memory tools automatically. Web search remains explicit opt-in through its toggle.

## Relationship with Web Browsing

Web search (`web_search`) is the **first and primary tool** in the agent system:

- A model with `.functionCalling` always uses the agent loop. When web search is ON, `web_search` joins the default registry and executes through `/v1/search/{search_tool_name}`.
- Web search cannot be enabled unless the model has `.functionCalling` and a search tool name is configured; an unavailable globe is shown in red.
- When web search is OFF, function-calling models still use the agent loop with datetime and eligible memory tools. Models without `.functionCalling` use regular streaming.

## MCP Tools

MCP (Model Context Protocol) tools are external tools provided by MCP servers configured on the user's LiteLLM backend. They are discovered, persisted, and executed through a dedicated client-side pipeline that integrates transparently with the agent loop.

### Discovery

- `FetchMCPToolsUseCase.execute()` (never throws, returns `[]` on failure) calls `GET /v1/mcp/server` to list configured MCP servers, then concurrently calls `GET /mcp-rest/tools/list?server_id=X` for each server.
- Discovered tools are stored in `ChatViewModel.LoadedState.availableMCPTools` and populated during `fetchAndBuildInitialState()` alongside model data.
- If the server does not expose MCP endpoints, the use case returns `[]` and `isMCPSupported` remains `false`.

### Tool Definition Conversion

Each `MCPToolInfo` is wrapped in an `MCPTool` that conforms to `ChatToolProtocol`. `MCPTool.toolParameters(from:)` converts the `MCPJSONSchema` (recursive JSON Schema class) into the flat `ToolParameters` format used by the agent loop:

- Top-level `type` and `required` are forwarded directly.
- Nested property schemas are resolved to a `type` string (e.g. `"array of string"` for arrays with items).
- Complex nested schemas beyond surface depth are described through their textual descriptions rather than full schema fidelity.

### Execution

- `MCPTool.execute(arguments:)` delegates to `MCPRepository.executeTool()` → `APIClient.callMCPTool()` → `POST /mcp-rest/tools/call`.
- The request body includes `server_id`, `name` (the original un-prefixed tool name), and `arguments` parsed from the JSON string the LLM produced.
- The response `content` items are joined and returned as a `ToolExecutionResult`.

### User Management

- An MCP antenna icon next to the web search globe opens the `MCPToolsSheet`.
- The sheet lists every discovered tool with a toggle; toggling a tool persists the `enabledMCPToolIds` set via `SettingsManager`.
- The `ChatViewModel+Agent.makeToolRegistry()` method reads the enabled set and only injects activated `MCPTool` instances.
- The system prompt in `buildAgentSystemPrompt()` includes a short description line for each enabled MCP tool.
- A corresponding MCP section in Settings allows the same tool management and re-fetch from a Settings context.

### Relationship with Web Search

- MCP tools and web search are independent: a model with `.functionCalling` can use both simultaneously.
- Web search requires a configured search tool in Settings and the web search toggle to be on.
- MCP tools require the LiteLLM server to have at least one MCP server configured and individual tools to be enabled in the MCP Tools sheet.
- Both are integrated through the same `ToolRegistry` → `AgentStreamUseCase` pipeline.
- See `web-browsing.instructions.md` for the full flow table and implementation details
