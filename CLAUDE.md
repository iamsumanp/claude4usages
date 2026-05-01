# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What this project is

`claude4usages` is a macOS menu bar app that shows Claude usage as compact shape icons (5-hour circle, 7-day dashed circle, Opus rectangle, Sonnet rectangle, optional extra-usage hexagon) directly in the menu bar, plus a popover with details, refresh, and settings.

It runs `claude /usage` as a subprocess, scrubs the TUI's ANSI escapes, parses the percentages, and feeds them through an in-process `QuotaMonitor`. No network, no API tokens.

## Build

```bash
swift build              # debug
swift build -c release   # release
./scripts/build-dmg.sh   # produces claude4usages.app + .dmg under dist/
```

**Pure SwiftPM. No Tuist. No Xcode required.** Swift 6.1+ Command Line Tools is enough.

## Layout

```
Sources/
├── Domain/           # SPM library target — pure logic, no AppKit
│   ├── Provider/Claude/   # Claude provider, probe-mode enum
│   ├── Monitor/QuotaMonitor.swift
│   ├── Settings/AppSettingsRepository.swift
│   ├── DailyUsage/, Session/, Extension/
│   └── Provider/{AIProvider,UsageSnapshot,UsageQuota,QuotaType,...}.swift
├── Infrastructure/   # SPM library target — adapters, probes, storage
│   ├── Claude/       # CLI probe, Pass probe, daily-usage analyzer, credential loader
│   ├── MenuBar/      # Shape-icon renderer + UsageSnapshot adapter
│   │   ├── IconUsageData.swift              # owned data model
│   │   ├── ClaudeSnapshotToIconData.swift   # adapter
│   │   ├── IconShapePaths.swift
│   │   ├── MenuBarIconColorScheme.swift
│   │   ├── ShapeIconRenderer.swift
│   │   └── MenuBarIconRenderer.swift        # also defines MenuBarIconRendererSettings
│   │   └── Resources/AppIcon.png + AppIconReverse.png
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

Menu bar icon:
- `app.menuBarIcon.displayMode` — `percentageOnly` | `iconOnly` | `both` (default `both`)
- `app.menuBarIcon.styleMode` — `monochrome` | `colorTranslucent` | `colorWithBackground` (default `colorTranslucent`)
- `app.menuBarIcon.activeTypes` — array of `fiveHour` / `sevenDay` / `opusWeekly` / `sonnetWeekly` / `extraUsage`

## Architecture notes

- `QuotaMonitor` is the single source of truth for the Claude provider's `UsageSnapshot`.
- `MenuBarIconView` reads `monitor.selectedProvider?.snapshot` + `AppSettings.menuBarIcon*` and feeds them through `makeIconUsageData(from:)` → `MenuBarIconRenderer.createIcon(...)`.
- The renderer is `@MainActor` (drawing requires it). Calls `NSApp.effectiveAppearance` when `button == nil` for color decisions.
- `extraUsage` is plumbed but the CLI probe doesn't surface it; the adapter always returns `nil` for that slot.
- `ClaudeUsageProbe` runs `claude /usage --allowed-tools ""` as a subprocess. Its TUI output is normalized by `TerminalRenderer.render(_:)` which translates `\x1B[NC` (cursor right) into N spaces and strips other CSI/OSC sequences. The parser (`extractPercent`) searches for the substring `session` (not `current session`) because Claude's TUI sometimes splits the word `Current` across cursor-positioning escapes.

## What this fork does NOT have

No Sparkle (auto-update), no Mockable (test mocks), no asset catalog (Assets.xcassets), no SwiftUI Previews scaffolding, no tests yet. Tuist/Xcode are not used.

## Common tasks

**Adding a new icon setting:** Update `AppSettingsRepository` protocol → implement in `JSONSettingsRepository` → expose via `AppSettings` `@Observable` accessor → bind in `MenuBarIconSettingsView` → consume in `MenuBarIconView`.

**Adjusting menu bar icon visuals:** Edit `MenuBarIconRenderer.swift` / `ShapeIconRenderer.swift` / `MenuBarIconColorScheme.swift`.

**Releasing:** Update version in `scripts/build-dmg.sh`, run it, attach `claude4usages.dmg` to a tagged GitHub release.
