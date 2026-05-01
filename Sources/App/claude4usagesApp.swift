import SwiftUI

extension Notification.Name {
    static let hookSettingsChanged = Notification.Name("com.claude4usages.hookSettingsChanged")
}

@main
struct claude4usagesApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // SwiftUI requires at least one Scene. Use Settings { EmptyView() }
        // to satisfy that without showing a window — the menu bar item is the
        // entire user-visible UI, managed by AppDelegate via NSStatusItem.
        Settings { EmptyView() }
    }
}
