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
        if isSessionActive {
            TimelineView(.animation(minimumInterval: 0.05)) { context in
                Image(nsImage: rendered(spinnerPhase: phase(from: context.date)))
            }
        } else {
            Image(nsImage: rendered(spinnerPhase: nil))
        }
    }

    /// Maps the timeline's wall-clock to a 0..<1 phase that completes one full
    /// rotation per second.
    private func phase(from date: Date) -> Double {
        let secondsSinceReference = date.timeIntervalSinceReferenceDate
        return secondsSinceReference.truncatingRemainder(dividingBy: 1.0)
    }

    private func rendered(spinnerPhase: Double?) -> NSImage {
        let renderer = MenuBarIconRenderer(settings: rendererSettings)
        let iconData = makeIconUsageData(from: snapshot)
        return renderer.createIcon(
            usageData: iconData,
            hasUpdate: hasUpdate,
            isSessionActive: isSessionActive,
            spinnerPhase: spinnerPhase,
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
