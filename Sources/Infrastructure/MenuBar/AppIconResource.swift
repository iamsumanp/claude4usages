import Foundation
import AppKit

/// Loads the bundled Anthropic-asterisk app icon PNG from the Infrastructure target's resource bundle.
/// Used by both the menu bar renderer and the popover header so they share the same artwork.
public enum AppIconResource {
    /// - Parameter monochrome: if true, returns `AppIconReverse.png` flagged as a template image
    ///   (so AppKit tints it to match the foreground color); otherwise returns the colored `AppIcon.png`.
    public static func image(monochrome: Bool) -> NSImage? {
        let resourceName = monochrome ? "AppIconReverse" : "AppIcon"
        guard let bundle = resourceBundle,
              let url = bundle.url(forResource: resourceName, withExtension: "png"),
              let image = NSImage(contentsOf: url) else {
            return nil
        }
        image.isTemplate = monochrome
        return image
    }

    /// Locates the Infrastructure target's resource bundle without using the SwiftPM-generated
    /// `Bundle.module`, which calls `fatalError` (crashing the whole app) when the bundle is
    /// missing — e.g. if a packaging step fails to copy it into `Contents/Resources`. We search
    /// the same candidate locations but return `nil` on failure so a missing icon degrades gracefully.
    private static let resourceBundle: Bundle? = {
        let bundleName = "claude4usages_Infrastructure.bundle"
        let candidates = [
            Bundle.main.resourceURL,
            Bundle(for: BundleToken.self).resourceURL,
            Bundle.main.bundleURL,
            // .app bundles place SwiftPM resource bundles under Contents/Resources.
            Bundle.main.resourceURL?.deletingLastPathComponent(),
        ]
        for case let candidate? in candidates {
            let url = candidate.appendingPathComponent(bundleName)
            if let bundle = Bundle(url: url) {
                return bundle
            }
        }
        // Fall back to the bundle containing this class (covers test/CLI contexts).
        return Bundle(for: BundleToken.self)
    }()

    private final class BundleToken {}
}
