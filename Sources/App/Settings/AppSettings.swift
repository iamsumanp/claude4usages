import Foundation
import Domain
import Infrastructure
import ServiceManagement

/// Observable settings manager for claude4usages preferences.
/// Thin `@Observable` wrapper around `AppSettingsRepository` for SwiftUI reactivity.
/// All persistence is delegated to the repository (`~/.claude4usages/settings.json`).
@MainActor
@Observable
public final class AppSettings {
    public static let shared = AppSettings()

    /// The underlying repository (internal - views access settings through AppSettings properties/methods)
    private let repository: JSONSettingsRepository

    // MARK: - Theme Settings

    /// The current theme mode (cli)
    public var themeMode: String {
        didSet {
            repository.setThemeMode(themeMode)
        }
    }

    // MARK: - Display Settings

    /// Whether to show quota as "remaining" or "used"
    public var usageDisplayMode: UsageDisplayMode {
        didSet {
            repository.setUsageDisplayMode(usageDisplayMode.rawValue)
        }
    }

    /// Whether to show daily usage report cards (API Cost, Token Usage, Working Time)
    public var showDailyUsageCards: Bool {
        didSet {
            repository.setShowDailyUsageCards(showDailyUsageCards)
        }
    }

    // MARK: - Overview Mode Settings

    /// Whether to show all enabled providers at once instead of one at a time
    public var overviewModeEnabled: Bool {
        didSet {
            repository.setOverviewModeEnabled(overviewModeEnabled)
        }
    }

    // MARK: - Background Sync Settings

    /// Whether background sync is enabled (default: false)
    public var backgroundSyncEnabled: Bool {
        didSet {
            repository.setBackgroundSyncEnabled(backgroundSyncEnabled)
        }
    }

    /// Background sync interval in seconds (default: 60)
    public var backgroundSyncInterval: TimeInterval {
        didSet {
            repository.setBackgroundSyncInterval(backgroundSyncInterval)
        }
    }

    // MARK: - Claude API Budget Settings

    /// Whether Claude API budget tracking is enabled
    public var claudeApiBudgetEnabled: Bool {
        didSet {
            repository.setClaudeApiBudgetEnabled(claudeApiBudgetEnabled)
        }
    }

    /// The budget threshold for Claude API usage (in dollars)
    public var claudeApiBudget: Decimal {
        didSet {
            repository.setClaudeApiBudget(NSDecimalNumber(decimal: claudeApiBudget).doubleValue)
        }
    }

    // MARK: - Burn Rate Warning Settings

    /// Whether burn rate-based warnings are enabled (default: false, uses absolute thresholds)
    public var burnRateWarningEnabled: Bool {
        didSet {
            repository.setBurnRateWarningEnabled(burnRateWarningEnabled)
        }
    }

    /// The burn rate multiplier threshold above which warnings fire (default: 1.5)
    public var burnRateThreshold: Double {
        didSet {
            repository.setBurnRateThreshold(burnRateThreshold)
        }
    }

    // MARK: - Update Settings

    /// Whether to receive beta updates (default: false)
    public var receiveBetaUpdates: Bool {
        didSet {
            repository.setReceiveBetaUpdates(receiveBetaUpdates)
            NotificationCenter.default.post(name: .betaUpdatesSettingChanged, object: nil)
        }
    }

    // MARK: - Launch at Login Settings

    /// Whether the app should launch at login (backed by SMAppService, not JSON)
    public var launchAtLogin: Bool {
        didSet {
            guard !isInitializing else { return }
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                launchAtLogin = SMAppService.mainApp.status == .enabled
            }
        }
    }

    // MARK: - Menu Bar Icon Settings

    /// Display mode for the menu bar icon ("percentageOnly", "iconOnly", "both")
    public var menuBarIconDisplayMode: String {
        didSet {
            repository.setMenuBarIconDisplayMode(menuBarIconDisplayMode)
        }
    }

    /// Style mode for the menu bar icon ("monochrome", "colorTranslucent", "colorWithBackground")
    public var menuBarIconStyleMode: String {
        didSet {
            repository.setMenuBarIconStyleMode(menuBarIconStyleMode)
        }
    }

    /// Which limit types to show in the menu bar icon
    public var menuBarIconActiveTypes: [String] {
        didSet {
            repository.setMenuBarIconActiveTypes(menuBarIconActiveTypes)
        }
    }

    // MARK: - Completion Feedback Settings

    /// Whether the menu bar icon pulses green when Claude finishes a message
    public var completionPulseEnabled: Bool {
        didSet {
            repository.setCompletionPulseEnabled(completionPulseEnabled)
        }
    }

    /// Whether to play a sound when Claude finishes a message
    public var completionSoundEnabled: Bool {
        didSet {
            repository.setCompletionSoundEnabled(completionSoundEnabled)
        }
    }

    /// Name of the macOS system sound to play (e.g. "Pop", "Glass", "Purr", "Bottle")
    public var completionSoundName: String {
        didSet {
            repository.setCompletionSoundName(completionSoundName)
        }
    }

    // MARK: - Internal

    private var isInitializing = true

    // MARK: - Initialization

    private init(repository: JSONSettingsRepository = .shared) {
        self.repository = repository

        // Load all values from repository
        self.themeMode = repository.themeMode()
        self.claudeApiBudgetEnabled = repository.claudeApiBudgetEnabled()
        self.claudeApiBudget = Decimal(repository.claudeApiBudget())
        self.receiveBetaUpdates = repository.receiveBetaUpdates()
        self.burnRateWarningEnabled = repository.burnRateWarningEnabled()
        self.burnRateThreshold = repository.burnRateThreshold()
        self.showDailyUsageCards = repository.showDailyUsageCards()
        self.overviewModeEnabled = repository.overviewModeEnabled()
        self.backgroundSyncEnabled = repository.backgroundSyncEnabled()
        self.backgroundSyncInterval = repository.backgroundSyncInterval()

        if let mode = UsageDisplayMode(rawValue: repository.usageDisplayMode()) {
            self.usageDisplayMode = mode
        } else {
            self.usageDisplayMode = .remaining
        }

        self.menuBarIconDisplayMode = repository.menuBarIconDisplayMode()
        self.menuBarIconStyleMode = repository.menuBarIconStyleMode()
        self.menuBarIconActiveTypes = repository.menuBarIconActiveTypes()

        self.completionPulseEnabled = repository.completionPulseEnabled()
        self.completionSoundEnabled = repository.completionSoundEnabled()
        self.completionSoundName = repository.completionSoundName()

        // Launch at login - read from SMAppService (system service, not JSON)
        self.launchAtLogin = SMAppService.mainApp.status == .enabled

        self.isInitializing = false
    }

    // MARK: - Provider Settings Access

    /// Access provider-specific settings for reading/writing in Settings UI.
    /// These are non-observable (loaded into @State) - only app-level settings are @Observable.
    public var provider: ProviderSettingsRepository { repository }
    public var claude: ClaudeSettingsRepository { repository }
    public var hook: HookSettingsRepository { repository }

    /// Extension config repository for dynamic extension provider settings.
    public let extensionConfig: any ExtensionConfigRepository = JSONExtensionConfigRepository(
        settingsStore: .shared
    )
}

// MARK: - Notification Names

extension Notification.Name {
    static let betaUpdatesSettingChanged = Notification.Name("betaUpdatesSettingChanged")
}
