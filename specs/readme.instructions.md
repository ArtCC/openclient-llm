---
description: "Use when updating the README, adding badges, updating the architecture diagram, documenting new features, or changing project documentation."
applyTo: "**/README.md"
---

# README Maintenance

`README.md` is product documentation, not a fixed nine-section template. Preserve its current voice and broad ordering
unless a deliberate documentation redesign is requested.

The current README includes: centered icon/title/badges, Description and feature groups, website/download links,
Screenshots, Technologies, Architecture, Usage/Requirements/Self-hosting, License, Contributing, Feedback, Author, and a
closing product statement.

## Linked files

`README.md` links to `ARCHITECTURE.md` for structural detail. Keep the two consistent when a change materially affects
the architecture described to contributors.

### ARCHITECTURE.md

- Contains a representative structural tree for all five targets: `openclient-llm`, `openclient-llm-macOS`,
  `openclient-llm-test`, `ShareExtension`, and `WidgetsExtension`
- Contains the layer diagram (`View → ViewModel → UseCase → Repository → APIClient / LocalStorage`)
- Contains per-layer responsibility descriptions

**When to update `ARCHITECTURE.md`:**
- A new feature folder is added under `Shared/Features/`
- A layer, target, top-level directory, feature module, or platform ownership rule changes
- A Core area is added, removed, or changes responsibility
- Extension/App Group data flow or target relationships change materially

Do not update `ARCHITECTURE.md` merely because an implementation file or test file is added inside an already documented
folder. Its tree is intentionally directory-level with selected explanatory file names, not a complete file manifest.

**Style rules for `ARCHITECTURE.md`:**
- Use the existing tree style with `├──`, `│`, `└──` box-drawing characters
- File names are listed without inline comments unless the purpose is non-obvious
- Keep the layer diagram at the top unchanged unless the architecture itself changes
- Keep target names, paths, layer descriptions, and data-flow diagrams aligned with the Xcode project and current code.
  Preserve the existing section order when possible; add focused sections only when they help explain a real subsystem.

### README.md Architecture section

The Architecture section in `README.md` is intentionally brief — it describes the pattern in one paragraph and delegates detail to `ARCHITECTURE.md` via a link. Do **not** duplicate the full tree in `README.md`.

## Rules

- Badges use shields.io `flat-square` style; keep platform/Xcode version badges in sync with deployment targets
- Keep the opening product description concise, then maintain the existing feature groups as shipped behavior changes.
- Usage must cover clone, open in Xcode, configure a server URL, and run, plus current toolchain/platform/backend
  requirements.
- Never remove the Self-hosting guides subsection
- When a new feature is added, update the Technologies table only if a new technology or framework is introduced
- Update screenshots, download links, and extension/widget claims when shipped product behavior changes.
