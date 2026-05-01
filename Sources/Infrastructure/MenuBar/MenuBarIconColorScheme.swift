//
//  MenuBarIconColorScheme.swift
//  claude4usages
//
//  Created by Claude on 2025-11-26.
//  Copyright © 2026 Suman Pokharel. All rights reserved.
//

import AppKit

/// Unified color scheme for menu bar icons.
/// Provides 5-hour and 7-day limit colors; supports AppKit and SwiftUI.
@MainActor
public enum MenuBarIconColorScheme {

    // MARK: - Appearance Detection

    /// Detects whether the current appearance is dark mode.
    /// - Parameter statusButton: Optional status bar button for accurate appearance info
    /// - Returns: true for dark mode, false for light mode
    public static func isDarkMode(for statusButton: NSStatusBarButton? = nil) -> Bool {
        // Use status bar button appearance first (most accurate — reflects true menu bar appearance)
        let appearance = statusButton?.effectiveAppearance ?? NSApp.effectiveAppearance
        if let best = appearance.bestMatch(from: [.darkAqua, .aqua]) {
            return best == .darkAqua
        }

        // Fallback: read system preference directly
        return UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
    }

    /// Convenience property — detects dark mode without a button reference
    public static var isDarkMode: Bool {
        return isDarkMode(for: nil)
    }

    // MARK: - 5-Hour Limit Colors (green → orange → red)

    /// Returns an NSColor for the 5-hour limit based on usage percentage.
    /// - Note: 0–70% green (safe), 70–90% orange (warning), 90–100% red (critical)
    public static func fiveHourColor(_ percentage: Double) -> NSColor {
        if percentage < 70 {
            return NSColor(red: 40/255.0, green: 180/255.0, blue: 70/255.0, alpha: 1.0)  // #28B446
        } else if percentage < 90 {
            return NSColor.systemOrange
        } else {
            return NSColor.systemRed
        }
    }

    /// Returns an appearance-adaptive NSColor for the 5-hour limit.
    public static func fiveHourColorAdaptive(_ percentage: Double, for statusButton: NSStatusBarButton? = nil) -> NSColor {
        let baseColor = fiveHourColor(percentage)
        return isDarkMode(for: statusButton) ? baseColor.adjustedForDarkMode() : baseColor
    }

    // MARK: - 7-Day Limit Colors (light purple → deep purple → dark purple-red)

    /// Returns an NSColor for the 7-day limit based on usage percentage.
    /// - Note: 0–70% light purple (safe), 70–90% deep purple (warning), 90–100% dark purple-red (critical)
    public static func sevenDayColor(_ percentage: Double) -> NSColor {
        if percentage < 70 {
            return NSColor(red: 192/255.0, green: 132/255.0, blue: 252/255.0, alpha: 1.0)  // #C084FC
        } else if percentage < 90 {
            return NSColor(red: 180/255.0, green: 80/255.0, blue: 240/255.0, alpha: 1.0)   // #B450F0
        } else {
            return NSColor(red: 180/255.0, green: 30/255.0, blue: 160/255.0, alpha: 1.0)   // #B41EA0
        }
    }

    /// Returns an appearance-adaptive NSColor for the 7-day limit.
    public static func sevenDayColorAdaptive(_ percentage: Double, for statusButton: NSStatusBarButton? = nil) -> NSColor {
        let baseColor = sevenDayColor(percentage)
        return isDarkMode(for: statusButton) ? baseColor.adjustedForDarkMode() : baseColor
    }

    // MARK: - Extra Usage Colors (pink → rose → purple-red)

    /// Returns an NSColor for Extra Usage based on usage percentage.
    /// - Note: 0–70% pink (safe), 70–90% rose (warning), 90–100% purple-red (critical)
    public static func extraUsageColor(_ percentage: Double) -> NSColor {
        if percentage < 70 {
            return NSColor(red: 255/255.0, green: 158/255.0, blue: 205/255.0, alpha: 1.0)  // #FF9ECD
        } else if percentage < 90 {
            return NSColor(red: 236/255.0, green: 72/255.0, blue: 153/255.0, alpha: 1.0)   // #EC4899
        } else {
            return NSColor(red: 217/255.0, green: 70/255.0, blue: 239/255.0, alpha: 1.0)   // #D946EF
        }
    }

    /// Returns an appearance-adaptive NSColor for Extra Usage.
    public static func extraUsageColorAdaptive(_ percentage: Double, for statusButton: NSStatusBarButton? = nil) -> NSColor {
        let baseColor = extraUsageColor(percentage)
        return isDarkMode(for: statusButton) ? baseColor.adjustedForDarkMode() : baseColor
    }

    // MARK: - Opus Weekly Colors (amber → orange → orange-red)

    /// Returns an NSColor for the Opus weekly limit based on usage percentage.
    /// - Note: 0–70% amber (safe), 70–90% orange (warning), 90–100% orange-red (critical)
    public static func opusWeeklyColor(_ percentage: Double) -> NSColor {
        if percentage < 70 {
            return NSColor(red: 251/255.0, green: 191/255.0, blue: 36/255.0, alpha: 1.0)   // #FBBF24
        } else if percentage < 90 {
            return NSColor.systemOrange
        } else {
            return NSColor(red: 255/255.0, green: 100/255.0, blue: 50/255.0, alpha: 1.0)   // #FF6432
        }
    }

    /// Returns an appearance-adaptive NSColor for the Opus weekly limit.
    public static func opusWeeklyColorAdaptive(_ percentage: Double, for statusButton: NSStatusBarButton? = nil) -> NSColor {
        let baseColor = opusWeeklyColor(percentage)
        return isDarkMode(for: statusButton) ? baseColor.adjustedForDarkMode() : baseColor
    }

    // MARK: - Sonnet Weekly Colors (light blue → blue → indigo)

    /// Returns an NSColor for the Sonnet weekly limit based on usage percentage.
    /// - Note: 0–70% light blue (safe), 70–90% blue (warning), 90–100% deep indigo (critical)
    public static func sonnetWeeklyColor(_ percentage: Double) -> NSColor {
        if percentage < 70 {
            return NSColor(red: 100/255.0, green: 200/255.0, blue: 255/255.0, alpha: 1.0)  // #64C8FF
        } else if percentage < 90 {
            return NSColor.systemBlue
        } else {
            return NSColor(red: 79/255.0, green: 70/255.0, blue: 229/255.0, alpha: 1.0)    // #4F46E5
        }
    }

    /// Returns an appearance-adaptive NSColor for the Sonnet weekly limit.
    public static func sonnetWeeklyColorAdaptive(_ percentage: Double, for statusButton: NSStatusBarButton? = nil) -> NSColor {
        let baseColor = sonnetWeeklyColor(percentage)
        return isDarkMode(for: statusButton) ? baseColor.adjustedForDarkMode() : baseColor
    }
}

// MARK: - NSColor Extension

extension NSColor {
    /// Adjusts a color for dark mode by increasing brightness and saturation.
    /// - Returns: A brighter version suitable for dark backgrounds.
    func adjustedForDarkMode() -> NSColor {
        guard let rgbColor = self.usingColorSpace(.deviceRGB) else {
            return self
        }

        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        rgbColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        let adjustedBrightness = min(1.0, max(0.75, brightness * 1.4))
        let adjustedSaturation = min(1.0, saturation * 1.0)

        return NSColor(hue: hue, saturation: adjustedSaturation, brightness: adjustedBrightness, alpha: alpha)
    }
}
