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

- Execute all tool calls (can be done concurrently with `TaskGroup`)
- Send ALL results back in one request, each with its matching `tool_call_id`
- Check `supports_parallel_function_calling` from model info

### Loop Safety

- **Maximum iterations**: Cap the loop at 10 iterations to prevent infinite loops
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

- Only show agent mode toggle for models with `supports_function_calling: true`
- Only enable parallel execution for models with `supports_parallel_function_calling: true`
- Models without function calling (e.g., some Ollama models) should hide/disable agent features

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
// Shared/Features/Chat/Models/Tool.swift

protocol ChatTool: Sendable {
    var definition: ToolDefinition { get }
    func execute(arguments: String) async throws -> String
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

Built-in tools to implement:
- **`web_search`**: Web search integration via LiteLLM (see web-browsing.instructions.md). Uses a generic name to avoid triggering LiteLLM's `websearch_interception` callback, which may interfere with providers like Ollama.
- Future: calculator, code execution, file operations, etc.

### Agentic UseCase

```swift
// Shared/Features/Chat/UseCases/AgentStreamUseCase.swift

protocol AgentStreamUseCaseProtocol: Sendable {
    func execute(
        messages: [ChatMessage],
        model: String,
        tools: [ToolDefinition]
    ) -> AsyncThrowingStream<AgentEvent, Error>
}

enum AgentEvent: Sendable {
    case token(String)                           // Streaming text token
    case toolCallStarted(ToolCall)               // Model requested a tool call
    case toolCallCompleted(String, String)        // toolCallId, result
    case completed                                // Final response done
    case error(String)                           // Error message
}
```

The use case manages the full agentic loop internally, emitting events for the UI.

### ViewModel Integration

The `ChatViewModel` needs to:
1. Detect if agent mode is enabled for the conversation
2. Use `AgentStreamUseCase` instead of `StreamMessageUseCase` when tools are active
3. Handle `AgentEvent` updates to show tool execution progress in the UI

## Streaming Considerations

Tool calling and streaming can interact in two ways:

### Non-Streaming Tool Calls (Recommended for v1)

- Send request with `stream: false` during the agentic loop
- Only stream the **final response** after all tool calls are resolved
- Simpler to implement, easier to manage the loop

### Streaming Tool Calls (Advanced)

- LiteLLM streams tool call deltas: `delta.tool_calls[0].function.arguments` builds up incrementally
- Must accumulate argument fragments before parsing JSON
- More complex but provides real-time feedback

> **Recommendation**: Start with non-streaming for tool call rounds, stream only the final answer.

## UI Design

### Agent Mode Toggle

- Show a "Tools" or "Agent" chip/toggle near the input bar (next to web browsing toggle)
- Only visible for models with `supports_function_calling: true`
- When enabled, available tools are shown as small icons/badges

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
- **Loop stuck**: After max iterations, stop and show whatever the model last returned
- **Network error during tool execution**: Show error, allow retry
- **Unknown tool name**: Return "Unknown tool" as result, model can self-correct

## Security

- **Argument validation**: Parse and validate tool arguments before execution
- **No arbitrary code execution**: Tools are predefined, no dynamic tool loading
- **Rate limiting**: Apply rate limits to tool executions (especially web search)
- **Content sanitization**: Sanitize tool results before injecting into messages
- **User consent**: User explicitly enables agent mode; tools don't execute without opt-in

## Relationship with Web Browsing

Web search (`web_search`) is the **first and primary tool** in the agent system:

- When web search is ON + model has `.functionCalling` → Agent mode activates with `web_search` as a registered tool. The app's agentic loop executes the tool via `/v1/search`.
- When web search is ON + model has `.nativeWebSearch` → Uses `web_search_options` in the request body (no agent mode needed)
- When web search is ON + model has no capabilities → **No search occurs**. The globe shows red to inform the user.
- When web search is OFF → Regular streaming, no tools registered
- See `web-browsing.instructions.md` for the full flow table and implementation details