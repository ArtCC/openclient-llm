---
description: "Use when updating the CHANGELOG, adding entries for new features, bug fixes, or changes, deciding what to document, or reviewing changelog format."
applyTo: "**/CHANGELOG.md"
---

# Changelog Guidelines

## Format

The changelog follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

### Version header

```markdown
## [MAJOR.MINOR.PATCH-build-N] - YYYY-MM-DD
```

- `MAJOR.MINOR.PATCH` follows SemVer
- Released headers append `-build-N` inside the brackets (e.g. `## [1.4.5-build-57] - 2026-07-15`). Treat this as the project version format even though the build suffix is not SemVer build metadata.
- Date is ISO 8601 (e.g. `2026-04-03`)
- Unreleased work goes under `## [Unreleased]` at the top

### Sections (in order, omit empty ones)

```markdown
### Added
### Changed
### Deprecated
### Removed
### Fixed
### Security
```

## Entry Style

- Prefer one entry per bullet (`-`). Existing releases sometimes use nested bullets for a single grouped feature such as widget variants; preserve that historical structure and use it only when it materially improves clarity.
- Start with a noun or past-tense verb describing what changed, not who changed it
- Be specific: include the affected type, file, or feature name where helpful
- Do not mention PR numbers, commit hashes, or author names
- Keep entries concise — one sentence max
- Group related entries under the same section, not by file or layer

**Good:**
```
- Pull-to-refresh in the Models screen (iOS/iPadOS)
- `LogManager` debug logging system with emoji-differentiated log levels — only active in DEBUG builds
- Keychain queries updated to include `kSecUseDataProtectionKeychain: true` on all operations
```

**Bad:**
```
- Fixed a bug
- Updated some files
- Refactored ChatViewModel (see PR #42)
```

## What to Document

### Always document
- New user-facing features or UI changes
- New public types, protocols, or APIs added to Shared/
- Behaviour changes that affect the user experience
- Bug fixes visible to the user
- Security fixes
- Breaking changes to internal contracts (Repositories, UseCases, Managers)
- New platform support or deployment target changes
- New localization languages

### Do not document
- Internal refactors with no behaviour change (e.g. extracting a private method)
- Test additions or changes — unless fixing a previously untested bug
- SwiftLint or formatting-only changes
- Changes to `.gitignore`, CI scripts, or dev tooling (unless they affect contributors)
- Documentation-only changes (README, instructions files, prompts)

## When to Update

Update `CHANGELOG.md` when:
- A feature is fully implemented and tested
- A bug fix is confirmed working
- A breaking change is introduced

Do **not** update the changelog speculatively or mid-implementation.

## Unreleased Section

Use `## [Unreleased]` for changes not yet assigned to a build number:

```markdown
## [Unreleased]

### Added
- ...

### Fixed
- ...
```

When a build is released, replace `[Unreleased]` with the version + date.

## Rules

- Do not rewrite historical entries merely for tone, punctuation, formatting, or to match newer conventions.
- Narrow historical corrections are allowed when current code or an authoritative release artifact proves an entry factually wrong (for example, storage location, endpoint, default value, or shipped widget behavior). Keep the original release placement, change only the inaccurate wording, and do not recast unreleased work as shipped.
- Never group multiple distinct changes into a single bullet
- The most recent version always appears at the top
- Keep the introductory paragraph (Keep a Changelog + SemVer links) unchanged
- Historical sections contain style and factual inconsistencies. Do not copy an inconsistency into a new release, and do not perform a bulk cleanup while making an unrelated changelog update.
