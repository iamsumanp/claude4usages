import SwiftUI
import AppKit
import Domain
import Infrastructure

/// SwiftUI wrapper that renders the menu bar shape icons via MenuBarIconRenderer.
@MainActor
struct MenuBarIconView: View {
    let monitor: QuotaMonitor
    let sessionMonitor: SessionMonitor
    let displayMode: String
    let styleMode: String
    let activeTypes: [String]
    let hasUpdate: Bool

    var body: some View {
        // Reading these @Observable properties inside the body lets SwiftUI
        // track them and re-render the menu bar label when they change —
        // including when the popover is closed. (Previously the parent App
        // struct didn't re-evaluate its body for sessionMonitor changes.)
        Image(nsImage: rendered(
            snapshot: monitor.selectedProvider?.snapshot,
            isSessionActive: sessionMonitor.activeSession != nil
        ))
    }

    private func rendered(snapshot: UsageSnapshot?, isSessionActive: Bool) -> NSImage {
        let renderer = MenuBarIconRenderer(settings: rendererSettings)
        let iconData = makeIconUsageData(from: snapshot)
        return renderer.createIcon(
            usageData: iconData,
            hasUpdate: hasUpdate,
            isSessionActive: isSessionActive,
            button: nil
        )
    }

    private var rendererSettings: MenuBarIconRendererSettings {
        MenuBarIconRendererSettings(
            displayMode: MenuBarIconRendererSettings.DisplayMode(rawValue: displayMode) ?? .both,
            styleMode: MenuBarIconRendererSettings.StyleMode(rawValue: styleMode) ?? .colorTranslucent,
            activeTypes: activeTypes.compactMap { IconLimitType(rawValue: $0) }
        )
    }
}
