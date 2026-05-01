import SwiftUI
import AppKit
import Domain
import Infrastructure

/// SwiftUI wrapper that renders the menu bar shape icons via MenuBarIconRenderer.
@MainActor
struct MenuBarIconView: View {
    let snapshot: UsageSnapshot?
    let displayMode: String
    let styleMode: String
    let activeTypes: [String]
    let hasUpdate: Bool
    let isSessionActive: Bool

    var body: some View {
        Image(nsImage: rendered)
    }

    private var rendered: NSImage {
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
