# claude4usages Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `claude4usages` — a macOS menu bar app combining ClaudeBar's full Claude-monitoring stack (Tuist project, layered architecture, themes, Sparkle, settings, hook server, daily-usage analyzer, probes) with Usage4Claude's distinctive programmatically-rendered menu bar shape icons (5h circle, 7d dashed circle, Opus/Sonnet rectangles, hexagon).

**Architecture:** Fork ClaudeBar's repo into a new directory; keep its layered Domain / Infrastructure / App architecture untouched; strip the 13 non-Claude providers (Codex, Gemini, Copilot, Antigravity, Z.ai, Bedrock, Amp, Kimi, Kiro, Cursor, MiniMax, Alibaba, Mistral); port Usage4Claude's `MenuBarIconRenderer` + `ShapeIconRenderer` + `IconShapePaths` into a new `Sources/App/MenuBar/` directory; add a thin adapter that maps ClaudeBar's `UsageSnapshot` → an owned `IconUsageData` model; wire the rendered `NSImage` into ClaudeBar's existing SwiftUI `MenuBarExtra { } label:` slot. Rebrand throughout (bundle id, settings folder, log path, OSLog subsystem).

**Tech Stack:** Swift 6.0, SwiftUI + AppKit (NSImage drawing), Tuist, Sparkle, Mockable, Swift Testing.

**Spec:** `docs/superpowers/specs/2026-05-01-claude4usages-design.md`

---

## File Structure (Target)

```
claude4usages/
├── Project.swift                                  # MODIFIED: name, bundleIds, drop AWS+SwiftTerm+SweetCookieKit deps
├── Tuist.swift
├── Tuist/Package.swift                            # MODIFIED: drop AWS SDK + SwiftTerm + SweetCookieKit
├── docs/superpowers/specs/                        # spec moves here
├── docs/superpowers/plans/                        # this plan moves here
├── Sources/
│   ├── Domain/
│   │   ├── Provider/
│   │   │   ├── AIProvider.swift                   # unchanged
│   │   │   ├── AIProviderRepository.swift         # unchanged
│   │   │   ├── ProviderSettingsRepository.swift   # unchanged
│   │   │   ├── UsageSnapshot.swift / UsageQuota.swift / QuotaType.swift / QuotaStatus.swift  # unchanged
│   │   │   └── Claude/                            # KEPT
│   │   │   # DELETED: Codex/, Gemini/, Copilot/, Antigravity/, Zai/, Bedrock/,
│   │   │   #         AmpCode/, Kimi/, Kiro/, Cursor/, MiniMax/, Alibaba/, Mistral/
│   │   ├── Monitor/QuotaMonitor.swift             # unchanged
│   │   ├── Settings/
│   │   │   ├── AppSettingsRepository.swift        # MODIFIED: + 3 menu-bar-icon accessors
│   │   │   └── HookSettingsRepository.swift       # unchanged
│   │   ├── DailyUsage/                            # unchanged
│   │   ├── Session/                               # unchanged
│   │   └── Extension/                             # unchanged
│   ├── Infrastructure/
│   │   ├── Claude/                                # KEPT (probes, parser, analyzer, credentials)
│   │   │   # DELETED siblings: Codex/, Gemini/, Copilot/, Antigravity/, Zai/, Bedrock/,
│   │   │   #                  AmpCode/, Kimi/, Kiro/, Cursor/, MiniMax/, Alibaba/, Mistral/
│   │   ├── Storage/
│   │   │   ├── JSONSettingsRepository.swift       # MODIFIED: drop non-Claude protocol conformances; + 3 menu-bar-icon getters/setters
│   │   │   ├── JSONSettingsStore.swift            # unchanged
│   │   │   ├── AIProviders.swift                  # unchanged
│   │   │   ├── UserDefaultsCredentialRepository.swift  # unchanged
│   │   │   └── UserDefaultsProviderSettingsRepository.swift  # unchanged
│   │   ├── Hooks/                                 # unchanged
│   │   ├── Logging/AppLog.swift                   # MODIFIED: subsystem id, file path
│   │   ├── Network/                               # unchanged
│   │   ├── Notifications/                         # unchanged
│   │   ├── Shared/                                # unchanged
│   │   ├── TerminalImport/                        # unchanged
│   │   └── Extension/                             # unchanged
│   └── App/
│       ├── claude4usagesApp.swift                 # RENAMED from ClaudeBarApp.swift; struct renamed
│       ├── Info.plist                             # MODIFIED: name, bundle id, version
│       ├── entitlements.plist / entitlements.mas.plist  # unchanged
│       ├── Resources/Assets.xcassets/             # MODIFIED: drop 13 provider iconsets
│       ├── Theme/                                 # unchanged
│       ├── Settings/
│       │   ├── AppSettings.swift                  # MODIFIED: drop non-Claude accessors; + 3 menu-bar-icon @Observable properties
│       │   ├── ThemeImportView.swift              # unchanged
│       │   └── MenuBarIconSettingsView.swift      # NEW — picker UI for icon settings
│       ├── Views/                                 # MODIFIED: drop non-Claude provider rows / settings tabs
│       ├── LiveActivity/                          # unchanged
│       ├── SparkleUpdater.swift                   # unchanged
│       └── MenuBar/                               # NEW DIR
│           ├── IconUsageData.swift                # NEW — owned data model
│           ├── ClaudeSnapshotToIconData.swift     # NEW — adapter
│           ├── IconShapePaths.swift               # PORTED from Usage4Claude
│           ├── MenuBarIconColorScheme.swift       # PORTED (was UsageColorScheme); modified for nil button
│           ├── ShapeIconRenderer.swift            # PORTED
│           ├── MenuBarIconRenderer.swift          # PORTED; adapted to consume IconUsageData
│           └── MenuBarIconView.swift              # NEW — SwiftUI wrapper that feeds renderer into MenuBarExtra label
└── Tests/
    ├── DomainTests/                               # MODIFIED: drop non-Claude provider tests
    ├── InfrastructureTests/                       # MODIFIED: drop non-Claude probe tests; + JSONSettingsRepository menu-bar-icon tests
    └── AcceptanceTests/                           # MODIFIED: drop non-Claude scenarios
```

---

## Phase 1 — Bootstrap the new project (rename only)

### Task 1.1: Copy ClaudeBar tree into `claude4usages/`

**Files:**
- Create: `/Users/boski/Desktop/desk/claude4usages/` (new directory, contents = ClaudeBar minus `.git`)

- [ ] **Step 1: Copy the ClaudeBar tree, excluding `.git`**

```bash
cd /Users/boski/Desktop/desk
rsync -a --exclude='.git' --exclude='Derived' --exclude='*.xcworkspace' --exclude='*.xcodeproj' ClaudeBar/ claude4usages/
ls claude4usages/
```

Expected: lists `Project.swift`, `Sources`, `Tests`, `Tuist`, `Tuist.swift`, `docs`, `scripts`, `CHANGELOG.md`, `README.md`, `CLAUDE.md`, `codecov.yml`, `.github/`, `.claude/`, `.gitignore`, `.gitattributes`.

- [ ] **Step 2: Initialize a fresh git repo and stage the snapshot**

```bash
cd /Users/boski/Desktop/desk/claude4usages
git init
git add -A
git commit -m "chore: import ClaudeBar baseline as claude4usages starting point"
```

Expected: `git log --oneline` shows one commit.

---

### Task 1.2: Move spec + plan into the new project

**Files:**
- Move: `/Users/boski/Desktop/desk/docs/superpowers/specs/2026-05-01-claude4usages-design.md` → `claude4usages/docs/superpowers/specs/`
- Move: `/Users/boski/Desktop/desk/docs/superpowers/plans/2026-05-01-claude4usages.md` → `claude4usages/docs/superpowers/plans/`

- [ ] **Step 1: Create dirs and move files**

```bash
cd /Users/boski/Desktop/desk/claude4usages
mkdir -p docs/superpowers/specs docs/superpowers/plans
mv ../docs/superpowers/specs/2026-05-01-claude4usages-design.md docs/superpowers/specs/
mv ../docs/superpowers/plans/2026-05-01-claude4usages.md docs/superpowers/plans/
```

- [ ] **Step 2: Commit**

```bash
git add docs/superpowers/
git commit -m "docs: import design spec and implementation plan"
```

---

### Task 1.3: Rename Tuist project + targets + bundle ids

**Files:**
- Modify: `claude4usages/Project.swift`

- [ ] **Step 1: Replace `Project.swift` with renamed identifiers**

Open `Project.swift`. Apply these exact edits:

| Line | Before | After |
|------|--------|-------|
| 4 | `    name: "ClaudeBar",` | `    name: "claude4usages",` |
| 29 | `            bundleId: "com.tddworks.claudebar.domain",` | `            bundleId: "com.claude4usages.domain",` |
| 47 | `            bundleId: "com.tddworks.claudebar.infrastructure",` | `            bundleId: "com.claude4usages.infrastructure",` |
| 71 | `            name: "ClaudeBar",` | `            name: "claude4usages",` |
| 74 | `            bundleId: "com.tddworks.claudebar",` | `            bundleId: "com.claude4usages.app",` |
| 109 | `            bundleId: "com.tddworks.claudebar.domain-tests",` | `            bundleId: "com.claude4usages.domain-tests",` |
| 135 | `            bundleId: "com.tddworks.claudebar.infrastructure-tests",` | `            bundleId: "com.claude4usages.infrastructure-tests",` |
| 161 | `            bundleId: "com.tddworks.claudebar.acceptance-tests",` | `            bundleId: "com.claude4usages.acceptance-tests",` |
| 184 | `            name: "ClaudeBar",` | `            name: "claude4usages",` |
| 186 | `            buildAction: .buildAction(targets: ["ClaudeBar"]),` | `            buildAction: .buildAction(targets: ["claude4usages"]),` |
| 195 | `            runAction: .runAction(configuration: .debug, executable: .target("ClaudeBar")),` | `            runAction: .runAction(configuration: .debug, executable: .target("claude4usages")),` |
| 197 | `            profileAction: .profileAction(configuration: .release, executable: .target("ClaudeBar")),` | `            profileAction: .profileAction(configuration: .release, executable: .target("claude4usages")),` |

Note: the AWS + SwiftTerm + SweetCookieKit external deps stay for now; we'll prune them in Phase 2 after deleting the providers that use them. Pruning in Phase 1 would break the build before we've removed the consumers.

- [ ] **Step 2: Verify Tuist generation succeeds**

```bash
cd /Users/boski/Desktop/desk/claude4usages
tuist install
tuist generate
```

Expected: generates `claude4usages.xcworkspace`. No errors.

- [ ] **Step 3: Commit**

```bash
git add Project.swift
git commit -m "chore: rename Tuist project + bundle ids to claude4usages"
```

---

### Task 1.4: Update Info.plist

**Files:**
- Modify: `claude4usages/Sources/App/Info.plist`

- [ ] **Step 1: Inspect current values**

```bash
cd /Users/boski/Desktop/desk/claude4usages
/usr/libexec/PlistBuddy -c "Print :CFBundleName" Sources/App/Info.plist
/usr/libexec/PlistBuddy -c "Print :CFBundleDisplayName" Sources/App/Info.plist 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" Sources/App/Info.plist 2>/dev/null || true
```

- [ ] **Step 2: Update name fields**

```bash
/usr/libexec/PlistBuddy -c "Set :CFBundleName claude4usages" Sources/App/Info.plist
# Add display name if missing, update if present
/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName claude4usages" Sources/App/Info.plist 2>/dev/null \
  || /usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string claude4usages" Sources/App/Info.plist
```

- [ ] **Step 3: Verify**

```bash
/usr/libexec/PlistBuddy -c "Print :CFBundleName" Sources/App/Info.plist
/usr/libexec/PlistBuddy -c "Print :CFBundleDisplayName" Sources/App/Info.plist
```

Expected: both print `claude4usages`.

- [ ] **Step 4: Commit**

```bash
git add Sources/App/Info.plist
git commit -m "chore: rename Info.plist bundle/display name"
```

---

### Task 1.5: Rename App entry struct + file

**Files:**
- Rename: `claude4usages/Sources/App/ClaudeBarApp.swift` → `claude4usages/Sources/App/claude4usagesApp.swift`
- Modify: that file (struct rename, notification name)

- [ ] **Step 1: Rename file and update its contents**

```bash
cd /Users/boski/Desktop/desk/claude4usages
git mv Sources/App/ClaudeBarApp.swift Sources/App/claude4usagesApp.swift
```

In the renamed file, apply:

```swift
// Before:
extension Notification.Name {
    static let hookSettingsChanged = Notification.Name("com.tddworks.claudebar.hookSettingsChanged")
}

@main
struct ClaudeBarApp: App {

// After:
extension Notification.Name {
    static let hookSettingsChanged = Notification.Name("com.claude4usages.hookSettingsChanged")
}

@main
struct claude4usagesApp: App {
```

Also replace any in-file log lines that say `"ClaudeBar v..."` with `"claude4usages v..."`:

```swift
// Before:
AppLog.ui.info("ClaudeBar v\(version) (\(build)) initializing...")
...
AppLog.ui.info("ClaudeBar initialization complete")

// After:
AppLog.ui.info("claude4usages v\(version) (\(build)) initializing...")
...
AppLog.ui.info("claude4usages initialization complete")
```

- [ ] **Step 2: Update any other in-tree references to `ClaudeBarApp`**

```bash
grep -rn "ClaudeBarApp" Sources/ Tests/
```

Expected: no results (the struct should only have been declared in the renamed file). If any references remain, replace with `claude4usagesApp` and re-grep until clean.

- [ ] **Step 3: Regenerate + build**

```bash
tuist generate
tuist build claude4usages
```

Expected: build succeeds.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "refactor: rename ClaudeBarApp struct/file to claude4usagesApp"
```

---

### Task 1.6: Move settings folder from `~/.claudebar/` to `~/.claude4usages/`

**Files:**
- Modify: `claude4usages/Sources/Infrastructure/Storage/JSONSettingsStore.swift` (and any other file that references `.claudebar`)

- [ ] **Step 1: Find all `.claudebar` references**

```bash
grep -rn "\.claudebar" Sources/ Tests/
```

- [ ] **Step 2: Replace each occurrence**

Use a structured replace, then re-grep to confirm:

```bash
grep -rln "\.claudebar" Sources/ Tests/ | xargs sed -i '' 's/\.claudebar/.claude4usages/g'
grep -rn "\.claudebar" Sources/ Tests/
```

Expected after: no remaining matches.

- [ ] **Step 3: Replace `~/.claudebar/themes/` references too if any reference uses the literal `claudebar` without dot**

```bash
grep -rn "claudebar" Sources/ Tests/
```

For each match, if it's a path/identifier (e.g., `"claudebar"` as a folder name in a string), replace with `claude4usages`. Skip matches that are part of `com.tddworks.claudebar.*` bundle ids — those are handled by Project.swift; check that none remain in source code:

```bash
grep -rn "com\.tddworks\.claudebar" Sources/ Tests/
```

For each remaining hit, replace with `com.claude4usages` (preserving any suffix like `.hookSettingsChanged`).

- [ ] **Step 4: Build and run a quick settings round-trip test**

```bash
tuist build claude4usages
tuist test InfrastructureTests
```

Expected: settings tests pass against the new path.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "chore: move settings folder to ~/.claude4usages/"
```

---

### Task 1.7: Update log path and OSLog subsystem

**Files:**
- Modify: `claude4usages/Sources/Infrastructure/Logging/AppLog.swift`

- [ ] **Step 1: Read current log paths and subsystem**

```bash
grep -n "ClaudeBar\|com.tddworks" Sources/Infrastructure/Logging/AppLog.swift
```

- [ ] **Step 2: Apply replacements**

In `AppLog.swift`:

| Before | After |
|--------|-------|
| `"com.tddworks.ClaudeBar"` | `"com.claude4usages.app"` |
| `"~/Library/Logs/ClaudeBar/"` (or any literal path with `ClaudeBar` log dir) | `"~/Library/Logs/claude4usages/"` |
| `"ClaudeBar.log"` | `"claude4usages.log"` |
| `"ClaudeBar.old.log"` | `"claude4usages.old.log"` |

Use `Edit` on each occurrence (don't bulk-sed here — there may be a few `ClaudeBar` strings legitimately referring to the old name in comments that should also be updated, but you want to verify each).

- [ ] **Step 3: Search for any other log-related ClaudeBar string**

```bash
grep -rn "ClaudeBar" Sources/Infrastructure/Logging/
grep -rn "ClaudeBar" Sources/App/ | grep -i log
```

Replace any remaining hits.

- [ ] **Step 4: Build**

```bash
tuist build claude4usages
```

Expected: success.

- [ ] **Step 5: Commit**

```bash
git add Sources/Infrastructure/Logging/AppLog.swift Sources/App/
git commit -m "chore: rename OSLog subsystem and log file paths"
```

---

## Phase 2 — Strip non-Claude providers

### Task 2.1: Delete non-Claude domain provider folders

**Files:**
- Delete (folders): `Sources/Domain/Provider/{Codex,Gemini,Copilot,Antigravity,Zai,Bedrock,AmpCode,Kimi,Kiro,Cursor,MiniMax,Alibaba,Mistral}/`

- [ ] **Step 1: Delete the folders**

```bash
cd /Users/boski/Desktop/desk/claude4usages
rm -rf Sources/Domain/Provider/Codex \
       Sources/Domain/Provider/Gemini \
       Sources/Domain/Provider/Copilot \
       Sources/Domain/Provider/Antigravity \
       Sources/Domain/Provider/Zai \
       Sources/Domain/Provider/Bedrock \
       Sources/Domain/Provider/AmpCode \
       Sources/Domain/Provider/Kimi \
       Sources/Domain/Provider/Kiro \
       Sources/Domain/Provider/Cursor \
       Sources/Domain/Provider/MiniMax \
       Sources/Domain/Provider/Alibaba \
       Sources/Domain/Provider/Mistral
ls Sources/Domain/Provider/
```

Expected listing (only Claude provider dir + shared types remains):
```
AIProvider.swift
AIProviderRepository.swift
AccountInfo.swift
AccountTier.swift
BudgetStatus.swift
Claude
CostUsage.swift
CredentialRepository.swift
MultiAccountSettingsRepository.swift
MultiAccountSupport.swift
ProbeError.swift
ProviderAccount.swift
ProviderSettingsRepository.swift
QuotaStatus.swift
QuotaType.swift
UsageDisplayMode.swift
UsagePace.swift
UsageQuota.swift
UsageSnapshot.swift
```

(Build will be broken at this point — that's expected; Tasks 2.2–2.5 fix the dangling references.)

---

### Task 2.2: Delete non-Claude infrastructure provider folders

**Files:**
- Delete: `Sources/Infrastructure/{Codex,Gemini,Copilot,Antigravity,Zai,Bedrock,AmpCode,Kimi,Kiro,Cursor,MiniMax,Alibaba,Mistral}/`

- [ ] **Step 1: Delete the folders**

```bash
cd /Users/boski/Desktop/desk/claude4usages
rm -rf Sources/Infrastructure/Codex \
       Sources/Infrastructure/Gemini \
       Sources/Infrastructure/Copilot \
       Sources/Infrastructure/Antigravity \
       Sources/Infrastructure/Zai \
       Sources/Infrastructure/Bedrock \
       Sources/Infrastructure/AmpCode \
       Sources/Infrastructure/Kimi \
       Sources/Infrastructure/Kiro \
       Sources/Infrastructure/Cursor \
       Sources/Infrastructure/MiniMax \
       Sources/Infrastructure/Alibaba \
       Sources/Infrastructure/Mistral
ls Sources/Infrastructure/
```

Expected listing:
```
Claude
Extension
Hooks
Logging
Network
Notifications
Shared
Storage
TerminalImport
```

---

### Task 2.3: Strip non-Claude protocol conformances from `JSONSettingsRepository`

**Files:**
- Modify: `Sources/Infrastructure/Storage/JSONSettingsRepository.swift`

- [ ] **Step 1: Delete non-Claude conformances from the class declaration**

In `JSONSettingsRepository.swift` lines 10–22, change:

```swift
public final class JSONSettingsRepository:
    AppSettingsRepository,
    ZaiSettingsRepository,
    CopilotSettingsRepository,
    BedrockSettingsRepository,
    ClaudeSettingsRepository,
    CodexSettingsRepository,
    KimiSettingsRepository,
    MiniMaxSettingsRepository,
    AlibabaSettingsRepository,
    HookSettingsRepository,
    @unchecked Sendable
{
```

to:

```swift
public final class JSONSettingsRepository:
    AppSettingsRepository,
    ClaudeSettingsRepository,
    HookSettingsRepository,
    @unchecked Sendable
{
```

- [ ] **Step 2: Delete the method bodies for non-Claude protocols**

Inside the class, delete every method and `// MARK:` block that belongs to a non-Claude protocol. Search for each block by section comment / method-name prefix and delete:

```bash
grep -n "MARK: -" Sources/Infrastructure/Storage/JSONSettingsRepository.swift
```

Delete sections labeled (or methods prefixed for): `Codex`, `Kimi`, `Zai`, `Copilot`, `Bedrock`, `MiniMax`, `Alibaba`. Keep `AppSettingsRepository`, `Claude`, `Hook`, and any provider-agnostic helpers.

Methods to remove (from the existing 463-line file): `codexProbeMode`, `setCodexProbeMode`, `kimiProbeMode`, `setKimiProbeMode`, `zaiConfigPath`, `setZaiConfigPath`, `glmAuthEnvVar`, `setGlmAuthEnvVar`, `copilotProbeMode`, `setCopilotProbeMode`, `copilotAuthEnvVar`, `setCopilotAuthEnvVar`, `copilotMonthlyLimit`, `setCopilotMonthlyLimit`, `copilotManualUsageValue`, `setCopilotManualUsageValue`, `copilotManualUsageIsPercent`, `setCopilotManualUsageIsPercent`, `copilotManualOverrideEnabled`, `setCopilotManualOverrideEnabled`, `copilotApiReturnedEmpty`, `setCopilotApiReturnedEmpty`, `bedrockAwsProfile`, `setBedrockAwsProfile`, `bedrockRegions`, `setBedrockRegions`, `minimaxApiKey`, `setMinimaxApiKey`, `alibaba*`. Also remove credentials methods specific to GitHub Copilot or MiniMax (e.g. `saveCopilotToken`, `saveMiniMaxApiKey`).

- [ ] **Step 3: Delete the corresponding non-Claude protocol files**

Some sub-protocols live under `Sources/Domain/Provider/<Provider>/<Provider>SettingsRepository.swift` and were already removed in Task 2.1. Verify nothing in `Sources/Domain/Settings/` still defines them:

```bash
grep -rn "ZaiSettingsRepository\|CopilotSettingsRepository\|BedrockSettingsRepository\|CodexSettingsRepository\|KimiSettingsRepository\|MiniMaxSettingsRepository\|AlibabaSettingsRepository" Sources/Domain/
```

Expected: no results.

- [ ] **Step 4: Search for stray references**

```bash
grep -rn "ZaiSettingsRepository\|CopilotSettingsRepository\|BedrockSettingsRepository\|CodexSettingsRepository\|KimiSettingsRepository\|MiniMaxSettingsRepository\|AlibabaSettingsRepository" Sources/ Tests/
```

Replace or delete each remaining reference. Most should be in `AppSettings.swift` and the App's settings UI — handled in the next two tasks.

---

### Task 2.4: Strip non-Claude accessors from `AppSettings`

**Files:**
- Modify: `Sources/App/Settings/AppSettings.swift`

- [ ] **Step 1: Identify non-Claude accessors**

```bash
grep -n "codex\|kimi\|copilot\|zai\|bedrock\|minimax\|alibaba\|antigravity\|gemini\|amp\|kiro\|cursor\|mistral" Sources/App/Settings/AppSettings.swift
```

- [ ] **Step 2: Delete each non-Claude property and accessor**

Remove typed sub-accessors like:

```swift
public var codex: CodexSettingsRepository { repository }
public var kimi: KimiSettingsRepository { repository }
public var copilot: CopilotSettingsRepository { repository }
public var zai: ZaiSettingsRepository { repository }
public var bedrock: BedrockSettingsRepository { repository }
public var minimax: MiniMaxSettingsRepository { repository }
public var alibaba: AlibabaSettingsRepository { repository }
```

Also delete any per-provider `@Observable` properties (e.g. `var copilotMonthlyLimit`, `var bedrockRegions`).

Keep: any Claude-specific accessor (`var claude: ClaudeSettingsRepository { repository }`), all `app.*` accessors (`themeMode`, `usageDisplayMode`, `showDailyUsageCards`, `backgroundSyncEnabled`, `claudeApiBudget*`, `burnRate*`).

- [ ] **Step 3: Verify**

```bash
grep -n "codex\|kimi\|copilot\|zai\|bedrock\|minimax\|alibaba\|antigravity\|gemini\|amp\|kiro\|cursor\|mistral" Sources/App/Settings/AppSettings.swift
```

Expected: no results.

---

### Task 2.5: Strip non-Claude provider registrations from app init + remove non-Claude UI

**Files:**
- Modify: `Sources/App/claude4usagesApp.swift`
- Modify / Delete: any view file under `Sources/App/Views/` or `Sources/App/Settings/` that references a removed provider

- [ ] **Step 1: Replace the providers array in `claude4usagesApp.init()`**

Find the block in `claude4usagesApp.swift` that constructs `AIProviders(providers: [...])` (around lines 53–101 in the original ClaudeBarApp.swift). Replace the whole array with just the Claude entry:

```swift
let repository = AIProviders(providers: [
    ClaudeProvider(
        cliProbe: ClaudeUsageProbe(),
        apiProbe: ClaudeAPIUsageProbe(),
        passProbe: ClaudePassProbe(),
        settingsRepository: settingsRepository,
        dailyUsageAnalyzer: ClaudeDailyUsageAnalyzer()
    ),
])
```

- [ ] **Step 2: Find and delete view files that reference removed providers**

```bash
grep -rln "CodexProvider\|GeminiProvider\|CopilotProvider\|AntigravityProvider\|ZaiProvider\|BedrockProvider\|AmpCodeProvider\|KimiProvider\|KiroProvider\|CursorProvider\|MiniMaxProvider\|AlibabaProvider\|MistralProvider" Sources/App/
```

For each hit:

- If the file's whole purpose is the removed provider (e.g. a settings tab view called `BedrockSettingsView.swift`), delete the file.
- If the file mentions multiple providers (e.g. a generic `ProviderListView.swift`), edit to remove only the references to the deleted providers.

After:

```bash
grep -rn "CodexProvider\|GeminiProvider\|CopilotProvider\|AntigravityProvider\|ZaiProvider\|BedrockProvider\|AmpCodeProvider\|KimiProvider\|KiroProvider\|CursorProvider\|MiniMaxProvider\|AlibabaProvider\|MistralProvider" Sources/
```

Expected: no results.

- [ ] **Step 3: Find and remove icon-asset references for removed providers**

```bash
grep -rn "CodexIcon\|GeminiIcon\|CopilotIcon\|AntigravityIcon\|ZaiIcon\|BedrockIcon\|AmpCodeIcon\|KimiIcon\|KiroIcon\|CursorIcon\|MiniMaxIcon\|AlibabaIcon\|MistralIcon" Sources/
```

Remove each `Image(<icon-name>)` reference.

- [ ] **Step 4: Build**

```bash
tuist generate
tuist build claude4usages
```

Expected: build succeeds. If it fails, the error message will name the missing symbol — repeat the grep / delete cycle until green.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor: strip 13 non-Claude providers — domain, infrastructure, settings, UI"
```

---

### Task 2.6: Delete non-Claude provider tests

**Files:**
- Delete: any test file under `Tests/DomainTests/`, `Tests/InfrastructureTests/`, `Tests/AcceptanceTests/` that targets a removed provider

- [ ] **Step 1: Find non-Claude test files**

```bash
cd /Users/boski/Desktop/desk/claude4usages
find Tests -type f \( -name "*Codex*" -o -name "*Gemini*" -o -name "*Copilot*" -o -name "*Antigravity*" -o -name "*Zai*" -o -name "*Bedrock*" -o -name "*AmpCode*" -o -name "*Kimi*" -o -name "*Kiro*" -o -name "*Cursor*" -o -name "*MiniMax*" -o -name "*Alibaba*" -o -name "*Mistral*" \)
```

- [ ] **Step 2: Delete each of those files**

```bash
find Tests -type f \( -name "*Codex*" -o -name "*Gemini*" -o -name "*Copilot*" -o -name "*Antigravity*" -o -name "*Zai*" -o -name "*Bedrock*" -o -name "*AmpCode*" -o -name "*Kimi*" -o -name "*Kiro*" -o -name "*Cursor*" -o -name "*MiniMax*" -o -name "*Alibaba*" -o -name "*Mistral*" \) -delete
```

- [ ] **Step 3: Find shared test files that reference removed providers**

```bash
grep -rln "CodexProvider\|GeminiProvider\|CopilotProvider\|AntigravityProvider\|ZaiProvider\|BedrockProvider\|AmpCodeProvider\|KimiProvider\|KiroProvider\|CursorProvider\|MiniMaxProvider\|AlibabaProvider\|MistralProvider" Tests/
```

For each file, edit out the offending references.

- [ ] **Step 4: Run tests**

```bash
tuist test
```

Expected: all remaining tests pass.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "test: drop non-Claude provider tests"
```

---

### Task 2.7: Drop non-Claude provider icons from the asset catalog

**Files:**
- Delete (imageset folders): `Sources/App/Resources/Assets.xcassets/{CodexIcon,GeminiIcon,CopilotIcon,AntigravityIcon,ZaiIcon,BedrockIcon,AmpCodeIcon,KimiIcon,KiroIcon,CursorIcon,MiniMaxIcon,AlibabaIcon,MistralIcon}.imageset/`

- [ ] **Step 1: Delete the imagesets**

```bash
cd /Users/boski/Desktop/desk/claude4usages
for icon in CodexIcon GeminiIcon CopilotIcon AntigravityIcon ZaiIcon BedrockIcon AmpCodeIcon KimiIcon KiroIcon CursorIcon MiniMaxIcon AlibabaIcon MistralIcon; do
  rm -rf "Sources/App/Resources/Assets.xcassets/${icon}.imageset"
done
ls Sources/App/Resources/Assets.xcassets/
```

Expected listing: only `AppIcon.appiconset`, `AppLogo.imageset`, `ClaudeIcon.imageset`, `Contents.json`.

- [ ] **Step 2: Build**

```bash
tuist generate
tuist build claude4usages
```

Expected: success.

- [ ] **Step 3: Commit**

```bash
git add Sources/App/Resources/Assets.xcassets/
git commit -m "chore: drop non-Claude provider iconsets"
```

---

### Task 2.8: Prune unused external dependencies (AWS, SwiftTerm, SweetCookieKit)

**Files:**
- Modify: `claude4usages/Project.swift`
- Modify: `claude4usages/Tuist/Package.swift`

- [ ] **Step 1: Verify the pruned providers were the only consumers**

```bash
grep -rn "import AWS\|import SwiftTerm\|import SweetCookieKit" Sources/ Tests/
```

Expected: no results (Bedrock used AWS, Kimi used SweetCookieKit, Cursor used SwiftTerm — all already deleted in Tasks 2.1–2.2).

- [ ] **Step 2: Remove `.external(name: "AWS*")`, `"SwiftTerm"`, `"SweetCookieKit"` from `Project.swift`**

In `Project.swift`, remove these lines from the Infrastructure target's `dependencies:` block:

```swift
.external(name: "SwiftTerm"),
.external(name: "AWSCloudWatch"),
.external(name: "AWSSTS"),
.external(name: "AWSPricing"),
.external(name: "AWSSDKIdentity"),
.external(name: "AWSSSO"),
.external(name: "AWSSSOOIDC"),
.external(name: "SweetCookieKit"),
```

Also remove the same `AWS*` external deps from `DomainTests`, `InfrastructureTests`, and `AcceptanceTests` target definitions (lines 116–122, 142–148, 168–174 in original).

- [ ] **Step 3: Update `Tuist/Package.swift`**

```bash
cat Tuist/Package.swift
```

Remove any package dependency declarations for `aws-sdk-swift`, `SwiftTerm`, `SweetCookieKit`. (Mockable and Sparkle stay.)

- [ ] **Step 4: Re-resolve and rebuild**

```bash
rm -rf .build Tuist/.build .derived
tuist install
tuist generate
tuist build claude4usages
tuist test
```

Expected: clean build + green tests.

- [ ] **Step 5: Commit**

```bash
git add Project.swift Tuist/Package.swift
git commit -m "deps: drop AWS SDK + SwiftTerm + SweetCookieKit (no longer consumed)"
```

---

## Phase 3 — Port the Usage4Claude icon renderer

### Task 3.1: Create `IconUsageData` model

**Files:**
- Create: `claude4usages/Sources/App/MenuBar/IconUsageData.swift`

- [ ] **Step 1: Create the new directory**

```bash
mkdir -p Sources/App/MenuBar
```

- [ ] **Step 2: Write `IconUsageData.swift`**

```swift
import Foundation

/// Flat, renderer-facing snapshot of Claude usage limits.
/// Owned by claude4usages — independent of `UsageSnapshot` so the renderer
/// can be tested and refactored without coupling to the domain layer.
public struct IconUsageData: Sendable, Equatable {
    public let fiveHour: LimitData?
    public let sevenDay: LimitData?
    public let opus: LimitData?
    public let sonnet: LimitData?
    public let extraUsage: ExtraUsageData?

    public init(
        fiveHour: LimitData? = nil,
        sevenDay: LimitData? = nil,
        opus: LimitData? = nil,
        sonnet: LimitData? = nil,
        extraUsage: ExtraUsageData? = nil
    ) {
        self.fiveHour = fiveHour
        self.sevenDay = sevenDay
        self.opus = opus
        self.sonnet = sonnet
        self.extraUsage = extraUsage
    }

    public struct LimitData: Sendable, Equatable {
        public let percentage: Double
        public let resetsAt: Date?

        public init(percentage: Double, resetsAt: Date? = nil) {
            self.percentage = percentage
            self.resetsAt = resetsAt
        }
    }

    public struct ExtraUsageData: Sendable, Equatable {
        public let enabled: Bool
        public let percentage: Double?

        public init(enabled: Bool, percentage: Double?) {
            self.enabled = enabled
            self.percentage = percentage
        }
    }
}

/// Which limit shape is rendered.
public enum IconLimitType: String, Sendable, CaseIterable, Codable {
    case fiveHour
    case sevenDay
    case opusWeekly
    case sonnetWeekly
    case extraUsage
}
```

- [ ] **Step 3: Build to ensure it compiles**

```bash
tuist generate
tuist build claude4usages
```

Expected: success.

- [ ] **Step 4: Commit**

```bash
git add Sources/App/MenuBar/IconUsageData.swift
git commit -m "feat(menubar): introduce IconUsageData renderer-facing model"
```

---

### Task 3.2: Write failing test for `ClaudeSnapshotToIconData` adapter

**Files:**
- Test: `claude4usages/Tests/InfrastructureTests/MenuBar/ClaudeSnapshotToIconDataTests.swift` (new)

- [ ] **Step 1: Create the test file**

```bash
mkdir -p Tests/InfrastructureTests/MenuBar
```

```swift
// Tests/InfrastructureTests/MenuBar/ClaudeSnapshotToIconDataTests.swift
import Testing
import Foundation
@testable import Domain
// The adapter is App-layer code, so we expose it via a public function in the App module.
// Since unit tests can't easily target the App target, the adapter is hosted in
// Domain or Infrastructure. We host in Infrastructure to test it cleanly.
@testable import Infrastructure

struct ClaudeSnapshotToIconDataTests {
    @Test func nilSnapshotProducesNilIconData() {
        let result = makeIconUsageData(from: nil)
        #expect(result == nil)
    }

    @Test func sessionAndWeeklyMapToFiveHourAndSevenDay() {
        let session = UsageQuota(quotaType: .session, percentage: 42.0, resetAt: nil)
        let weekly = UsageQuota(quotaType: .weekly, percentage: 73.0, resetAt: nil)
        let snapshot = UsageSnapshot(providerId: "claude", quotas: [session, weekly], capturedAt: Date())

        let icon = makeIconUsageData(from: snapshot)

        #expect(icon?.fiveHour?.percentage == 42.0)
        #expect(icon?.sevenDay?.percentage == 73.0)
        #expect(icon?.opus == nil)
        #expect(icon?.sonnet == nil)
    }

    @Test func opusAndSonnetModelLimitsMap() {
        let opusQuota = UsageQuota(quotaType: .modelSpecific("opus"), percentage: 10.0, resetAt: nil)
        let sonnetQuota = UsageQuota(quotaType: .modelSpecific("Sonnet 3.5"), percentage: 25.0, resetAt: nil)
        let snapshot = UsageSnapshot(providerId: "claude", quotas: [opusQuota, sonnetQuota], capturedAt: Date())

        let icon = makeIconUsageData(from: snapshot)

        #expect(icon?.opus?.percentage == 10.0)
        #expect(icon?.sonnet?.percentage == 25.0)
    }

    @Test func modelNameMatchIsCaseInsensitive() {
        let opusQuota = UsageQuota(quotaType: .modelSpecific("OPUS-4-5"), percentage: 50.0, resetAt: nil)
        let snapshot = UsageSnapshot(providerId: "claude", quotas: [opusQuota], capturedAt: Date())

        let icon = makeIconUsageData(from: snapshot)
        #expect(icon?.opus?.percentage == 50.0)
    }

    @Test func extraUsageNotMappedInV1() {
        let session = UsageQuota(quotaType: .session, percentage: 5.0, resetAt: nil)
        let snapshot = UsageSnapshot(providerId: "claude", quotas: [session], capturedAt: Date())

        let icon = makeIconUsageData(from: snapshot)
        #expect(icon?.extraUsage == nil)
    }

    @Test func resetTimePropagates() {
        let resetAt = Date(timeIntervalSince1970: 1_750_000_000)
        let session = UsageQuota(quotaType: .session, percentage: 12.0, resetAt: resetAt)
        let snapshot = UsageSnapshot(providerId: "claude", quotas: [session], capturedAt: Date())

        let icon = makeIconUsageData(from: snapshot)
        #expect(icon?.fiveHour?.resetsAt == resetAt)
    }
}
```

Note: this places the adapter in the **Infrastructure** target (not App) so it's testable. The App layer will import it.

- [ ] **Step 2: Run the test to verify it fails (no `makeIconUsageData` symbol yet)**

```bash
tuist generate
tuist test InfrastructureTests
```

Expected: FAIL — "Cannot find 'makeIconUsageData' in scope" or similar.

---

### Task 3.3: Implement `ClaudeSnapshotToIconData` adapter

**Files:**
- Create: `Sources/Infrastructure/MenuBar/ClaudeSnapshotToIconData.swift`
- Create (move): if needed, place `IconUsageData.swift` in Infrastructure as well so both layers can see it. **Decision: move IconUsageData into Infrastructure too**, since the adapter (Infrastructure) returns it. The App layer imports Infrastructure already.

- [ ] **Step 1: Move `IconUsageData.swift` into Infrastructure**

```bash
mkdir -p Sources/Infrastructure/MenuBar
git mv Sources/App/MenuBar/IconUsageData.swift Sources/Infrastructure/MenuBar/IconUsageData.swift
```

- [ ] **Step 2: Create the adapter**

```swift
// Sources/Infrastructure/MenuBar/ClaudeSnapshotToIconData.swift
import Foundation
import Domain

/// Maps a domain `UsageSnapshot` (Claude provider) into the renderer-facing `IconUsageData`.
/// Returns `nil` when the snapshot itself is `nil` (no usage data fetched yet).
public func makeIconUsageData(from snapshot: UsageSnapshot?) -> IconUsageData? {
    guard let snapshot else { return nil }

    return IconUsageData(
        fiveHour: limitData(in: snapshot, where: { $0 == .session }),
        sevenDay: limitData(in: snapshot, where: { $0 == .weekly }),
        opus: limitData(in: snapshot, where: { isModel($0, named: "opus") }),
        sonnet: limitData(in: snapshot, where: { isModel($0, named: "sonnet") }),
        extraUsage: nil  // not surfaced by current Claude probes
    )
}

private func limitData(in snapshot: UsageSnapshot, where match: (QuotaType) -> Bool) -> IconUsageData.LimitData? {
    guard let quota = snapshot.quotas.first(where: { match($0.quotaType) }) else { return nil }
    return IconUsageData.LimitData(percentage: quota.percentage, resetsAt: quota.resetAt)
}

private func isModel(_ type: QuotaType, named target: String) -> Bool {
    guard case let .modelSpecific(name) = type else { return false }
    return name.lowercased().contains(target.lowercased())
}
```

- [ ] **Step 3: Run the test — expect it to pass**

```bash
tuist generate
tuist test InfrastructureTests
```

Expected: all `ClaudeSnapshotToIconDataTests` pass. If `UsageQuota`'s init signature differs from the test's `(quotaType:percentage:resetAt:)`, open `Sources/Domain/Provider/UsageQuota.swift` and adapt the test calls to the actual init signature — do not change the production type.

- [ ] **Step 4: Commit**

```bash
git add Sources/Infrastructure/MenuBar/ Tests/InfrastructureTests/MenuBar/
git commit -m "feat(menubar): adapter mapping UsageSnapshot to IconUsageData"
```

---

### Task 3.4: Port `IconShapePaths.swift`

**Files:**
- Copy: `/Users/boski/Desktop/desk/Usage4Claude/Usage4Claude/Helpers/IconShapePaths.swift` → `claude4usages/Sources/Infrastructure/MenuBar/IconShapePaths.swift`

- [ ] **Step 1: Copy and adjust headers**

```bash
cp /Users/boski/Desktop/desk/Usage4Claude/Usage4Claude/Helpers/IconShapePaths.swift \
   /Users/boski/Desktop/desk/claude4usages/Sources/Infrastructure/MenuBar/IconShapePaths.swift
```

Open the file; replace its top header comment (`//  Usage4Claude` → `//  claude4usages`). Make the type `public` if it wasn't already so the App layer can use it:

```swift
// At each `class IconShapePaths`, `struct IconShapePaths`, `enum IconShapePaths`, etc.
// Add `public` modifier. Same for static methods — make them `public static`.
```

- [ ] **Step 2: Build**

```bash
tuist generate
tuist build claude4usages
```

Expected: success. If the file references `UIKit`/iOS types, this is a port issue — `IconShapePaths` in Usage4Claude is AppKit-compatible (uses `NSBezierPath`), so it should compile cleanly.

- [ ] **Step 3: Commit**

```bash
git add Sources/Infrastructure/MenuBar/IconShapePaths.swift
git commit -m "feat(menubar): port IconShapePaths from Usage4Claude"
```

---

### Task 3.5: Port `MenuBarIconColorScheme.swift` (renamed from `UsageColorScheme`) with nil-button fallback

**Files:**
- Copy: `/Users/boski/Desktop/desk/Usage4Claude/Usage4Claude/Helpers/ColorScheme.swift` → `claude4usages/Sources/Infrastructure/MenuBar/MenuBarIconColorScheme.swift`

- [ ] **Step 1: Read the Usage4Claude source first to understand its `button` parameter usage**

```bash
cat /Users/boski/Desktop/desk/Usage4Claude/Usage4Claude/Helpers/ColorScheme.swift | head -80
```

- [ ] **Step 2: Copy the file**

```bash
cp /Users/boski/Desktop/desk/Usage4Claude/Usage4Claude/Helpers/ColorScheme.swift \
   /Users/boski/Desktop/desk/claude4usages/Sources/Infrastructure/MenuBar/MenuBarIconColorScheme.swift
```

- [ ] **Step 3: Rename the type and add nil-button fallback**

Open `MenuBarIconColorScheme.swift`. Apply:

1. Rename `UsageColorScheme` → `MenuBarIconColorScheme` (replace all occurrences in the file).
2. Make it `public`.
3. For each method that takes `button: NSStatusBarButton?` and reads `button?.effectiveAppearance` (or similar), add a fallback: when `button == nil`, use `NSApp.effectiveAppearance`. Pattern to replace within each color-decision method:

```swift
// Before:
let appearance = button?.effectiveAppearance ?? NSAppearance.currentDrawing()

// After:
let appearance = button?.effectiveAppearance ?? NSApp.effectiveAppearance
```

(If the existing fallback is already `NSAppearance.currentDrawing()` or `NSApp.effectiveAppearance`, leave it alone — both work for the menu bar context.)

- [ ] **Step 4: Build**

```bash
tuist build claude4usages
```

Expected: success.

- [ ] **Step 5: Commit**

```bash
git add Sources/Infrastructure/MenuBar/MenuBarIconColorScheme.swift
git commit -m "feat(menubar): port color scheme as MenuBarIconColorScheme; nil-button uses NSApp.effectiveAppearance"
```

---

### Task 3.6: Port `ShapeIconRenderer.swift`

**Files:**
- Copy: `/Users/boski/Desktop/desk/Usage4Claude/Usage4Claude/Helpers/ShapeIconRenderer.swift` → `claude4usages/Sources/Infrastructure/MenuBar/ShapeIconRenderer.swift`

- [ ] **Step 1: Copy and update**

```bash
cp /Users/boski/Desktop/desk/Usage4Claude/Usage4Claude/Helpers/ShapeIconRenderer.swift \
   /Users/boski/Desktop/desk/claude4usages/Sources/Infrastructure/MenuBar/ShapeIconRenderer.swift
```

In the new file:
1. Replace any `UsageColorScheme.` reference → `MenuBarIconColorScheme.`.
2. Make the type and its methods `public`.
3. If the file references `IconShapePaths.<method>` and that method is now public, leave alone.

- [ ] **Step 2: Build**

```bash
tuist build claude4usages
```

If the build fails because the renderer references `UserSettings` (Usage4Claude's settings type), do **not** import that — instead, change those references to read from a passed-in parameter or hard-code defaults. The renderer in Usage4Claude likely doesn't reference `UserSettings`; only `MenuBarIconRenderer` does. If it does, refactor the offending method to take the value as a parameter.

- [ ] **Step 3: Commit**

```bash
git add Sources/Infrastructure/MenuBar/ShapeIconRenderer.swift
git commit -m "feat(menubar): port ShapeIconRenderer"
```

---

### Task 3.7: Port `MenuBarIconRenderer.swift` (consume `IconUsageData`)

**Files:**
- Copy: `/Users/boski/Desktop/desk/Usage4Claude/Usage4Claude/App/MenuBarIconRenderer.swift` → `claude4usages/Sources/Infrastructure/MenuBar/MenuBarIconRenderer.swift`

- [ ] **Step 1: Copy**

```bash
cp /Users/boski/Desktop/desk/Usage4Claude/Usage4Claude/App/MenuBarIconRenderer.swift \
   /Users/boski/Desktop/desk/claude4usages/Sources/Infrastructure/MenuBar/MenuBarIconRenderer.swift
```

- [ ] **Step 2: Adapt the file**

Open it and apply:

1. Make `class MenuBarIconRenderer` → `public final class MenuBarIconRenderer`. Make `init`, `createIcon`, and any other consumed method `public`.
2. Replace `UsageData` → `IconUsageData` in the file (struct + parameter types). Replace `LimitType` → `IconLimitType`. The 5 cases stay 1:1 (`.fiveHour`, `.sevenDay`, `.opusWeekly`, `.sonnetWeekly`, `.extraUsage`).
3. The original code has a `UserSettings` dependency. Replace it with a small parameter-bag struct so the renderer doesn't reach into Usage4Claude's settings:

```swift
public struct MenuBarIconRendererSettings: Sendable, Equatable {
    public enum DisplayMode: String, Sendable, Codable, CaseIterable {
        case percentageOnly
        case iconOnly
        case both
    }
    public enum StyleMode: String, Sendable, Codable, CaseIterable {
        case monochrome
        case colorTranslucent
        case colorWithBackground
    }

    public var displayMode: DisplayMode
    public var styleMode: StyleMode
    public var activeTypes: [IconLimitType]

    public init(
        displayMode: DisplayMode = .both,
        styleMode: StyleMode = .colorTranslucent,
        activeTypes: [IconLimitType] = [.fiveHour, .sevenDay, .opusWeekly, .sonnetWeekly]
    ) {
        self.displayMode = displayMode
        self.styleMode = styleMode
        self.activeTypes = activeTypes
    }
}
```

Place that struct at the top of `MenuBarIconRenderer.swift` (or in a sibling file `MenuBarIconRendererSettings.swift` — your call; sibling is cleaner if the file is large).

4. Replace the `init(settings: UserSettings = .shared)` initializer:

```swift
private var settings: MenuBarIconRendererSettings

public init(settings: MenuBarIconRendererSettings = MenuBarIconRendererSettings()) {
    self.settings = settings
}

public func update(settings: MenuBarIconRendererSettings) {
    self.settings = settings
}
```

5. In the body of `createIcon(usageData:hasUpdate:button:)` and helpers, replace every `settings.iconStyleMode` / `settings.iconDisplayMode` / `settings.getActiveDisplayTypes(...)` / `settings.canUseColoredTheme(...)` reference with the new struct's properties:

   - `settings.iconStyleMode` → `settings.styleMode` (same three cases: `.monochrome`, `.colorTranslucent`, `.colorWithBackground`).
   - `settings.iconDisplayMode` → `settings.displayMode` (same three cases).
   - `settings.getActiveDisplayTypes(usageData:)` → just return `settings.activeTypes` (we pre-filtered in claude4usages settings).
   - `settings.canUseColoredTheme(usageData:)` → return `true` always for v1 (i.e., let the user's chosen styleMode dictate; if monochrome, it's monochrome; otherwise color). Replace conditional `forceMonochrome` logic with `let isMonochrome = settings.styleMode == .monochrome`.

6. Strip the AppIcon-display-mode branch's reference to `settings.canUseColoredTheme` similarly.

7. Replace any localized string lookups (`L.MenuBar.something`) with English literals or remove the affected display path entirely (we're English-only).

- [ ] **Step 3: Build**

```bash
tuist generate
tuist build claude4usages
```

Expected: success. If errors mention missing `UserSettings`, `LocalizationHelper`, `L.*`, or other Usage4Claude-only types, fix them by removing the dependency or substituting a literal.

- [ ] **Step 4: Commit**

```bash
git add Sources/Infrastructure/MenuBar/MenuBarIconRenderer.swift
git commit -m "feat(menubar): port MenuBarIconRenderer; consumes IconUsageData + MenuBarIconRendererSettings"
```

---

## Phase 4 — Wire renderer into the app

### Task 4.1: Add menu-bar-icon settings to `AppSettingsRepository` protocol

**Files:**
- Modify: `Sources/Domain/Settings/AppSettingsRepository.swift`

- [ ] **Step 1: Find the protocol**

```bash
grep -n "protocol AppSettingsRepository" Sources/Domain/Settings/AppSettingsRepository.swift
```

- [ ] **Step 2: Add three new method pairs to the protocol**

```swift
// Menu Bar Icon settings
func menuBarIconDisplayMode() -> String
func setMenuBarIconDisplayMode(_ mode: String)

func menuBarIconStyleMode() -> String
func setMenuBarIconStyleMode(_ mode: String)

func menuBarIconActiveTypes() -> [String]
func setMenuBarIconActiveTypes(_ types: [String])
```

- [ ] **Step 3: Build (will fail — `JSONSettingsRepository` no longer conforms)**

```bash
tuist build claude4usages
```

Expected: error in `JSONSettingsRepository.swift` about missing protocol methods. Good — that's the next task.

---

### Task 4.2: Implement menu-bar-icon settings in `JSONSettingsRepository` (TDD)

**Files:**
- Test: `Tests/InfrastructureTests/Storage/JSONSettingsRepositoryMenuBarIconTests.swift` (new)
- Modify: `Sources/Infrastructure/Storage/JSONSettingsRepository.swift`

- [ ] **Step 1: Write the failing test**

```swift
// Tests/InfrastructureTests/Storage/JSONSettingsRepositoryMenuBarIconTests.swift
import Testing
import Foundation
@testable import Infrastructure
@testable import Domain

struct JSONSettingsRepositoryMenuBarIconTests {

    private func makeRepo() -> JSONSettingsRepository {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("c4u-test-\(UUID().uuidString).json")
        let store = JSONSettingsStore(fileURL: tmp)
        return JSONSettingsRepository(store: store)
    }

    @Test func displayModeDefaultsToBoth() {
        let repo = makeRepo()
        #expect(repo.menuBarIconDisplayMode() == "both")
    }

    @Test func styleModeDefaultsToColorTranslucent() {
        let repo = makeRepo()
        #expect(repo.menuBarIconStyleMode() == "colorTranslucent")
    }

    @Test func activeTypesDefaultsToFourPrimaryShapes() {
        let repo = makeRepo()
        #expect(repo.menuBarIconActiveTypes() == ["fiveHour", "sevenDay", "opusWeekly", "sonnetWeekly"])
    }

    @Test func displayModePersists() {
        let repo = makeRepo()
        repo.setMenuBarIconDisplayMode("iconOnly")
        #expect(repo.menuBarIconDisplayMode() == "iconOnly")
    }

    @Test func activeTypesPersists() {
        let repo = makeRepo()
        repo.setMenuBarIconActiveTypes(["fiveHour"])
        #expect(repo.menuBarIconActiveTypes() == ["fiveHour"])
    }
}
```

If `JSONSettingsStore` exposes a different init signature (e.g. `init(fileURL:)` doesn't exist — it might be `init(url:)`), open `Sources/Infrastructure/Storage/JSONSettingsStore.swift` and adjust the test's init call to match.

- [ ] **Step 2: Run test — expect compile failure**

```bash
tuist test InfrastructureTests
```

Expected: FAIL — methods don't exist yet on the repository.

- [ ] **Step 3: Implement the methods in `JSONSettingsRepository`**

Add to `JSONSettingsRepository.swift` inside the class (after the existing `// MARK: - AppSettingsRepository` block):

```swift
// MARK: - Menu Bar Icon

public func menuBarIconDisplayMode() -> String {
    store.read(key: "app.menuBarIcon.displayMode") ?? "both"
}

public func setMenuBarIconDisplayMode(_ mode: String) {
    store.write(value: mode, key: "app.menuBarIcon.displayMode")
}

public func menuBarIconStyleMode() -> String {
    store.read(key: "app.menuBarIcon.styleMode") ?? "colorTranslucent"
}

public func setMenuBarIconStyleMode(_ mode: String) {
    store.write(value: mode, key: "app.menuBarIcon.styleMode")
}

public func menuBarIconActiveTypes() -> [String] {
    store.read(key: "app.menuBarIcon.activeTypes")
        ?? ["fiveHour", "sevenDay", "opusWeekly", "sonnetWeekly"]
}

public func setMenuBarIconActiveTypes(_ types: [String]) {
    store.write(value: types, key: "app.menuBarIcon.activeTypes")
}
```

- [ ] **Step 4: Run test — expect pass**

```bash
tuist test InfrastructureTests
```

Expected: all `JSONSettingsRepositoryMenuBarIconTests` pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/Domain/Settings/AppSettingsRepository.swift \
        Sources/Infrastructure/Storage/JSONSettingsRepository.swift \
        Tests/InfrastructureTests/Storage/JSONSettingsRepositoryMenuBarIconTests.swift
git commit -m "feat(settings): persist menu-bar-icon display/style/active-types"
```

---

### Task 4.3: Add `@Observable` accessors to `AppSettings`

**Files:**
- Modify: `Sources/App/Settings/AppSettings.swift`

- [ ] **Step 1: Add three properties**

In `AppSettings.swift`, add inside the `@Observable` class:

```swift
// MARK: - Menu Bar Icon

public var menuBarIconDisplayMode: String {
    get { repository.menuBarIconDisplayMode() }
    set { repository.setMenuBarIconDisplayMode(newValue) }
}

public var menuBarIconStyleMode: String {
    get { repository.menuBarIconStyleMode() }
    set { repository.setMenuBarIconStyleMode(newValue) }
}

public var menuBarIconActiveTypes: [String] {
    get { repository.menuBarIconActiveTypes() }
    set { repository.setMenuBarIconActiveTypes(newValue) }
}
```

- [ ] **Step 2: Build**

```bash
tuist build claude4usages
```

Expected: success.

- [ ] **Step 3: Commit**

```bash
git add Sources/App/Settings/AppSettings.swift
git commit -m "feat(settings): expose menu-bar-icon settings via @Observable AppSettings"
```

---

### Task 4.4: Replace `StatusBarIcon` with new `MenuBarIconView`

**Files:**
- Modify: `Sources/App/claude4usagesApp.swift` (delete `StatusBarIcon` struct + Preview at bottom; reference new view)
- Create: `Sources/App/MenuBar/MenuBarIconView.swift`

- [ ] **Step 1: Create the new view**

```swift
// Sources/App/MenuBar/MenuBarIconView.swift
import SwiftUI
import AppKit
import Domain
import Infrastructure

/// Renders the Usage4Claude-style shape icons for the current Claude snapshot,
/// re-rendering whenever snapshot or icon settings change.
struct MenuBarIconView: View {
    let snapshot: UsageSnapshot?
    let displayMode: String
    let styleMode: String
    let activeTypes: [String]
    let hasUpdate: Bool

    var body: some View {
        Image(nsImage: rendered)
            .renderingMode(.template == nil ? .original : .original) // placeholder; image's isTemplate flag controls tinting
    }

    private var rendered: NSImage {
        let renderer = MenuBarIconRenderer(settings: rendererSettings)
        let iconData = makeIconUsageData(from: snapshot)
        return renderer.createIcon(usageData: iconData, hasUpdate: hasUpdate, button: nil)
    }

    private var rendererSettings: MenuBarIconRendererSettings {
        MenuBarIconRendererSettings(
            displayMode: MenuBarIconRendererSettings.DisplayMode(rawValue: displayMode) ?? .both,
            styleMode: MenuBarIconRendererSettings.StyleMode(rawValue: styleMode) ?? .colorTranslucent,
            activeTypes: activeTypes.compactMap { IconLimitType(rawValue: $0) }
        )
    }
}
```

Note: the `renderingMode` line above is a placeholder — `Image(nsImage:)` already respects the `NSImage.isTemplate` flag, so simply `Image(nsImage: rendered)` is enough. Remove the `.renderingMode(...)` modifier entirely if the build complains.

- [ ] **Step 2: Update `claude4usagesApp.body`**

In `claude4usagesApp.swift`, change the `MenuBarExtra` `label:` slot:

```swift
// Before:
} label: {
    StatusBarIcon(status: effectiveSelectedProviderStatus, activeSession: sessionMonitor.activeSession)
        .appThemeProvider(themeModeId: settings.themeMode)
}

// After:
} label: {
    MenuBarIconView(
        snapshot: monitor.selectedProvider?.snapshot,
        displayMode: settings.menuBarIconDisplayMode,
        styleMode: settings.menuBarIconStyleMode,
        activeTypes: settings.menuBarIconActiveTypes,
        hasUpdate: hasSparkleUpdate
    )
}
```

Add a helper near the top of the struct:

```swift
private var hasSparkleUpdate: Bool {
    #if ENABLE_SPARKLE
    return sparkleUpdater.updateAvailable
    #else
    return false
    #endif
}
```

(If `SparkleUpdater` doesn't have an `updateAvailable` property, simply return `false` and revisit later — the badge dot is a v2 detail.)

- [ ] **Step 3: Delete the obsolete `StatusBarIcon` struct + its Preview at the bottom of `claude4usagesApp.swift`**

Remove the `struct StatusBarIcon: View { ... }` declaration and the `#Preview("StatusBarIcon - All States")` block (everything from line ~232 to end of file in the original).

- [ ] **Step 4: Build & run**

```bash
tuist generate
tuist build claude4usages
```

Expected: success.

- [ ] **Step 5: Manual smoke test**

```bash
open claude4usages.xcworkspace
# In Xcode, run with Cmd+R. Expect the menu bar to show shape icons.
```

If shape icons render but data hasn't been fetched yet, you'll see the default 0% placeholder (a small empty circle). Click the menu bar to load Claude data, then verify the percentages appear.

- [ ] **Step 6: Commit**

```bash
git add Sources/App/MenuBar/MenuBarIconView.swift Sources/App/claude4usagesApp.swift
git commit -m "feat(menubar): replace StatusBarIcon with MenuBarIconView (Usage4Claude shapes)"
```

---

### Task 4.5: Build the `MenuBarIconSettingsView`

**Files:**
- Create: `Sources/App/Settings/MenuBarIconSettingsView.swift`

- [ ] **Step 1: Create the view**

```swift
// Sources/App/Settings/MenuBarIconSettingsView.swift
import SwiftUI
import Infrastructure

struct MenuBarIconSettingsView: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Form {
            Section("Display") {
                Picker("Mode", selection: $settings.menuBarIconDisplayMode) {
                    Text("Percentage Only").tag("percentageOnly")
                    Text("Icon Only").tag("iconOnly")
                    Text("Both").tag("both")
                }
                .pickerStyle(.segmented)
            }

            Section("Style") {
                Picker("Color", selection: $settings.menuBarIconStyleMode) {
                    Text("Monochrome").tag("monochrome")
                    Text("Color (Translucent)").tag("colorTranslucent")
                    Text("Color (With Background)").tag("colorWithBackground")
                }
                .pickerStyle(.segmented)
            }

            Section("Show These Limits") {
                limitToggle(label: "5-hour session",   value: "fiveHour")
                limitToggle(label: "7-day weekly",     value: "sevenDay")
                limitToggle(label: "Opus weekly",      value: "opusWeekly")
                limitToggle(label: "Sonnet weekly",    value: "sonnetWeekly")
            }
        }
        .padding()
    }

    private func limitToggle(label: String, value: String) -> some View {
        Toggle(label, isOn: Binding(
            get: { settings.menuBarIconActiveTypes.contains(value) },
            set: { isOn in
                var types = settings.menuBarIconActiveTypes
                if isOn {
                    if !types.contains(value) { types.append(value) }
                } else {
                    types.removeAll { $0 == value }
                }
                settings.menuBarIconActiveTypes = types
            }
        ))
    }
}
```

- [ ] **Step 2: Build**

```bash
tuist build claude4usages
```

Expected: success.

- [ ] **Step 3: Commit**

```bash
git add Sources/App/Settings/MenuBarIconSettingsView.swift
git commit -m "feat(settings): MenuBarIconSettingsView UI"
```

---

### Task 4.6: Mount the new settings view in the Settings window

**Files:**
- Modify: whichever existing settings host view drives the tabs in the popover/window. Find with grep.

- [ ] **Step 1: Find the settings host**

```bash
grep -rn "TabView\|TabItem\|Section.*Theme\|SettingsView" Sources/App/ | head -20
```

Look for the file that contains the Settings UI tabs (likely `Sources/App/Views/SettingsView.swift` or similar). Open it.

- [ ] **Step 2: Add a new "Menu Bar Icon" tab/section**

Add a new tab matching the existing pattern in the settings host. For example, if tabs are declared with `.tabItem`:

```swift
MenuBarIconSettingsView(settings: AppSettings.shared)
    .tabItem {
        Label("Menu Bar Icon", systemImage: "menubar.rectangle")
    }
    .tag("menuBarIcon")
```

Place it next to the Theme tab.

- [ ] **Step 3: Build & manual test**

```bash
tuist build claude4usages
open claude4usages.xcworkspace
```

In Xcode run the app, open Settings, go to the new "Menu Bar Icon" tab, toggle each control, and verify the menu bar icon updates live.

- [ ] **Step 4: Commit**

```bash
git add Sources/App/
git commit -m "feat(settings): mount MenuBarIconSettingsView in settings window"
```

---

## Phase 5 — Polish

### Task 5.1: Update `README.md` and `CLAUDE.md`

**Files:**
- Modify: `claude4usages/README.md`
- Modify: `claude4usages/CLAUDE.md`

- [ ] **Step 1: Replace `ClaudeBar` → `claude4usages` in user-facing docs**

```bash
grep -n "ClaudeBar\|claudebar" README.md | head -30
```

For each line, decide:
- Marketing copy referring to the app: replace with `claude4usages`.
- Section about non-Claude providers: delete (the app no longer supports them).
- Repo URL references (`tddworks/ClaudeBar`): replace with a placeholder (e.g. `<your-org>/claude4usages`) or leave with a TODO comment.
- Homebrew cask install line: remove (not published).
- Contributors section: remove (this is a fresh fork).

For `CLAUDE.md`: similar treatment. Update the project overview to say "claude4usages monitors Claude Code usage with programmatically rendered menu bar shape icons (5h / 7d / Opus / Sonnet)."

- [ ] **Step 2: Build (no code change, sanity)**

```bash
tuist build claude4usages
```

- [ ] **Step 3: Commit**

```bash
git add README.md CLAUDE.md
git commit -m "docs: rebrand README and CLAUDE.md for claude4usages"
```

---

### Task 5.2: Final verification

- [ ] **Step 1: Run the full test suite**

```bash
tuist test
```

Expected: all tests pass.

- [ ] **Step 2: Build release**

```bash
tuist build claude4usages -C Release
```

Expected: success.

- [ ] **Step 3: Run the app and walk the golden path**

```bash
open claude4usages.xcworkspace
# Cmd+R in Xcode
```

Verify:
1. Menu bar shows shape icons (or empty placeholder if no Claude data yet).
2. Click menu bar → popover opens, shows Claude usage cards.
3. Refresh → icon updates with current percentages.
4. Settings → Menu Bar Icon tab → toggle display mode → icon changes immediately.
5. Settings → Menu Bar Icon tab → toggle each shape on/off → menu bar updates.
6. Switch macOS appearance Light↔Dark → icon colors update.
7. (Skip Sparkle update test — needs network + appcast.)

- [ ] **Step 4: Commit a final version-stamp marker**

```bash
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString 0.1.0" Sources/App/Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion 1" Sources/App/Info.plist
git add Sources/App/Info.plist
git commit -m "chore: stamp v0.1.0"
```

---

## Self-Review Notes

**Spec coverage:**

- ✅ Architecture (Domain/Infrastructure/App) — preserved as-is via Phase 1.
- ✅ Data mapping (`UsageSnapshot` → `IconUsageData`) — Tasks 3.1–3.3.
- ✅ Icon settings (`displayMode`, `styleMode`, `activeTypes` under `app.menuBarIcon.*`) — Tasks 4.1–4.3.
- ✅ Rebranding (bundle id, settings folder, log path, OSLog subsystem, app name) — Tasks 1.3–1.7.
- ✅ Drop non-Claude providers — Tasks 2.1–2.6.
- ✅ Drop unused external deps — Task 2.8.
- ✅ Replace `StatusBarIcon` view — Task 4.4.
- ✅ Settings UI for icon customization — Tasks 4.5–4.6.
- ✅ Tests for adapter + persistence — Tasks 3.2 and 4.2.
- ✅ Manual verification — Task 5.2.
- ✅ Out-of-scope items (extra-usage hexagon, localization, Multi-account UI, Sparkle URL, real app icon, Homebrew, signing) — explicitly deferred and noted.

**Type-consistency:** `IconUsageData`, `IconLimitType`, `MenuBarIconRendererSettings.{DisplayMode,StyleMode}` are all defined once in Phase 3 and referenced consistently in Phase 4. The `JSONSettingsRepository` getter/setter names (`menuBarIcon{Display,Style}Mode`, `menuBarIconActiveTypes`) match between the protocol (Task 4.1), the impl (Task 4.2), and the `AppSettings` accessors (Task 4.3).

**Placeholder check:** No `TBD` / `TODO` in implementation steps. The only deferred items are explicit out-of-scope features called out in the spec, not in steps. (One `<your-org>` placeholder in Task 5.1 is intentional — a doc placeholder that the user fills in when they create the GitHub repo.)
