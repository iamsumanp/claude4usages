# claude4usages

A macOS menu bar app that shows your Claude usage at a glance.

The menu bar icon is a tight cluster of compact percentage shapes — one for your **5-hour session**, one for your **7-day weekly window**, and (optionally) shapes for your **Opus weekly** and **Sonnet weekly** allowances. Click it for a popover with the full breakdown, refresh button, and settings.


<img width="467" height="701" alt="claude4usages" src="https://github.com/user-attachments/assets/acf4d812-5144-4d12-8610-2a68e18c7984" />


## Requirements

- **macOS 15+**
- **Swift 6.1+ toolchain** — Xcode is **not** required; Command Line Tools are enough
- **Claude CLI** installed and signed in (`claude` on `$PATH`)

## Install

Download `claude4usages.dmg` from the [latest release](https://github.com/iamsumanp/claude4usages/releases/latest), open it, and drag `claude4usages.app` into `/Applications`.

The build is ad-hoc signed (not notarized), so the first launch is blocked by Gatekeeper. To unblock:

```bash
xattr -dr com.apple.quarantine /Applications/claude4usages.app
```

Then launch it from Spotlight or `/Applications`. The asterisk icon will appear in your menu bar.

## Build from source

```bash
git clone https://github.com/iamsumanp/claude4usages.git
cd claude4usages
swift build -c release
./scripts/build-dmg.sh   # produces dist/claude4usages.app + claude4usages.dmg
```

No Xcode, no Tuist, no asset catalogs — pure SwiftPM.

## Configure

Click the menu bar icon → gear → **Menu Bar Icon** to choose:

- **Display mode** — Percentage Only / Icon Only / Both
- **Style** — Monochrome / Color (Translucent) / Color (With Background)
- **Which limits to show** — 5-hour session, 7-day weekly, Opus weekly, Sonnet weekly

Settings are persisted at `~/.claude4usages/settings.json`. Logs are at `~/Library/Logs/claude4usages/claude4usages.log`.

## How it works

claude4usages spawns `claude /usage` periodically, scrubs the TUI's ANSI cursor sequences, and parses out the `Current session`, `Current week (all models)`, and per-model percentages. Those feed an in-process `QuotaMonitor` whose state drives both the menu bar icon and the popover. No network calls, no API tokens, no cookies.

## Architecture

```
Sources/
├── Domain/           # SPM library — provider protocols, QuotaMonitor, settings, models
├── Infrastructure/   # SPM library — Claude probes, JSON settings, MenuBar renderer
└── App/              # SPM executable — SwiftUI views, themes, MenuBarExtra label
```

Three SPM targets: `Domain` → `Infrastructure` → `claude4usages`. The menu bar shape rendering lives in `Sources/Infrastructure/MenuBar/` (`MenuBarIconRenderer`, `ShapeIconRenderer`, `IconShapePaths`, `MenuBarIconColorScheme`) and is fed by the `ClaudeSnapshotToIconData` adapter that maps `UsageSnapshot` → `IconUsageData`.

## License

MIT — see `LICENSE`.
