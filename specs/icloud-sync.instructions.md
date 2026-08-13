---
description: "Use when implementing or changing iCloud synchronization, iCloud Documents storage, conflict resolution, cloud availability, or cloud data management."
---

# iCloud Documents Synchronization Contract

## Scope

This specification is the authoritative contract for OpenClient synchronization through the app's private iCloud
Documents container. It covers conversations, attachments, the user profile, memory items, custom prompt templates, and
the metadata required to reconcile or delete them.

The synchronization implementation must remain file based through `Codable` and `FileManager`. SwiftData, CloudKit
records, third-party databases, and a server-side synchronization service are outside the scope of this feature.

## Implementation Status

The file-based iCloud Documents synchronization stabilization was completed in this order:

- [x] Synchronization contract, runtime-state contract, and compatible schema versioning.
- [x] Testable serialized storage infrastructure and critical correctness fixes.
- [x] Consistent reconciliation for conversations, attachments, profile, memory, and prompt templates.
- [x] Accurate Settings state and user communication.
- [x] Cloud inventory plus durable individual and global deletion.
- [x] Automated two-device coverage.

## Core Guarantees

- Existing local and cloud JSON files are user data and must remain readable across upgrades.
- Synchronization must never infer deletion from an empty directory, a missing file, an unavailable container, a pending
  iCloud download, a decoding failure, or an unsupported schema.
- A write or delete may begin only after all metadata that can affect its reconciliation decision is current.
- Repeating the same synchronization with unchanged inputs must produce the same result and no additional writes.
- At most one synchronization operation may mutate local or cloud state at a time. Triggers received during a run are
  coalesced into at most one follow-up run.
- User data may be permanently deleted only after an explicit user action or after applying durable deletion metadata
  created by such an action.
- No iCloud file operation may block the main actor.
- A failure in one data category must be reported. It must not be converted into global success or silently discarded.

## Storage Backend

Both app targets use the private ubiquity container `iCloud.com.artcc.openclient-llm` with the `CloudDocuments` service.
The developer and the configured LiteLLM server have no access to this container.

The current Version 1 layout under the container's `Documents` directory is:

```text
Documents/
  Conversations/<conversation UUID>.json
  Attachments/<conversation UUID>/<attachment file>
  ConversationTombstones/<conversation UUID>.json
  ConversationTombstones.json
  ConversationDeleteAll.json
  UserProfile.json
  UserProfileDeletion.json
  PromptTemplates/<template UUID>.json
  PromptTemplateTombstones/<template UUID>.json
  Memory.json
  MemoryTombstones.json
  CloudPurgeMarker.json
  SyncManifest.json
```

`ConversationTombstones.json` is the legacy aggregate tombstone file. Readers must continue to merge it with per-record
tombstones while it can exist in shipped installations. New user data must not be stored in synchronization metadata.
`CloudPurgeMarker.json` is the verified global deletion barrier shared by every category. It is synchronization metadata,
not an independently manageable user record.

## Schema Versioning

Version 1 is the current storage schema. A missing `SyncManifest.json` means legacy Version 1 and is valid. The absence of
the manifest must never make the container look empty or unsupported.

When written, the additive manifest has this schema:

```json
{
  "format": "com.artcc.openclient-llm.icloud-sync",
  "schemaVersion": 1,
  "minimumReaderVersion": 1
}
```

Manifest rules:

- `format` must match exactly.
- `schemaVersion` describes the layout written by the newest participating app.
- `minimumReaderVersion` is the oldest implementation allowed to mutate that layout.
- Unknown fields are ignored for forward-compatible additive changes.
- A malformed manifest, an unknown format, or an unsupported version puts synchronization into a read-only failure state.
  The app must not write, migrate, or delete cloud files in that state.
- An incompatible layout change requires an incremented schema version and an explicit, tested migration.
- Migration writes the new representation first, reads it back, validates it, and only then records completion.
- Files that would be replaced or removed during migration must first be copied to local recovery storage outside the
  iCloud container. Corrupt or unrecognized files are preserved and reported.
- Cleanup of a previous representation is deferred until the new representation has completed verified synchronization.

## User Intent And Runtime State

The persisted `isCloudSyncEnabled` setting represents only user intent. It does not mean that iCloud is available or that
data is synchronized.

Runtime state is ephemeral and has these semantic states:

| State | Meaning |
|---|---|
| `disabled` | User intent is off. No observers, retries, downloads, writes, or deletes are active. |
| `checkingAvailability` | The app is resolving account, container, schema, and initial metadata state. |
| `idle` | User intent is on and the container is usable, but no complete successful run is currently asserted. |
| `synchronizing` | A serialized reconciliation is in progress. |
| `waitingForDownloads` | Required ubiquitous items are not current; their downloads have been requested and no writes are allowed. |
| `synchronized` | Every enabled data category completed successfully in the same run. |
| `unavailable` | The account or container cannot currently be used. User intent may remain on. |
| `failed` | A non-pending operation failed. The error and affected categories are retained for UI and retry. |

Rules for state and settings:

- Availability and runtime state are never persisted as if they were user preferences.
- The last successful synchronization date is local diagnostic state, not proof that the current container is available.
- Turning synchronization off must always be possible, including while iCloud is unavailable.
- Turning synchronization off cancels pending work and stops observers. It does not delete local or cloud data.
- Enabling synchronization performs availability, schema, and metadata preflight before any user data write.
- `synchronized` describes conversations, attachments, profile, memory, and templates together. A conversation-only result
  must never be presented as global synchronization success.

## Reconciliation Rules

All categories follow these common rules:

1. Resolve the container and validate the manifest.
2. Gather metadata and request required placeholder downloads.
3. If required input is pending, return `waitingForDownloads` without writing user data.
4. Decode local data, cloud data, and deletion metadata independently.
5. Merge logical records deterministically.
6. Persist local output and verify it.
7. Persist cloud output through coordinated atomic writes and verify it.
8. Apply durable deletions only after their metadata is safely stored.
9. Return a per-category result and derive the global runtime state.

An item present only locally is uploaded unless durable deletion metadata rejects it. An item present only in iCloud is
downloaded unless durable deletion metadata rejects it. An empty side contributes no records; it is not an instruction to
remove records from the other side.

Category identity and conflict rules:

- Conversations are records keyed by `Conversation.id`. The newest valid `updatedAt` wins. A tombstone rejects only a
  version that is not newer than its deletion date.
- Attachments are children of a conversation and are never reconciled as independent user records. Referenced files are
  materialized; unreferenced cloud folders are cleaned only after the parent reconciliation is verified.
- Memory is merged by `MemoryItem.id`, not by treating `Memory.json` as an indivisible winner. Item updates require a
  modification value and item deletions require durable metadata.
- Custom prompt templates are records keyed by `PromptTemplate.id`. Built-in templates are never cloud user data. Template
  updates require a modification value and deletions require durable metadata.
- The profile is a singleton record. Its modification metadata and deletion marker determine the winner. If an automatic
  choice cannot be made safely, the conflict UI must explicitly refer only to the profile.
- Equal modification values with different content are conflicts. Resolution must be deterministic and the losing valid
  representation must remain recoverable.

## Deletion Rules

- Individual deletion writes durable deletion metadata before removing the corresponding local or cloud data.
- Deletion metadata is merged using the newest deletion date and is intentionally retained so an offline device cannot
  resurrect old content.
- A delete-all operation writes its purge marker before deleting any category.
- A purge marker rejects records whose modification value is not newer than the marker. Records created or deliberately
  updated after the purge remain eligible to synchronize.
- Delete operations are idempotent. An already absent payload is success only when its required deletion metadata exists.
- The cloud-management UI uses synchronized deletion semantics: deletion affects iCloud and all synchronized devices.
  Removing only a cloud copy while synchronization remains active is not supported because another device can re-upload it.
- Internal manifests, tombstones, and purge markers are not presented as independently deletable user records.

## Availability And Observation

- Availability requires a valid ubiquity identity and a resolvable container URL, but these checks are runtime snapshots,
  not permanent facts.
- The app observes ubiquity identity changes and re-checks availability when becoming active.
- Metadata observation starts only when user intent is enabled and the container is available. It stops when either ceases
  to be true and can start again later.
- Initial metadata gathering always establishes a baseline. Starting while synchronization is disabled must not leave an
  observer that can neither emit nor restart.
- Metadata events are debounced and coalesced. Writes generated by the app may trigger observation, but idempotent file
  comparison and the serialized coordinator must prevent feedback loops.

## Error And Recovery Contract

- Errors distinguish unavailable account/container, pending download, unsupported schema, invalid data, coordinated file
  access failure, insufficient storage, and partial category failure.
- Transient failures may retry with bounded backoff. Permanent failures wait for explicit user action or a relevant system
  event. Disabling synchronization cancels retries.
- Raw file paths, profile content, memory content, conversation content, and attachment content must not be logged.
- A valid representation that loses conflict resolution is copied to local recovery storage before it can be replaced.
- Automatic recovery never uploads an unvalidated file.

## User Communication

Settings must communicate user intent and runtime state separately. It must identify all synchronized categories, show
pending downloads and failures, retain the last successful date, and provide retry when appropriate. Manual synchronization
must cover every category; otherwise it must be labeled with the category it actually affects.

Destructive actions require confirmation that explains their device-wide synchronized effect. A partial delete must list
the categories that failed and remain retryable; it must not report that all data was deleted.

## Certification Requirements

A synchronization behavior is not complete until it has:

- Unit tests against an injectable temporary cloud root.
- Deterministic two-device tests with separate local roots and a shared cloud root.
- Tests for local-only, cloud-only, equal, divergent, pending, unavailable, corrupt, deleted, and repeated inputs.
- iOS and macOS verification.
- Manual validation with two app installations using a real test iCloud account for placeholder and metadata behavior that
  cannot be faithfully reproduced by the local test harness.
