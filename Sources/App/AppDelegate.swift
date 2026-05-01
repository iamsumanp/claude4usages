import AppKit
import SwiftUI
import Domain
import Infrastructure

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!

    // Domain state (was on claude4usagesApp)
    let monitor: QuotaMonitor
    let sessionMonitor = SessionMonitor()
    let hookServer = HookHTTPServer()
    private(set) var hookServerTask: Task<Void, Never>?
    let quotaAlerter = NotificationAlerter()
    let sessionAlertSender = SystemAlertSender()
    let settingsRepository: JSONSettingsRepository

    private let appSettings = AppSettings.shared

    // Token used to cancel + re-register observation tracking when re-rendering the icon
    private var iconRedrawToken: UInt = 0

    // Hook-driven busy indicator: green while Claude is actively responding, white when idle.
    private var isIconSessionActive: Bool = false {
        didSet {
            guard isIconSessionActive != oldValue else { return }
            if let button = statusItem?.button {
                button.image = nil
                button.image = renderIconWithActive(isIconSessionActive)
                button.needsDisplay = true
            }
        }
    }

    override init() {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        AppLog.ui.info("claude4usages v\(version) (\(build)) initializing...")

        // Create the shared settings repository (JSON-backed: ~/.claude4usages/settings.json)
        let repo = JSONSettingsRepository.shared
        settingsRepository = repo

        // Create all providers with their probes (rich domain models)
        let repository = AIProviders(providers: [
            ClaudeProvider(
                probe: ClaudeUsageProbe(),
                passProbe: ClaudePassProbe(),
                settingsRepository: repo,
                dailyUsageAnalyzer: ClaudeDailyUsageAnalyzer()
            ),
        ])
        AppLog.providers.info("Created \(repository.all.count) providers")

        // Initialize the domain service with quota alerter
        let alerter = NotificationAlerter()
        monitor = QuotaMonitor(
            providers: repository,
            alerter: alerter
        )
        AppLog.monitor.info("QuotaMonitor initialized")

        super.init()

        // Load user extensions from ~/.claude4usages/extensions/
        let extensionRegistry = ExtensionRegistry(
            settingsRepository: repo,
            configRepository: AppSettings.shared.extensionConfig
        )
        let extensionProviders = extensionRegistry.loadExtensions(into: monitor)
        if !extensionProviders.isEmpty {
            AppLog.providers.info("Loaded \(extensionProviders.count) extension provider(s): \(extensionProviders.map(\.name).joined(separator: ", "))")
        }

        AppLog.ui.info("claude4usages initialization complete")
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        setupStatusItem()
        setupPopover()

        if settingsRepository.isHookEnabled() {
            startHookServer()
        }

        // Initial refresh + optional background monitoring
        Task { @MainActor in
            // Request notification permission once (after the run loop is active)
            _ = await quotaAlerter.requestPermission()

            // Initial refresh for all enabled providers
            await withTaskGroup(of: Void.self) { group in
                for provider in monitor.enabledProviders {
                    group.addTask {
                        _ = try? await provider.refresh()
                    }
                }
            }

            if appSettings.backgroundSyncEnabled {
                let interval = Duration.seconds(appSettings.backgroundSyncInterval)
                let stream = monitor.startMonitoring(interval: interval)
                for await _ in stream { /* QuotaMonitor handles internally */ }
            }
        }

        // Reactive icon updates — re-render whenever monitor / sessionMonitor / settings change
        scheduleIconRedraw()
    }

    // MARK: - Status Item Setup

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(togglePopover(_:))
            button.image = renderIcon()
        }
    }

    // MARK: - Popover Setup

    private func setupPopover() {
        popover = NSPopover()
        popover.behavior = .transient  // closes when clicking outside
        popover.animates = true

        let content = MenuContentView(
            monitor: monitor,
            sessionMonitor: sessionMonitor,
            quotaAlerter: quotaAlerter,
            onHookSettingsChanged: { [weak self] enabled in
                if enabled { self?.startHookServer() } else { self?.stopHookServer() }
            }
        )
        .appThemeProvider(themeModeId: appSettings.themeMode)

        let host = NSHostingController(rootView: content)
        popover.contentViewController = host
        popover.contentSize = NSSize(width: 400, height: 500)
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    // MARK: - Reactive Icon Redraw

    /// Use `withObservationTracking` to register reads and re-render once any of them changes.
    /// After re-rendering, re-register for the next change cycle.
    private func scheduleIconRedraw() {
        iconRedrawToken &+= 1
        let token = iconRedrawToken

        withObservationTracking {
            statusItem.button?.image = renderIcon()
        } onChange: { [weak self] in
            // Hop back onto main actor before mutating UI / re-registering
            DispatchQueue.main.async {
                guard let self else { return }
                guard self.iconRedrawToken == token else { return }  // a newer registration superseded
                self.scheduleIconRedraw()
            }
        }
    }

    private func renderIcon() -> NSImage {
        renderIconWithActive(isIconSessionActive)
    }

    private func renderIconWithActive(_ active: Bool) -> NSImage {
        let renderer = MenuBarIconRenderer(settings: rendererSettings)
        let iconData = makeIconUsageData(from: monitor.selectedProvider?.snapshot)
        return renderer.createIcon(
            usageData: iconData,
            hasUpdate: false,
            isSessionActive: active,
            button: statusItem?.button
        )
    }

    private var rendererSettings: MenuBarIconRendererSettings {
        MenuBarIconRendererSettings(
            displayMode: MenuBarIconRendererSettings.DisplayMode(rawValue: appSettings.menuBarIconDisplayMode) ?? .both,
            styleMode: MenuBarIconRendererSettings.StyleMode(rawValue: appSettings.menuBarIconStyleMode) ?? .colorTranslucent,
            activeTypes: appSettings.menuBarIconActiveTypes.compactMap { IconLimitType(rawValue: $0) }
        )
    }

    // MARK: - Hook Server

    func startHookServer() {
        hookServerTask?.cancel()
        hookServer.stop()

        hookServerTask = Task { @MainActor in
            do {
                let events = try await hookServer.start()
                AppLog.hooks.info("Hook server started, listening for events")
                for await event in events {
                    sessionMonitor.processEvent(event)
                    handleSessionEventForIcon(event)
                    sendSessionNotification(for: event)
                }
            } catch {
                AppLog.hooks.error("Failed to start hook server: \(error.localizedDescription)")
            }
        }
    }

    func stopHookServer() {
        hookServerTask?.cancel()
        hookServerTask = nil
        hookServer.stop()
    }

    // MARK: - Hook-driven completion pulse

    private var pulseTimer: Timer?

    /// Smooth opacity pulse when Claude finishes answering.
    /// Renders the green icon once, then animates button.alphaValue on a sine wave
    /// (hardware-composited by macOS — no bitmap re-allocation per frame).
    private func handleSessionEventForIcon(_ event: SessionEvent) {
        switch event.eventName {
        case .stop, .sessionEnd:
            startCompletionPulse()
        default:
            break
        }
    }

    private func startCompletionPulse() {
        pulseTimer?.invalidate()
        guard let button = statusItem?.button else { return }

        // Show green icon for the duration of the pulse
        isIconSessionActive = true

        var elapsed: TimeInterval = 0
        let pulsePeriod: TimeInterval = 1.6   // seconds per full sine cycle
        let totalDuration: TimeInterval = 4.8  // 3 full pulses

        pulseTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] timer in
            elapsed += 0.05
            guard elapsed < totalDuration else {
                timer.invalidate()
                button.alphaValue = 1.0
                self?.isIconSessionActive = false
                return
            }
            // Sine wave: smoothly oscillates between 0.25 and 1.0
            let sine = sin(elapsed * 2 * .pi / pulsePeriod)  // -1 … +1
            button.alphaValue = CGFloat(0.625 + 0.375 * sine) // 0.25 … 1.0
        }
        RunLoop.main.add(pulseTimer!, forMode: .common)
    }

    // MARK: - Session Notifications

    @MainActor private func sendSessionNotification(for event: SessionEvent) {
        let projectName = (event.cwd as NSString).lastPathComponent

        switch event.eventName {
        case .sessionStart:
            Task {
                try? await sessionAlertSender.send(
                    title: "Claude Code Started",
                    body: "Session started in \(projectName)",
                    categoryIdentifier: "SESSION_START"
                )
            }
        case .sessionEnd:
            let taskCount = sessionMonitor.recentSessions.first?.completedTaskCount ?? 0
            let duration = sessionMonitor.recentSessions.first?.durationDescription ?? ""
            let summary = taskCount > 0
                ? "Completed \(taskCount) task\(taskCount == 1 ? "" : "s") in \(duration)"
                : "Session ended after \(duration)"
            Task {
                try? await sessionAlertSender.send(
                    title: "Claude Code Finished",
                    body: "\(projectName) — \(summary)",
                    categoryIdentifier: "SESSION_END"
                )
            }
        default:
            break
        }
    }
}
