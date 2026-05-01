//
//  MenuBarIconRenderer.swift
//  claude4usages
//
//  Created by Claude Code on 2025-12-02.
//  Copyright © 2026 Suman Pokharel. All rights reserved.
//

import AppKit

// MARK: - Settings

/// Renderer configuration — passed into MenuBarIconRenderer instead of coupling to UserSettings.
public struct MenuBarIconRendererSettings: Sendable, Equatable {
    public enum DisplayMode: String, Sendable, Codable, CaseIterable {
        case percentageOnly
        case iconOnly
        case both
    }
    public enum StyleMode: String, Sendable, Codable, CaseIterable {
        case monochrome
        case colorTranslucent
        case colorWithBackground
    }

    public var displayMode: DisplayMode
    public var styleMode: StyleMode
    public var activeTypes: [IconLimitType]

    public init(
        displayMode: DisplayMode = .both,
        styleMode: StyleMode = .colorTranslucent,
        activeTypes: [IconLimitType] = [.fiveHour, .sevenDay, .opusWeekly, .sonnetWeekly]
    ) {
        self.displayMode = displayMode
        self.styleMode = styleMode
        self.activeTypes = activeTypes
    }
}

// MARK: - Renderer

/// Menu bar icon renderer.
/// Draws shape-icons for the menu bar status item using IconUsageData.
@MainActor
public final class MenuBarIconRenderer {

    // MARK: - State

    private var settings: MenuBarIconRendererSettings

    // MARK: - Initialization

    public init(settings: MenuBarIconRendererSettings = MenuBarIconRendererSettings()) {
        self.settings = settings
    }

    public func update(settings: MenuBarIconRendererSettings) {
        self.settings = settings
    }

    // MARK: - Public API

    /// Creates the menu bar icon image.
    /// - Parameters:
    ///   - usageData: Usage data snapshot (nil renders a bare placeholder)
    ///   - hasUpdate: Whether an update badge should be shown
    ///   - isSessionActive: Whether a Claude Code session is currently active
    ///   - spinnerPhase: 0..<1 phase to draw a rotating spinner around the icon. nil = no spinner.
    ///   - button: Status bar button (used to read effective appearance)
    /// - Returns: The rendered icon image
    public func createIcon(
        usageData: IconUsageData?,
        hasUpdate: Bool,
        isSessionActive: Bool = false,
        spinnerPhase: Double? = nil,
        button: NSStatusBarButton?
    ) -> NSImage {
        guard let data = usageData else {
            let size = NSSize(width: 22, height: 22)
            return settings.styleMode == .monochrome ?
                createCircleTemplateImage(percentage: 0, size: size, button: button, removeBackground: true) :
                createCircleImage(percentage: 0, size: size, button: button, removeBackground: true)
        }

        let activeTypes = settings.activeTypes
        let isMonochrome = settings.styleMode == .monochrome

        var icon: NSImage

        switch settings.displayMode {
        case .percentageOnly:
            let activeColor: NSColor? = isSessionActive
                ? NSColor(srgbRed: 0.30, green: 0.78, blue: 0.45, alpha: 1.0) : nil
            icon = createCombinedPercentageIcon(data: data, types: activeTypes, isMonochrome: isMonochrome,
                                                activeOverride: activeColor, button: button)

        case .iconOnly:
            if let iconCopy = loadAppIconImage(isMonochrome: isMonochrome, sessionActive: isSessionActive) {
                icon = iconCopy
            } else {
                icon = createSimpleCircleIcon()
            }

        case .both:
            icon = createCombinedIconWithAppIcon(
                data: data,
                types: activeTypes,
                isMonochrome: isMonochrome,
                sessionActive: isSessionActive,
                button: button
            )
        }

        if hasUpdate {
            icon = addBadgeToImage(icon)
        }
        if let phase = spinnerPhase, isSessionActive {
            icon = addSpinnerArc(to: icon, phase: phase)
        }

        return icon
    }

    /// Overlays a rotating arc around the leading edge of the icon to indicate
    /// activity. Phase is 0..<1 and represents one full rotation.
    private func addSpinnerArc(to baseImage: NSImage, phase: Double) -> NSImage {
        let pad: CGFloat = 4
        let originalSize = baseImage.size
        let expanded = NSSize(width: originalSize.width + pad * 2, height: originalSize.height + pad * 2)

        let result = NSImage(size: expanded)
        result.lockFocus()
        defer {
            result.unlockFocus()
            result.isTemplate = false
        }

        // Draw the original icon centred
        baseImage.draw(in: NSRect(origin: NSPoint(x: pad, y: pad), size: originalSize))

        // Draw arc — a 90° wedge that rotates over time
        let center = NSPoint(x: expanded.width / 2, y: expanded.height / 2)
        let radius = (min(expanded.width, expanded.height) / 2) - 1
        let startDeg = phase * 360
        let endDeg = startDeg + 90

        let path = NSBezierPath()
        path.appendArc(withCenter: center, radius: radius, startAngle: CGFloat(startDeg), endAngle: CGFloat(endDeg), clockwise: false)
        path.lineWidth = 1.5
        path.lineCapStyle = .round

        NSColor(srgbRed: 0.30, green: 0.78, blue: 0.45, alpha: 1.0).setStroke()
        path.stroke()

        return result
    }

    /// Creates an icon for a single limit type.
    /// - Parameter activeOverride: when non-nil, overrides the stroke/fill colour with this
    ///   fixed colour so circles remain visible alongside a non-template icon (e.g. active session).
    public func createIconForType(
        _ type: IconLimitType,
        data: IconUsageData,
        isMonochrome: Bool,
        activeOverride: NSColor? = nil,
        button: NSStatusBarButton?
    ) -> NSImage? {
        let removeBackground = settings.styleMode == .colorTranslucent

        switch type {
        case .fiveHour:
            let percentage = data.fiveHour?.percentage ?? 0
            if let activeColor = activeOverride {
                return createCircleActiveImage(percentage: percentage, color: activeColor, size: NSSize(width: 18, height: 18))
            }
            if isMonochrome {
                return createCircleTemplateImage(percentage: percentage, size: NSSize(width: 18, height: 18), button: button, removeBackground: true)
            }
            return createCircleImage(percentage: percentage, size: NSSize(width: 18, height: 18), button: button, removeBackground: removeBackground)

        case .sevenDay:
            let percentage = data.sevenDay?.percentage ?? 0
            if let activeColor = activeOverride {
                return createCircleActiveImage(percentage: percentage, color: activeColor, size: NSSize(width: 18, height: 18), dashed: true)
            }
            if isMonochrome {
                return createCircleTemplateImage(percentage: percentage, size: NSSize(width: 18, height: 18), useSevenDayStyle: true, button: button, removeBackground: true)
            }
            return createCircleImage(percentage: percentage, size: NSSize(width: 18, height: 18), useSevenDayColor: true, button: button, removeBackground: removeBackground)

        case .opusWeekly:
            let percentage = data.opus?.percentage ?? 0
            return ShapeIconRenderer.createVerticalRectangleIcon(percentage: percentage, isMonochrome: activeOverride == nil && isMonochrome, button: button, removeBackground: removeBackground)

        case .sonnetWeekly:
            let percentage = data.sonnet?.percentage ?? 0
            return ShapeIconRenderer.createHorizontalRectangleIcon(percentage: percentage, isMonochrome: activeOverride == nil && isMonochrome, button: button, removeBackground: removeBackground)

        case .extraUsage:
            let percentage = (data.extraUsage?.enabled == true) ? (data.extraUsage?.percentage ?? 0) : 0
            return ShapeIconRenderer.createHexagonIcon(percentage: percentage, isMonochrome: activeOverride == nil && isMonochrome, button: button, removeBackground: removeBackground)
        }
    }

    /// Draws a circle progress indicator in a fixed `color` — used when the combined
    /// icon is non-template (e.g. active session) so the circles stay visible.
    private func createCircleActiveImage(
        percentage: Double,
        color: NSColor,
        size: NSSize,
        dashed: Bool = false
    ) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }

        let center = NSPoint(x: size.width / 2, y: size.height / 2)
        let radius = min(size.width, size.height) / 2 - 2

        // Track
        color.withAlphaComponent(0.25).setStroke()
        let track = NSBezierPath()
        track.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360, clockwise: false)
        track.lineWidth = 1.5
        if dashed { track.setLineDash([3, 1], count: 2, phase: 0) }
        track.stroke()

        // Progress arc
        if percentage > 0 {
            color.setStroke()
            let arc = NSBezierPath()
            let sweep = CGFloat(percentage) / 100.0 * 360
            arc.appendArc(withCenter: center, radius: radius, startAngle: 90, endAngle: 90 - sweep, clockwise: true)
            arc.lineWidth = 2.0
            arc.lineCapStyle = .round
            arc.stroke()
        }

        // Percentage label
        let fontSize: CGFloat = percentage >= 100 ? size.width * 0.275 : size.width * 0.38
        let font = NSFont.systemFont(ofSize: fontSize, weight: .semibold)
        let text = "\(Int(percentage))"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]
        let textSize = text.size(withAttributes: attrs)
        text.draw(at: NSPoint(x: center.x - textSize.width / 2, y: center.y - textSize.height / 2), withAttributes: attrs)

        image.isTemplate = false
        return image
    }

    // MARK: - Private Composite Methods

    private func createCombinedPercentageIcon(
        data: IconUsageData,
        types: [IconLimitType],
        isMonochrome: Bool,
        activeOverride: NSColor? = nil,
        button: NSStatusBarButton?
    ) -> NSImage {
        guard !types.isEmpty else { return createSimpleCircleIcon() }

        let icons = types.compactMap { type in
            createIconForType(type, data: data, isMonochrome: isMonochrome, activeOverride: activeOverride, button: button)
        }

        if icons.isEmpty {
            return createSimpleCircleIcon()
        } else if icons.count == 1 {
            return icons[0]
        } else {
            let combined = combineIcons(icons, spacing: 3.0, height: 18)
            combined.isTemplate = isMonochrome && activeOverride == nil
            return combined
        }
    }

    private func createCombinedIconWithAppIcon(
        data: IconUsageData,
        types: [IconLimitType],
        isMonochrome: Bool,
        sessionActive: Bool = false,
        button: NSStatusBarButton?
    ) -> NSImage {
        guard let appIconCopy = loadAppIconImage(isMonochrome: isMonochrome, sessionActive: sessionActive) else {
            return createCombinedPercentageIcon(data: data, types: types, isMonochrome: isMonochrome, button: button)
        }

        // When session active, render circles in green (not template black) so
        // they're visible alongside the non-template green asterisk.
        let activeColor: NSColor? = sessionActive
            ? NSColor(srgbRed: 0.30, green: 0.78, blue: 0.45, alpha: 1.0)
            : nil
        let percentageIcons = types.compactMap { type in
            createIconForType(type, data: data, isMonochrome: isMonochrome,
                              activeOverride: activeColor, button: button)
        }

        var allIcons = [appIconCopy]
        allIcons.append(contentsOf: percentageIcons)

        let combined = combineIcons(allIcons, spacing: 3.0, height: 18)
        combined.isTemplate = isMonochrome && !sessionActive
        return combined
    }

    // MARK: - Circle Drawing (Colored Mode)

    private func createCircleImage(
        percentage: Double,
        size: NSSize,
        useSevenDayColor: Bool = false,
        button: NSStatusBarButton?,
        removeBackground: Bool = false
    ) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()

        let center = NSPoint(x: size.width / 2, y: size.height / 2)
        let radius = min(size.width, size.height) / 2 - 2

        if !removeBackground {
            let backgroundCircle = NSBezierPath()
            backgroundCircle.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360, clockwise: false)
            NSColor.white.withAlphaComponent(0.5).setFill()
            backgroundCircle.fill()
        }

        NSColor.gray.withAlphaComponent(0.5).setStroke()
        let backgroundPath = NSBezierPath()
        backgroundPath.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360, clockwise: false)
        backgroundPath.lineWidth = 1.5
        if useSevenDayColor {
            let dashPattern: [CGFloat] = [3, 1]
            backgroundPath.setLineDash(dashPattern, count: dashPattern.count, phase: 0)
        }
        backgroundPath.stroke()

        let color = useSevenDayColor
            ? MenuBarIconColorScheme.sevenDayColorAdaptive(percentage, for: button)
            : MenuBarIconColorScheme.fiveHourColorAdaptive(percentage, for: button)
        color.setStroke()

        let progressPath = NSBezierPath()
        let lineWidth: CGFloat = 2.5
        let baseAngle = CGFloat(percentage) / 100.0 * 360
        let circumference = 2 * CGFloat.pi * radius
        let capAngle = (lineWidth / circumference) * 360

        let progressAngle: CGFloat
        let startAngle: CGFloat

        if percentage >= 100 {
            progressAngle = baseAngle
            startAngle = 90
        } else {
            progressAngle = baseAngle - capAngle * min(1.0, CGFloat(percentage / 50.0))
            startAngle = 90 - capAngle / 2 + 0.5
        }

        let endAngle = startAngle - progressAngle
        progressPath.appendArc(withCenter: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
        progressPath.lineWidth = lineWidth
        progressPath.lineCapStyle = percentage >= 100 ? .butt : .round
        progressPath.stroke()

        let fontSize: CGFloat = percentage >= 100 ? size.width * 0.275 : size.width * 0.4
        let font = NSFont.systemFont(ofSize: fontSize, weight: percentage >= 100 ? .bold : .semibold)
        let text = "\(Int(percentage))"
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.black, .paragraphStyle: paragraphStyle]
        let textSize = text.size(withAttributes: attrs)
        let textOrigin = NSPoint(x: center.x - textSize.width / 2, y: center.y - textSize.height / 2)
        text.draw(at: textOrigin, withAttributes: attrs)

        image.unlockFocus()
        return image
    }

    // MARK: - Circle Drawing (Template/Monochrome Mode)

    private func createCircleTemplateImage(
        percentage: Double,
        size: NSSize,
        useSevenDayStyle: Bool = false,
        button: NSStatusBarButton? = nil,
        removeBackground: Bool = false
    ) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()

        let center = NSPoint(x: size.width / 2, y: size.height / 2)
        let radius = min(size.width, size.height) / 2 - 2

        NSColor.labelColor.withAlphaComponent(0.25).setStroke()
        let backgroundPath = NSBezierPath()
        backgroundPath.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360, clockwise: false)
        backgroundPath.lineWidth = 1.5
        if useSevenDayStyle {
            let dashPattern: [CGFloat] = [3, 1]
            backgroundPath.setLineDash(dashPattern, count: dashPattern.count, phase: 0)
        }
        backgroundPath.stroke()

        NSColor.labelColor.setStroke()
        let progressPath = NSBezierPath()
        let lineWidth: CGFloat = 2.5
        let baseAngle = CGFloat(percentage) / 100.0 * 360
        let circumference = 2 * CGFloat.pi * radius
        let capAngle = (lineWidth / circumference) * 360

        let progressAngle: CGFloat
        let startAngle: CGFloat

        if percentage >= 100 {
            progressAngle = baseAngle
            startAngle = 90
        } else {
            progressAngle = baseAngle - capAngle * min(1.0, CGFloat(percentage / 50.0))
            startAngle = 90 - capAngle / 2 + 0.5
        }

        let endAngle = startAngle - progressAngle
        progressPath.appendArc(withCenter: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
        progressPath.lineWidth = lineWidth
        progressPath.lineCapStyle = percentage >= 100 ? .butt : .round
        progressPath.stroke()

        let fontSize: CGFloat = percentage >= 100 ? size.width * 0.275 : size.width * 0.4
        let font = NSFont.systemFont(ofSize: fontSize, weight: percentage >= 100 ? .bold : .semibold)
        let text = "\(Int(percentage))"
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.black, .paragraphStyle: paragraphStyle]
        let textSize = text.size(withAttributes: attrs)
        text.draw(at: NSPoint(x: center.x - textSize.width / 2, y: center.y - textSize.height / 2), withAttributes: attrs)

        image.unlockFocus()
        image.isTemplate = true
        return image
    }

    // MARK: - Utility

    private func createSimpleCircleIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()
        let rect = NSRect(x: 3, y: 3, width: 12, height: 12)
        let path = NSBezierPath(ovalIn: rect)
        NSColor.labelColor.setStroke()
        path.lineWidth = 2.0
        path.stroke()
        image.unlockFocus()
        image.isTemplate = true
        return image
    }

    private func addBadgeToImage(_ baseImage: NSImage) -> NSImage {
        let size = baseImage.size
        let expandedSize = NSSize(width: size.width + 2.5, height: size.height + 2.5)
        let badgedImage = NSImage(size: expandedSize)

        badgedImage.lockFocus()
        baseImage.draw(in: NSRect(origin: .zero, size: size))

        let badgeRadius: CGFloat = 2.0
        let badgeDiameter = badgeRadius * 2
        let badgeX = expandedSize.width - badgeDiameter - 1.5
        let badgeY = expandedSize.height - badgeDiameter - 1.5
        let badgeRect = NSRect(x: badgeX, y: badgeY, width: badgeDiameter, height: badgeDiameter)

        NSGraphicsContext.saveGraphicsState()
        NSColor.systemRed.setFill()
        NSBezierPath(ovalIn: badgeRect).fill()
        NSGraphicsContext.restoreGraphicsState()

        badgedImage.unlockFocus()
        badgedImage.isTemplate = baseImage.isTemplate
        return badgedImage
    }

    private func combineIcons(_ icons: [NSImage], spacing: CGFloat = 3.0, height: CGFloat = 18) -> NSImage {
        guard !icons.isEmpty else { return createSimpleCircleIcon() }

        let totalWidth = icons.reduce(0) { $0 + $1.size.width } + CGFloat(icons.count - 1) * spacing
        let size = NSSize(width: totalWidth, height: height)
        let image = NSImage(size: size)
        image.lockFocus()

        var currentX: CGFloat = 0
        for icon in icons {
            let y = (height - icon.size.height) / 2
            icon.draw(at: NSPoint(x: currentX, y: y),
                     from: NSRect(origin: .zero, size: icon.size),
                     operation: .sourceOver,
                     fraction: 1.0)
            currentX += icon.size.width + spacing
        }

        image.unlockFocus()
        return image
    }

    private func loadAppIconImage(isMonochrome: Bool, sessionActive: Bool = false) -> NSImage? {
        let resourceName = isMonochrome ? "AppIconReverse" : "AppIcon"
        guard let url = Bundle.module.url(forResource: resourceName, withExtension: "png"),
              let baseImage = NSImage(contentsOf: url) else {
            return nil
        }

        let size = NSSize(width: 18, height: 18)
        baseImage.size = size

        // Inactive: return as-is (template in monochrome, raw colors otherwise)
        guard sessionActive else {
            baseImage.isTemplate = isMonochrome
            return baseImage
        }

        // Active: bake a green tint into the image and disable template flag
        // so the green stays even in monochrome mode.
        let tinted = NSImage(size: size)
        tinted.lockFocus()
        defer { tinted.unlockFocus() }

        let rect = NSRect(origin: .zero, size: size)
        let activeColor = NSColor(srgbRed: 0.30, green: 0.78, blue: 0.45, alpha: 1.0)

        if isMonochrome {
            // Use the alpha mask of the (white-on-clear) AppIconReverse to fill green
            baseImage.draw(in: rect)
            activeColor.set()
            rect.fill(using: .sourceAtop)
        } else {
            // Color icon — multiply with green to keep some shape while signalling active
            baseImage.draw(in: rect)
            activeColor.withAlphaComponent(0.55).set()
            rect.fill(using: .sourceAtop)
        }

        tinted.isTemplate = false
        return tinted
    }
}
