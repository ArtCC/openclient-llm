---
name: litellm-integration
description: Use when testing openclient-llm against a real LiteLLM server, OpenAI-compatible endpoint, virtual key, streaming SSE, tool calling, or model integration.
---

# LiteLLM Integration Testing

Use this skill only for opt-in tests against a real LiteLLM deployment.

## Required Input

Ask for both values before making authenticated requests:

1. The exact OpenAI-compatible base URL entered in the app, for example `https://litellm.example.com/v1`.
2. A temporary virtual key with the minimum permissions required for the tests.

Never store either value in source files, `Secrets.xcconfig`, Xcode settings,
test fixtures, Git, or logs. Do not repeat the virtual key in user-facing output.
Tell the user to revoke the key after testing.

## Progressive Test Matrix

Run only the tests enabled by the server configuration and report skipped tests.

1. **Authentication and discovery**: append `models` to the supplied base URL and request it
   (for example `GET /v1/models` when the base URL ends in `/v1`); record model IDs and
   whether authentication succeeds, without exposing the key.
2. **Completion contract**: send a deterministic, short request to
   the base-relative `chat/completions` endpoint; verify the OpenAI-compatible choice, content and usage
   fields.
3. **SSE streaming**: repeat with `stream: true`; verify incremental `data:` chunks,
   a terminal finish reason, and `[DONE]`.
4. **Cancellation**: request a deliberately long response, interrupt the client after
   initial chunks, and verify that cancellation is local, prompt, and produces no
   unexpected retry. Do not claim server-side inference was cancelled unless the server
   explicitly confirms it.
5. **Tool calling**: use a tool-capable model and a harmless synthetic function schema.
   Verify tool-call structure only. Never run a production side-effecting tool against a
   real user account without explicit user approval.
6. **Attachments**: only with explicit approval and non-sensitive sample data, test a
   small image and PDF within application limits. Confirm rejection or omission above
   the limits.
7. **App integration**: only after endpoint checks pass, configure the app in the
   simulator manually for the current session and verify send, stream, stop, edit,
   regenerate, branch, export, and any enabled search tool.

## Execution Rules

- Prefer `curl` with the Authorization header for endpoint checks, using the supplied
  key only for the command that needs it.
- Match app URL construction: endpoints such as `models` and `chat/completions` are
  relative to the user-supplied base URL. Do not add or remove `/v1`; the configured
  base URL owns that prefix.
- Do not write response bodies containing sensitive user data to files.
- Use non-sensitive, deterministic prompts such as `Reply with exactly: integration-ok`.
- Stop immediately on `401`, `403`, certificate failures, or unexpected model behavior;
  report the failure without guessing.
- Keep server-side tests separate from unit tests. Run the app's unit suite before and
  after integration work if application code changes.

## Report Format

Report a compact table with test, endpoint/model, result, and relevant protocol facts.
State clearly which tests were skipped and why. End by reminding the user to revoke the
temporary virtual key.
