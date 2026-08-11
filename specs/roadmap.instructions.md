---
description: "Use when planning features, prioritizing work, defining scope, or deciding what to implement next in the project roadmap."
---

# Feature Roadmap

## Development Approach

Build incrementally from less to more. Each phase should result in a functional app.

## Current Status

The active planned work is stabilization of file-based iCloud Documents synchronization. The agreed order is:

- [x] Synchronization contract, runtime-state contract, and compatible schema versioning.
- [x] Testable serialized storage infrastructure and critical correctness fixes.
- [ ] Consistent reconciliation for conversations, attachments, profile, memory, and prompt templates.
- [ ] Accurate Settings state and user communication.
- [ ] Cloud inventory plus durable individual and global deletion.
- [ ] Automated two-device coverage and real iCloud certification.

The implementation remains based on Codable, FileManager, and iCloud Documents. See `icloud-sync.instructions.md` for the
authoritative behavior and data-safety requirements.
