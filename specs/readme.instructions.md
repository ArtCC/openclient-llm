---
description: "Use when updating the README, adding badges, updating the architecture diagram, documenting new features, or changing project documentation."
applyTo: "**/README.md"
---

# README Structure

The README follows this exact structure in order:

1. **Icon** — Centered app icon image (`assets/icon_radius.png`, width 128)
2. **Title** — Project name as centered H1
3. **Badges** — shields.io badges (Platform, Swift, SwiftUI, License, Xcode) using `flat-square` style
4. **Description** — Brief explanation of what the project is (2–3 sentences max)
5. **Technologies** — Two-column markdown table: Technology | Purpose
6. **Architecture** — Short paragraph summarising the pattern + link to `ARCHITECTURE.md`
7. **Usage** — Setup steps + Requirements subsection + Self-hosting guides subsection
8. **License** — GNU Affero General Public License v3.0 with link
9. **Author** — Name and links

## Linked files

`README.md` references two companion documents. **Both must be kept in sync** whenever the project structure or architecture changes:

### ARCHITECTURE.md

- Contains the full project tree (`openclient-llm/`, `openclient-llm-macOS/`, `openclient-llm-test/`) with every source file listed
- Contains the layer diagram (`View → ViewModel → UseCase → Repository → APIClient / LocalStorage`)
- Contains per-layer responsibility descriptions

**When to update `ARCHITECTURE.md`:**
- A new feature folder is added under `Shared/Features/`
- A new file is added to any existing feature (Model, Repository, UseCase, ViewModel, View)
- A new Core component is added (`Managers/`, `Networking/`, `Extensions/`, `Utils/`)
- A new macOS-specific view or app entry point is added
- A new test file is added under `openclient-llm-test/`

**Style rules for `ARCHITECTURE.md`:**
- Use the existing tree style with `├──`, `│`, `└──` box-drawing characters
- File names are listed without inline comments unless the purpose is non-obvious
- Keep the layer diagram at the top unchanged unless the architecture itself changes
- Section order: layer diagram → `openclient-llm/` tree → `openclient-llm-macOS/` tree → `openclient-llm-test/` tree → per-layer descriptions

### README.md Architecture section

The Architecture section in `README.md` is intentionally brief — it describes the pattern in one paragraph and delegates detail to `ARCHITECTURE.md` via a link. Do **not** duplicate the full tree in `README.md`.

## Rules

- Badges use shields.io `flat-square` style; keep platform/Xcode version badges in sync with deployment targets
- Description should be concise — 2–3 sentences max
- Usage must cover: clone, open in Xcode, configure server URL, run; plus Requirements (Xcode version, OS version, backend)
- Never remove the Self-hosting guides subsection
- When a new feature is added, update the Technologies table only if a new technology or framework is introduced