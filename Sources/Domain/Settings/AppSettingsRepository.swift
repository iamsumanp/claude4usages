import Foundation

/// Repository protocol for all app-level settings (display, sync, budget, etc.).
/// Provider-specific settings live in `ProviderSettingsRepository` sub-protocols.
///
/// Both protocols share one backing store (`~/.claude4usages/settings.json`).
/// `AppSettings` wraps this as an `@Observable` for SwiftUI.
public protocol AppSettingsRepository: Sendable {
    // MARK: - Theme

    func themeMode() -> String
    func setThemeMode(_ mode: String)

    func userHasChosenTheme() -> Bool
    func setUserHasChosenTheme(_ chosen: Bool)

    // MARK: - Display

    func usageDisplayMode() -> String
    func setUsageDisplayMode(_ mode: String)

    func showDailyUsageCards() -> Bool
    func setShowDailyUsageCards(_ show: Bool)

    // MARK: - Overview

    func overviewModeEnabled() -> Bool
    func setOverviewModeEnabled(_ enabled: Bool)

    // MARK: - Background Sync

    func backgroundSyncEnabled() -> Bool
    func setBackgroundSyncEnabled(_ enabled: Bool)

    func backgroundSyncInterval() -> TimeInterval
    func setBackgroundSyncInterval(_ interval: TimeInterval)

    // MARK: - Claude API Budget

    func claudeApiBudgetEnabled() -> Bool
    func setClaudeApiBudgetEnabled(_ enabled: Bool)

    func claudeApiBudget() -> Double
    func setClaudeApiBudget(_ amount: Double)

    // MARK: - Burn Rate Warning

    func burnRateWarningEnabled() -> Bool
    func setBurnRateWarningEnabled(_ enabled: Bool)

    func burnRateThreshold() -> Double
    func setBurnRateThreshold(_ threshold: Double)

    // MARK: - Updates

    func receiveBetaUpdates() -> Bool
    func setReceiveBetaUpdates(_ receive: Bool)

    // MARK: - Menu Bar Icon settings

    func menuBarIconDisplayMode() -> String
    func setMenuBarIconDisplayMode(_ mode: String)

    func menuBarIconStyleMode() -> String
    func setMenuBarIconStyleMode(_ mode: String)

    func menuBarIconActiveTypes() -> [String]
    func setMenuBarIconActiveTypes(_ types: [String])

    // MARK: - Completion Feedback (pulse + sound when Claude finishes a message)

    func completionPulseEnabled() -> Bool
    func setCompletionPulseEnabled(_ enabled: Bool)

    func completionSoundEnabled() -> Bool
    func setCompletionSoundEnabled(_ enabled: Bool)

    func completionSoundName() -> String
    func setCompletionSoundName(_ name: String)
}
