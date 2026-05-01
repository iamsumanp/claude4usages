# claude4usages — Design

**Date:** 2026-05-01
**Status:** Approved
**Owner:** Suman Pokharel

## Goal

Create a new macOS menu bar app, **claude4usages**, that combines:

- **Everything from ClaudeBar** (`tddworks/ClaudeBar`): Tuist project, layered Domain/Infrastructure/App architecture, Claude provider + probes (`ClaudeUsageProbe`, `ClaudeAPIUsageProbe`, `ClaudePassProbe`), `QuotaMonitor`, theme system (Light, Dark, CLI, Christmas), `JSONSettingsRepository`, hook server, daily-usage analyzer, Sparkle auto-update, system notifications, daily-usage cards.
- **Menu bar icon rendering from Usage4Claude** (`f-is-h/Usage4Claude`): the programmatically drawn shape icons (5h circle, 7d dashed circle, Opus vertical rect, Sonnet horizontal rect, extra-usage hexagon) with display modes (`percentageOnly` / `iconOnly` / `both`) and style modes (`monochrome` / `colorTranslucent` / `colorWithBackground`).

All non-Claude providers (Codex, Gemini, Copilot, Antigravity, Z.ai, Bedrock, Amp, Kimi, Kiro, Cursor, MiniMax, Alibaba, Mistral) are dropped.

## Approach

**Approach A — Fork ClaudeBar; port icon code in; strip non-Claude providers.**

ClaudeBar is the larger, better-architected codebase, so it provides the bones. The Usage4Claude icon renderer is a self-contained ~600 LOC chunk that ports cleanly into ClaudeBar's `App/MenuBar/` directory. SwiftUI `MenuBarExtra` is preserved — its `label:` slot accepts an `Image(nsImage:)`, so we feed it the rendered `NSImage` from the ported renderer; no rewrite to AppKit `NSStatusItem`.

## Architecture

```
claude4usages/
├── Project.swift                  # Tuist project def (renamed from ClaudeBar)
├── Tuist/Package.swift
├── Sources/
│   ├── Domain/                    # unchanged from ClaudeBar
│   │   ├── Provider/
│   │   │   └── Claude/            # only Claude kept; other provider folders deleted
│   │   ├── Monitor/QuotaMonitor.swift
│   │   ├── Settings/
│   │   ├── DailyUsage/
│   │   ├── Session/
│   │   └── Extension/
│   ├── Infrastructure/            # only Claude probes/CLI kept; others deleted
│   │   ├── CLI/                   # ClaudeUsageProbe, ClaudeAPIUsageProbe, ClaudePassProbe, ClaudeDailyUsageAnalyzer
│   │   ├── Storage/JSONSettingsRepository.swift  # provider sub-protocols other than Claude removed
│   │   ├── Hook/
│   │   └── Logging/AppLog.swift   # subsystem renamed
│   └── App/
│       ├── claude4usagesApp.swift # was ClaudeBarApp.swift
│       ├── Info.plist
│       ├── Resources/Assets.xcassets/  # only AppIcon, AppLogo, ClaudeIcon kept
│       ├── Theme/                 # unchanged (Light, Dark, CLI, Christmas)
│       ├── Settings/              # provider-toggle UI removed; MenuBarIconSettingsView added
│       ├── Views/                 # provider-row components for non-Claude removed
│       └── MenuBar/               # NEW
│           ├── MenuBarIconRenderer.swift     # ported from Usage4Claude
│           ├── ShapeIconRenderer.swift       # ported
│           ├── IconShapePaths.swift          # ported
│           ├── MenuBarIconColorScheme.swift  # ported (was UsageColorScheme)
│           ├── IconUsageData.swift           # NEW — owned data model
│           └── ClaudeSnapshotToIconData.swift  # NEW — adapter
└── Tests/
    └── (provider-specific tests for non-Claude providers deleted; new adapter + settings tests added)
```

`MenuBarExtra` stays. The `label:` slot hosts a small SwiftUI view that renders `Image(nsImage:)` from `MenuBarIconRenderer.createIcon(...)`, recomputed when (a) the Claude `UsageSnapshot` changes, (b) any `app.menuBarIcon.*` setting changes, or (c) Sparkle update availability changes (badge dot).

## Data Mapping

The renderer consumes a flat `IconUsageData` struct with up to five optional limit slots. The adapter translates ClaudeBar's `UsageSnapshot` (an array of `UsageQuota` keyed by `QuotaType`) into that shape.

| `IconUsageData` field | `UsageSnapshot` source                       | Notes                              |
|-----------------------|----------------------------------------------|------------------------------------|
| `fiveHour`            | `quota(for: .session)`                       | percentage + reset time            |
| `sevenDay`            | `quota(for: .weekly)`                        | percentage + reset time            |
| `opus`                | `quota(for: .modelSpecific("opus"))`         | case-insensitive model-name match  |
| `sonnet`              | `quota(for: .modelSpecific("sonnet"))`       | case-insensitive model-name match  |
| `extraUsage`          | not mapped in v1                             | always `nil`; renderer code stays  |

The model-name match is case-insensitive because the probe may emit `"Opus"`, `"opus"`, or `"opus-4-5"`-style strings; the adapter takes a `.lowercased().hasPrefix(...)` approach.

`IconUsageData` and its `LimitData` inner type are owned by claude4usages (not borrowed verbatim from Usage4Claude's `UsageData`) so we control the type. The renderer files are mechanically renamed to consume `IconUsageData` instead of `UsageData`.

The `extraUsage` slot stays in renderer code so the hexagon shape isn't lost; the adapter always returns `nil` for it in v1, and the menu bar omits the hexagon. Easy to wire in later if Claude's API ever surfaces an extra-usage figure.

## Icon Settings

New settings, persisted under `app.menuBarIcon.*` in `~/.claude4usages/settings.json`:

| Key                                   | Type      | Default                                              | Values                                                       |
|---------------------------------------|-----------|------------------------------------------------------|--------------------------------------------------------------|
| `app.menuBarIcon.displayMode`         | string    | `both`                                               | `percentageOnly`, `iconOnly`, `both`                         |
| `app.menuBarIcon.styleMode`           | string    | `colorTranslucent`                                   | `monochrome`, `colorTranslucent`, `colorWithBackground`      |
| `app.menuBarIcon.activeTypes`         | [string]  | `["fiveHour","sevenDay","opus","sonnet"]`            | subset of the same list                                      |

Wired into `AppSettings` as `@Observable` properties (`menuBarIconDisplayMode`, `menuBarIconStyleMode`, `menuBarIconActiveTypes`). SwiftUI re-renders the `MenuBarExtra` label when any of these change.

A new "Menu Bar Icon" section is added to the existing Settings window:

- `Picker` for display mode (3 options)
- `Picker` for style mode (3 options)
- 4 toggles for which limit shapes to render (5h, 7d, Opus, Sonnet)

Lives in `App/Settings/MenuBarIconSettingsView.swift`.

**Settings dropped from Usage4Claude (we inherit ClaudeBar's equivalents instead):**

- Notification preferences — ClaudeBar's `NotificationAlerter` already handles status-degradation alerts.
- Localization (zh, ja, ko) — claude4usages is English-only in v1.
- Data refresh interval — ClaudeBar's `backgroundSyncEnabled` + auto-refresh window covers this.
- Smart-mode display thresholds — we always render whichever shapes the user has enabled in `activeTypes`.

## Rebranding

| Item                                | From                                    | To                                            |
|-------------------------------------|-----------------------------------------|-----------------------------------------------|
| App name                            | `ClaudeBar`                             | `claude4usages`                               |
| Tuist project name                  | `ClaudeBar`                             | `claude4usages`                               |
| Bundle id                           | `com.tddworks.ClaudeBar`                | `com.claude4usages.app`                       |
| Settings folder                     | `~/.claudebar/`                         | `~/.claude4usages/`                           |
| Settings file                       | `~/.claudebar/settings.json`            | `~/.claude4usages/settings.json`              |
| Imported themes folder              | `~/.claudebar/themes/`                  | `~/.claude4usages/themes/`                    |
| Log folder                          | `~/Library/Logs/ClaudeBar/`             | `~/Library/Logs/claude4usages/`               |
| OSLog subsystem                     | `com.tddworks.ClaudeBar`                | `com.claude4usages.app`                       |
| `Notification.Name` constants       | `com.tddworks.claudebar.*`              | `com.claude4usages.*`                         |
| Hook header (if any custom)         | n/a                                     | unchanged                                     |
| App icon                            | ClaudeBar's `AppIcon.appiconset`        | new claude4usages icon (placeholder OK in v1) |
| Sparkle appcast URL                 | ClaudeBar's GitHub release feed         | `<TBD by user>` — left as a settings string in v1 |

The OSLog subsystem rename is one find-and-replace across `AppLog.swift` and any tests that filter by subsystem.

## What Gets Deleted

**Approach: minimal-touch.** Keep ClaudeBar's multi-provider architecture intact (it's clean and extensible); just don't register the other providers in `claude4usagesApp.init()` and delete their files.

Files removed (top-level dirs):

- `Sources/Domain/Provider/{Codex,Gemini,Copilot,Antigravity,Zai,Bedrock,AmpCode,Kimi,Kiro,Cursor,MiniMax,Alibaba,Mistral}/`
- `Sources/Infrastructure/CLI/{Codex,Gemini,Copilot,Antigravity,Zai,Bedrock,AmpCode,Kimi,Kiro,Cursor,MiniMax,Alibaba,Mistral}*` (each provider's probe files)
- Provider-specific tests under `Tests/`
- Provider icons in `Sources/App/Resources/Assets.xcassets/` (keep only `AppIcon`, `AppLogo`, `ClaudeIcon`)
- Provider-specific settings UI rows / tabs in `Sources/App/Settings/` and `Sources/App/Views/`
- `JSONSettingsRepository`'s implementations of non-Claude provider sub-protocols (`ZaiSettingsRepository`, `CopilotSettingsRepository`, `BedrockSettingsRepository`, `KimiSettingsRepository`, `MiniMaxSettingsRepository`) and the corresponding protocol files in `Domain/Provider/`
- The `Extensions` system stays (it's general-purpose)
- The `add-provider` skill in `.claude/skills/` stays (useful if claude4usages ever wants to grow beyond Claude — low maintenance burden)

The `AIProvider` protocol, `AIProviderRepository`, `QuotaMonitor`, and provider-agnostic types (`UsageSnapshot`, `UsageQuota`, `QuotaType`, `QuotaStatus`) all stay — `QuotaMonitor` continues to drive the single Claude provider.

## Replaced: `StatusBarIcon`

ClaudeBar's `StatusBarIcon` (SF-symbol view) is replaced by a new view that:

1. Reads `monitor.selectedProvider?.snapshot` (always Claude in this app).
2. Reads icon settings from `AppSettings`.
3. Reads Sparkle update availability (for badge dot).
4. Calls `MenuBarIconRenderer.createIcon(usageData:hasUpdate:button:)` with `button: nil`.
5. Wraps the resulting `NSImage` in `Image(nsImage:)`.

The renderer's `NSStatusBarButton?` parameter is preserved but always `nil`. Its color decisions fall back to `NSApp.effectiveAppearance` instead of the button's appearance — a small modification to `MenuBarIconColorScheme` (`fiveHourColorAdaptive` / `sevenDayColorAdaptive`) to accept an optional button and use the app appearance when `nil`.

## Testing Strategy

- **Domain tests:** keep all Claude-related tests; delete tests for removed providers.
- **Settings tests:** new tests for the three `app.menuBarIcon.*` keys (default values, round-trip persistence).
- **Adapter tests:** unit-test `makeIconUsageData(from:)` against representative `UsageSnapshot` fixtures (all four quota types present, partial subsets, `nil` snapshot, model-name case variations).
- **Renderer tests:** snapshot-test (or pixel-bounds test) that `MenuBarIconRenderer.createIcon` returns an `NSImage` with the expected size for each display mode + style mode combination. No deep visual diffing — just shape-count and size assertions.
- **Manual verification:** `tuist generate && open claude4usages.xcworkspace`, run, click menu bar, toggle each setting, switch macOS appearance light↔dark, verify icon updates correctly.

## Out of Scope (v1)

- **Extra-usage indicator** (hexagon stays in code, not rendered).
- **Localization** — English only.
- **Multi-account support** — `MultiAccountSettingsRepository` and `ProviderAccount` types stay (they're harmless), but no UI is exposed for adding Claude accounts beyond the primary.
- **Sparkle appcast URL** — left as a settings string with no default; user configures before first release.
- **App icon design** — placeholder copy of ClaudeBar's icon for v1; user supplies a real icon later.
- **Homebrew cask** — not published in v1.
- **CI/CD secrets / signing certs** — workflows copied from ClaudeBar but secrets are user's to configure.

## Open Questions (resolved)

- **Q:** Use Claude as the only provider? **A:** Yes.
- **Q:** App name? **A:** `claude4usages`.
- **Q:** Approach? **A:** A — fork ClaudeBar, port icon code, strip non-Claude providers.

## Success Criteria

1. App launches and shows a menu bar icon rendered by `MenuBarIconRenderer` with current Claude usage percentages.
2. Toggling display mode / style mode / active types in Settings updates the menu bar icon live.
3. Light↔dark macOS appearance changes update the icon's colors correctly.
4. Sparkle update available → red badge dot appears on the icon (existing Usage4Claude behavior).
5. All preserved Claude features still work: hook server, daily-usage cards, themes, notifications, refresh, dashboard popover.
6. `tuist build` and `tuist test` pass.
