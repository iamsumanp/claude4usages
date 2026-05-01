# claude4usages

A macOS menu bar app that shows your Claude usage at a glance.

The menu bar icon displays a tight cluster of compact percentage shapes — one for your **5-hour session**, one for your **7-day weekly window**, and optionally shapes for your **Opus weekly** and **Sonnet weekly** allowances. The asterisk icon turns **green** while `claude` is running anywhere on your machine. Click it for a full breakdown, refresh button, and settings.


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

Then launch it from Spotlight or `/Applications`.

## Build from source

```bash
git clone https://github.com/iamsumanp/claude4usages.git
cd claude4usages
swift build -c release
./scripts/build-dmg.sh   # produces dist/claude4usages.app + claude4usages.dmg
```

No Xcode, no Tuist, no asset catalogs — pure SwiftPM.

## Active session indicator

The menu bar asterisk turns **green** while any `claude` process is running on your machine (CLI or IDE). The app polls `pgrep -x claude` every 3 seconds on a background thread — negligible CPU/RAM, no effect on UI responsiveness.

## Configure

Click the menu bar icon → gear to access settings:

- **Quota Display** — show remaining or used percentage; toggle daily usage cards
- **Menu Bar Icon** — Display mode (% Only / Icon Only / Both), Style (Monochrome / Color), which limits to show
- **Claude Configuration** — probe mode (CLI / API), budget tracking
- **Background Sync**, **Burn Rate Warning**, **Hooks**, **Launch at Login**, and more

Settings are persisted at `~/.claude4usages/settings.json`. Logs are at `~/Library/Logs/claude4usages/claude4usages.log`.

## How it works

claude4usages spawns `claude /usage` periodically, scrubs the TUI's ANSI cursor-positioning sequences, and parses `Current session`, `Current week (all models)`, and per-model percentages. Those feed an in-process `QuotaMonitor` whose state drives both the menu bar icon and the popover.

**No network calls, no API tokens, no cookies** — all data comes from the local `claude` CLI.

**Daily usage cards** (Cost, Tokens, Working Time) are read from `~/.claude/projects/` JSONL session files — also 100% local.

## Architecture

```
Sources/
├── Domain/           # SPM library — QuotaMonitor, settings protocols, models
├── Infrastructure/   # SPM library — Claude probes, JSON settings, MenuBar renderer
└── App/              # SPM executable — AppDelegate (NSStatusItem), SwiftUI popover
```

Three SPM targets: `Domain` → `Infrastructure` → `claude4usages`.

The menu bar uses **AppKit `NSStatusItem`** (not SwiftUI `MenuBarExtra`) so the icon updates reactively without requiring the popover to be open. The icon shape rendering lives in `Sources/Infrastructure/MenuBar/`.

## License

MIT — see `LICENSE`.
