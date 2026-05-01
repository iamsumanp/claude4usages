import Foundation
import AppKit

/// Loads the bundled Anthropic-asterisk app icon PNG from the Infrastructure target's resource bundle.
/// Used by both the menu bar renderer and the popover header so they share the same artwork.
public enum AppIconResource {
    /// - Parameter monochrome: if true, returns `AppIconReverse.png` flagged as a template image
    ///   (so AppKit tints it to match the foreground color); otherwise returns the colored `AppIcon.png`.
    public static func image(monochrome: Bool) -> NSImage? {
        let resourceName = monochrome ? "AppIconReverse" : "AppIcon"
        guard let url = Bundle.module.url(forResource: resourceName, withExtension: "png"),
              let image = NSImage(contentsOf: url) else {
            return nil
        }
        image.isTemplate = monochrome
        return image
    }
}
