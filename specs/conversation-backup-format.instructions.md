---
description: "Use when exporting, importing, restoring, validating, or versioning OpenClient conversation backups."
applyTo: "openclient-llm/Shared/Features/Chat/**/*.swift"
---

# Conversation Backup Format Specification

## Scope

This specification defines the OpenClient JSON format used to export and restore conversations. It is the authoritative contract for both single-conversation exports and complete backups.

A single-conversation export contains one element in `conversations`. A complete backup contains every conversation available at export time. Both use the same document structure and version.

## Version 1 Schema

```json
{
  "format": "com.artcc.openclient-llm.conversations",
  "version": 1,
  "exportedAt": "2026-07-13T08:00:00Z",
  "conversations": [
    {
      "conversation": { "...": "Persisted Conversation fields" },
      "attachments": [
        {
          "messageId": "UUID",
          "attachmentId": "UUID",
          "data": "base64"
        }
      ]
    }
  ]
}
```

| Field | Type | Required | Definition |
|---|---|---|---|
| `format` | String | Yes | Must equal `com.artcc.openclient-llm.conversations`. |
| `version` | Integer | Yes | The document schema version. Version 1 is the current supported version. |
| `exportedAt` | ISO 8601 date | Yes | Time when the export document was created. |
| `conversations` | Array | Yes | Zero or more exported conversations. |
| `conversation` | Object | Yes | Persisted OpenClient conversation, including messages, parameters, tags, pin state, timestamps, tool data, web search results, branch references, manual context settings, and optional compacted-context metadata. |
| `attachments` | Array | Yes | Portable attachment payloads associated with messages in `conversation`. |
| `attachments[].messageId` | UUID | Yes | Identifier of the message containing the attachment. |
| `attachments[].attachmentId` | UUID | Yes | Identifier of the attachment in that message. |
| `attachments[].data` | Base64 string | Yes | Binary attachment content. |

## Export Rules

- Every export writes the format identifier, current version, and export timestamp.
- Attachment payloads are separate from conversation metadata so their binary content is portable.
- An attachment whose local file cannot be read is omitted from `attachments`; the conversation remains exportable.
- `fileRelativePath` is preserved in conversation metadata for Codable compatibility but is not a portable location and must not be used when restoring.
- Context summaries and their inclusive compacted-message cursor are preserved when present; they are optional so Version 1 imports created before context compaction remain valid.
- `contextWindowTokens` must be absent or greater than zero.
- A context summary and cursor form an indivisible pair; the summary must contain text and the cursor must reference a message in the same conversation.

## Import Rules

- An importer must reject documents whose `format` or `version` is unsupported.
- Conversation IDs and message IDs must be unique across the document.
- Every attachment payload must reference an attachment on the specified message. Duplicate attachment payloads are invalid.
- Imported conversations, messages, and attachments receive new UUIDs. Existing local conversations are never overwritten.
- Imported attachment data is written to a new local path. Exported `fileRelativePath` values are ignored.
- Missing or invalid base64 data omits only that attachment and is reported in the import result.
- Branch references are remapped when the referenced conversation or message is present in the document; external references are removed.
- Invalid context windows, summaries, or summary cursors reject the document before any conversation is restored.
- If a conversation cannot be persisted, its newly written attachments are removed. If a later conversation fails, earlier conversations restored from the same document are rolled back.

## Privacy And Limits

Backup files include full conversation content and raw attachment data. They must only be stored or shared through trusted, encrypted locations.

Version 1 imposes no artificial file or conversation-count limit. Available device storage and memory remain the practical limits.

## Versioning

Incompatible changes require a new integer `version`. Importers must reject unknown versions rather than infer a schema. Any migration support must be explicitly implemented and covered by tests.
