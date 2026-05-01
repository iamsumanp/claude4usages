# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What this project is

`claude4usages` is a macOS menu bar app that monitors Claude usage. It renders shape icons (5-hour circle, 7-day dashed circle, Opus rectangle, Sonnet rectangle, optional extra-usage hexagon) directly into the menu bar via `MenuBarIconRenderer`, fed by ClaudeBar's `QuotaMonitor` + Claude probes.

The app combines two upstreams:
- Monitoring stack from [ClaudeBar](https://github.com/tddworks/ClaudeBar) — Domain/Infrastructure/App layers, Claude CLI/API/Pass probes, hook server, daily-usage analyzer, theme system, JSON-backed settings.
- Menu bar shape rendering from [Usage4Claude](https://github.com/f-is-h/Usage4Claude) — programmatic NSImage drawing in `Sources/Infrastructure/MenuBar/`.

## Build

```bash
swift build              # debug
swift build -c release   # release
./scripts/build-dmg.sh   # produces claude4usages.app + .dmg under dist/
```

**No Tuist. No Xcode. No tests yet.** Pure SwiftPM. The user is on Swift 6.1.2 with Command Line Tools only.

## Layout

```
Sources/
├── Domain/           # SPM library target — pure logic, no AppKit
│   ├── Provider/Claude/   # Only Claude provider remains (others were stripped)
│   ├── Monitor/QuotaMonitor.swift
│   ├── Settings/AppSettingsRepository.swift
│   ├── DailyUsage/, Session/, Extension/
│   └── Provider/{AIProvider,UsageSnapshot,UsageQuota,QuotaType,...}.swift
├── Infrastructure/   # SPM library target — adapters, probes, storage
│   ├── Claude/       # CLI/API/Pass probes, daily-usage analyzer, credential loader
│   ├── MenuBar/      # NEW — shape-icon renderer + UsageSnapshot adapter
│   │   ├── IconUsageData.swift
│   │   ├── ClaudeSnapshotToIconData.swift
│   │   ├── IconShapePaths.swift
│   │   ├── MenuBarIconColorScheme.swift
│   │   ├── ShapeIconRenderer.swift
│   │   └── MenuBarIconRenderer.swift   (defines MenuBarIconRendererSettings)
│   ├── Storage/JSONSettingsRepository.swift   # ~/.claude4usages/settings.json
│   ├── Hooks/, Logging/, Network/, Notifications/, Shared/, TerminalImport/
└── App/              # SPM executable target — SwiftUI views + glue
    ├── claude4usagesApp.swift   # @main; MenuBarExtra { } label: { MenuBarIconView }
    ├── MenuBarIconView.swift    # SwiftUI wrapper around MenuBarIconRenderer
    ├── Settings/                # AppSettings (@Observable), MenuBarIconSettingsView
    ├── Theme/                   # Light, Dark, CLI, Christmas
    └── Views/                   # MenuContentView (popover), settings cards
```

## Settings keys (in `~/.claude4usages/settings.json`)

App-level: `app.themeMode`, `app.usageDisplayMode`, `app.showDailyUsageCards`, `app.backgroundSyncEnabled`, etc.

Menu bar icon (added in this fork):
- `app.menuBarIcon.displayMode` — `percentageOnly` | `iconOnly` | `both` (default `both`)
- `app.menuBarIcon.styleMode` — `monochrome` | `colorTranslucent` | `colorWithBackground` (default `colorTranslucent`)
- `app.menuBarIcon.activeTypes` — array of `fiveHour` / `sevenDay` / `opusWeekly` / `sonnetWeekly` / `extraUsage`

## Architecture notes

- `QuotaMonitor` is the single source of truth for the Claude provider's `UsageSnapshot`.
- `MenuBarIconView` reads `monitor.selectedProvider?.snapshot` + `AppSettings.menuBarIcon*` and feeds them through `makeIconUsageData(from:)` → `MenuBarIconRenderer.createIcon(...)`.
- The renderer is `@MainActor` (drawing requires it). Calls `NSApp.effectiveAppearance` when `button == nil` for color decisions.
- `extraUsage` is plumbed but Claude probes don't surface it; the adapter always returns `nil` for that slot in v1.

## What was dropped from ClaudeBar

Sparkle (auto-update), Mockable (test mocks), the asset catalog (`Assets.xcassets`), SwiftUI Previews scaffolding, and 13 non-Claude providers (Codex, Gemini, Copilot, Antigravity, Z.ai, Bedrock, Amp, Kimi, Kiro, Cursor, MiniMax, Alibaba, Mistral) and their probes/UI. All `Tests/` were removed (will be rewritten without Mockable later).

## Common tasks

**Adding a new icon setting:** Update `AppSettingsRepository` protocol → implement in `JSONSettingsRepository` → expose via `AppSettings` `@Observable` accessor → bind in `MenuBarIconSettingsView` → consume in `MenuBarIconView`.

**Renaming Claude probe behaviors:** Edit files in `Sources/Infrastructure/Claude/`. Domain stays untouched.

**Adjusting menu bar icon visuals:** Edit `MenuBarIconRenderer.swift` / `ShapeIconRenderer.swift` / `MenuBarIconColorScheme.swift`.
