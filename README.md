# claude4usages

A macOS menu bar app that monitors your Claude usage with at-a-glance shape icons.

The menu bar icon shows your current 5-hour session, 7-day weekly, Opus weekly, and Sonnet weekly usage as compact percentage shapes — adapted from [Usage4Claude](https://github.com/f-is-h/Usage4Claude). The app's monitoring stack (CLI/API probes, hook server, daily-usage analytics, themes) is forked from [ClaudeBar](https://github.com/tddworks/ClaudeBar).

## Requirements

- macOS 15+
- Swift 6.1+ toolchain (Xcode is **not** required)
- [Claude CLI](https://claude.ai/code) installed (`claude` on `$PATH`)

## Build

```bash
swift build -c release
```

## Package as `.app` + DMG

```bash
./scripts/build-dmg.sh
```

This produces `claude4usages.app` and `claude4usages.dmg` under `dist/`. Drag the `.app` into `/Applications`. The build is ad-hoc signed (not notarized), so on first launch:

```bash
xattr -dr com.apple.quarantine /Applications/claude4usages.app
```

## Run

After launching, click the menu bar icon to see the popover with quota detail, refresh, and settings. Open Settings → Menu Bar Icon to choose:

- **Display mode**: Percentage Only / Icon Only / Both
- **Style**: Monochrome / Color (Translucent) / Color (With Background)
- **Which limits to show**: 5-hour session, 7-day weekly, Opus weekly, Sonnet weekly

## Settings location

Settings are persisted at `~/.claude4usages/settings.json`. Logs are at `~/Library/Logs/claude4usages/claude4usages.log`.

## Architecture

```
Sources/
├── Domain/          # AIProvider, QuotaMonitor, settings protocols, models
├── Infrastructure/  # Claude probes, hook server, JSON settings, MenuBar renderer
└── App/             # SwiftUI views, themes, MenuBarExtra, settings UI
```

Three SPM targets — `Domain` → `Infrastructure` → `claude4usages` (executable).

## Credits

- Menu bar icon shape rendering ported from [Usage4Claude](https://github.com/f-is-h/Usage4Claude) (MIT)
- Monitoring + UI stack forked from [ClaudeBar](https://github.com/tddworks/ClaudeBar) (MIT)

## License

MIT
