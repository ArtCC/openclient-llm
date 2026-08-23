---
description: "Use when adding anything to CHANGELOG.md, choosing a release version or build number, or synchronizing app, TestFlight, and Remote Config version references."
applyTo: "{CHANGELOG.md,README.md,TestFlight/*.txt,config.json,config-dev.json,openclient-llm.xcodeproj/project.pbxproj}"
---

# Release Version Workflow

Read this specification together with `changelog.instructions.md` whenever a request adds or changes a changelog entry.
A numbered changelog release is an atomic version update: keep every active app-version reference listed below in sync.

## Required Questions

Before editing `CHANGELOG.md`, inspect its latest numeric release header and ask for any of the following information the
user has not already supplied:

1. What marketing version to use (`MAJOR.MINOR.PATCH`).
2. What build number to use.

Ask these as distinct, concise questions in the user's language; they may be grouped into one message. Mention the current
latest version and build as context. Do not infer or increment either value, and do not start the changelog or version edit
until both decisions are known.

If the user explicitly wants an `Unreleased` entry, confirm that choice instead of requiring a numeric version and build.
An `Unreleased` entry does not change TestFlight notes or any active app-version reference.

## Changelog Release

- Format a numbered header as `## [MAJOR.MINOR.PATCH-build-N] - YYYY-MM-DD`.
- Use the exact version and build chosen by the user; normalize a bare build number such as `78` to `build-78`.
- Use the current date unless the user supplies a different release date.
- Follow `changelog.instructions.md` for section order, entry wording, and what belongs in the changelog.
- When adding to the current marketing version, keep one latest release section and use the chosen build and date rather
  than creating a duplicate section for the same marketing version.

## Active Version Synchronization

For every numbered changelog release, locate the active references before editing and synchronize the chosen marketing
version in all of these places:

1. The latest release header in `CHANGELOG.md`, together with the chosen build number.
2. Every existing `TestFlight/*.txt` file, following the TestFlight rules below.
3. `MARKETING_VERSION` for the iOS app, macOS app, Share Extension, `WidgetsExtension-iOS`, and
   `WidgetsExtension-macOS` in
   `openclient-llm.xcodeproj/project.pbxproj`, for both Debug and Release configurations.
4. Both the badge URL and alt text of the version badge in `README.md`.
5. `app_update.ios.latest_version` and `app_update.macos.latest_version` in the existing local `config.json` and
   `config-dev.json` files, even when their update notification is disabled.

Do not rely only on a blind repository-wide replacement. Search for the previous active version and classify each match so
historical releases and unrelated version numbers remain unchanged.

## Values That Must Remain Stable

- Keep every shipping target's checked-in `CURRENT_PROJECT_VERSION` at `1`. Deployment increments the published build
  automatically; the user-supplied build number belongs in the changelog header.
- Keep the unit-test target's `MARKETING_VERSION` at `1.0.0`.
- Do not synchronize release versions into tests or mocks. Version-comparison fixtures use `1.0.0` for the current and
  default version, `1.1.0` for a newer version, and `0.9.0` for an older version.
- Do not change historical changelog headers or entries.
- Do not change project object versions, schema versions, backup-format versions, deployment targets, package versions, or
  other numbers that are not the active app marketing version.
- Keep `config.json` and `config-dev.json` ignored by Git. Never force-add them to a commit.

## TestFlight Release Notes

Update every existing file matching `TestFlight/*.txt` for each numbered changelog release; do not ask a separate
TestFlight question and do not create new locale files. Preserve each file's language, greeting, closing text, bullet
character, punctuation, and overall layout. TestFlight notes are user-facing, so adapt changelog content into concise
product language instead of copying technical details verbatim.

### Starting a new marketing version

When the requested marketing version differs from the current `***MAJOR.MINOR.PATCH:` heading in a TestFlight file:

1. Replace that heading with the requested marketing version; TestFlight headings do not include the build number.
2. Replace the current-version notes with the new version's notes.
3. Move the previous version's substantive, version-specific bullets to the beginning of the `***Recent Updates:` section,
   preserving their order.
4. Keep the generic `• Minor bug fixes and improvements for a smoother experience.` bullet as the current-version fallback
   when appropriate; do not move or duplicate it in `***Recent Updates:`.

### Adding to the current marketing version

When the requested marketing version matches the current TestFlight heading, keep the heading and `***Recent Updates:`
section in place. Add the new substantive bullets to the current-version block, before the generic minor-fixes fallback.

Do not deduplicate, rewrite, reorder, or prune older `***Recent Updates:` entries as part of an unrelated release update.

## Remote Config Decisions

The local `config.json` and `config-dev.json` files are release-management copies of Remote Config. Their
`latest_version` values follow the active app marketing version automatically, but their behavior flags and banner content
require explicit decisions. Do not assume that production and development should use the same settings merely because the
files are currently identical.

Before editing the Remote Config files for a numbered release, ask:

1. Whether update notifications should be enabled and whether the update should be forced, separately for production and
   development when needed. Never enable `force_update` without explicit confirmation.
2. Whether the banner should be kept unchanged, disabled, or replaced with a new banner.
3. Whether the resulting banner and activation state should apply to `config.json`, `config-dev.json`, or both.

Keeping a banner unchanged means preserving its `dismiss_banner_key`, localized items, activation, and any version text in
its title. Do not mechanically replace version numbers inside an existing banner. Disabling a banner changes its `active`
state but preserves its content unless the user asks to remove or replace it.

### New banner questions

When the user chooses a new banner, ask for any information not already supplied:

- The feature or message to announce, or permission to derive it from the new changelog entries.
- Platforms: iOS, macOS, or both.
- Whether the banner is active in each selected Remote Config file.
- Emoji, title, subtitle, CTA label, and action.
- The destination URL when the action is `open_url`.
- Which locales to include or whether to adapt the copy for every locale already present in the file.

Generate a new `dismiss_banner_key` from the release version and a concise stable slug unless the user supplies one, for
example `release-1.6.30-chat-streaming`. A new key makes the banner visible again to users who dismissed an older banner;
never change it merely to re-show unchanged content.

### Valid banner actions

Only these exact, case-sensitive JSON values are supported:

| JSON value | Behavior |
|---|---|
| `close` | The CTA dismisses the banner. |
| `open_url` | Opens the item's URL inside the app, then dismisses the banner. |
| `feedback` | Opens the Feedback presentation in Settings, then dismisses the banner. |
| `tip` | Opens the Tip Jar presentation in Settings, then dismisses the banner. |

- Unknown action values make the entire Remote Config fail to decode; never invent or approximate an action name.
- `open_url` requires a valid `http` or `https` URL. An invalid or unsupported URL only dismisses the banner.
- For actions other than `open_url`, use an empty `url` unless the user has a reason to preserve another value.
- An empty `cta` hides the action button. The separate close button always dismisses the banner regardless of its action.
