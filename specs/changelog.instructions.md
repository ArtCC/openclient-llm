---
description: "Use when updating the CHANGELOG, adding entries for new features, bug fixes, or changes, deciding what to document, or reviewing changelog format."
applyTo: "**/CHANGELOG.md"
---

# Changelog Guidelines

## Format

The changelog follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

### Version header

```markdown
## [MAJOR.MINOR.PATCH-buildN] - YYYY-MM-DD
```

- `MAJOR.MINOR.PATCH` follows SemVer
- `-buildN` suffix is included (e.g. `0.0.1-build-12`)
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

- One entry per bullet (`-`), no sub-bullets
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

- Never delete or rewrite existing entries — only append new ones
- Never group multiple distinct changes into a single bullet
- The most recent version always appears at the top
- Keep the introductory paragraph (Keep a Changelog + SemVer links) unchanged