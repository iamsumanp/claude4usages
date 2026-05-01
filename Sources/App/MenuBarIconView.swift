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
            .overlay(alignment: .topLeading) {
                if isSessionActive {
                    Circle()
                        .fill(Color(nsColor: NSColor(srgbRed: 0.30, green: 0.78, blue: 0.45, alpha: 1.0)))
                        .frame(width: 5, height: 5)
                        .offset(x: -1, y: -1)
                }
            }
    }

    private var rendered: NSImage {
        let renderer = MenuBarIconRenderer(settings: rendererSettings)
        let iconData = makeIconUsageData(from: snapshot)
        // Pass isSessionActive: false here — the dot is overlaid in SwiftUI above
        // so we don't blow away the template flag on the underlying image.
        return renderer.createIcon(
            usageData: iconData,
            hasUpdate: hasUpdate,
            isSessionActive: false,
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
