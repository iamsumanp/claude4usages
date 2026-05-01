//
//  MenuBarIconRenderer.swift
//  claude4usages
//
//  Created by Claude Code on 2025-12-02.
//  Copyright © 2025 f-is-h. All rights reserved.
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
    ///   - button: Status bar button (used to read effective appearance)
    /// - Returns: The rendered icon image
    public func createIcon(
        usageData: IconUsageData?,
        hasUpdate: Bool,
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
            icon = createCombinedPercentageIcon(data: data, types: activeTypes, isMonochrome: isMonochrome, button: button)

        case .iconOnly:
            if let iconCopy = loadAppIconImage(isMonochrome: isMonochrome) {
                icon = iconCopy
            } else {
                icon = createSimpleCircleIcon()
            }

        case .both:
            icon = createCombinedIconWithAppIcon(data: data, types: activeTypes, isMonochrome: isMonochrome, button: button)
        }

        if hasUpdate {
            icon = addBadgeToImage(icon)
        }

        return icon
    }

    /// Creates an icon for a single limit type, suitable for testing or previews.
    public func createIconForType(
        _ type: IconLimitType,
        data: IconUsageData,
        isMonochrome: Bool,
        button: NSStatusBarButton?
    ) -> NSImage? {
        let removeBackground = settings.styleMode == .colorTranslucent
        // Always show placeholder (0%) when data is nil — callers pre-filter inactive types
        let showPlaceholder = true

        switch type {
        case .fiveHour:
            let percentage = data.fiveHour?.percentage ?? (showPlaceholder ? 0 : nil)
            guard let percentage else { return nil }
            if isMonochrome {
                return createCircleTemplateImage(percentage: percentage, size: NSSize(width: 18, height: 18), button: button, removeBackground: true)
            } else {
                return createCircleImage(percentage: percentage, size: NSSize(width: 18, height: 18), button: button, removeBackground: removeBackground)
            }

        case .sevenDay:
            let percentage = data.sevenDay?.percentage ?? (showPlaceholder ? 0 : nil)
            guard let percentage else { return nil }
            if isMonochrome {
                return createCircleTemplateImage(percentage: percentage, size: NSSize(width: 18, height: 18), useSevenDayStyle: true, button: button, removeBackground: true)
            } else {
                return createCircleImage(percentage: percentage, size: NSSize(width: 18, height: 18), useSevenDayColor: true, button: button, removeBackground: removeBackground)
            }

        case .opusWeekly:
            let percentage = data.opus?.percentage ?? (showPlaceholder ? 0 : nil)
            guard let percentage else { return nil }
            return ShapeIconRenderer.createVerticalRectangleIcon(percentage: percentage, isMonochrome: isMonochrome, button: button, removeBackground: removeBackground)

        case .sonnetWeekly:
            let percentage = data.sonnet?.percentage ?? (showPlaceholder ? 0 : nil)
            guard let percentage else { return nil }
            return ShapeIconRenderer.createHorizontalRectangleIcon(percentage: percentage, isMonochrome: isMonochrome, button: button, removeBackground: removeBackground)

        case .extraUsage:
            let percentage: Double?
            if let extraUsage = data.extraUsage, extraUsage.enabled {
                percentage = extraUsage.percentage
            } else if showPlaceholder {
                percentage = 0
            } else {
                percentage = nil
            }
            guard let percentage else { return nil }
            return ShapeIconRenderer.createHexagonIcon(percentage: percentage, isMonochrome: isMonochrome, button: button, removeBackground: removeBackground)
        }
    }

    // MARK: - Private Composite Methods

    private func createCombinedPercentageIcon(
        data: IconUsageData,
        types: [IconLimitType],
        isMonochrome: Bool,
        button: NSStatusBarButton?
    ) -> NSImage {
        guard !types.isEmpty else { return createSimpleCircleIcon() }

        let icons = types.compactMap { type in
            createIconForType(type, data: data, isMonochrome: isMonochrome, button: button)
        }

        if icons.isEmpty {
            return createSimpleCircleIcon()
        } else if icons.count == 1 {
            return icons[0]
        } else {
            let combined = combineIcons(icons, spacing: 3.0, height: 18)
            combined.isTemplate = isMonochrome
            return combined
        }
    }

    private func createCombinedIconWithAppIcon(
        data: IconUsageData,
        types: [IconLimitType],
        isMonochrome: Bool,
        button: NSStatusBarButton?
    ) -> NSImage {
        guard let appIconCopy = loadAppIconImage(isMonochrome: isMonochrome) else {
            return createCombinedPercentageIcon(data: data, types: types, isMonochrome: isMonochrome, button: button)
        }

        let percentageIcons = types.compactMap { type in
            createIconForType(type, data: data, isMonochrome: isMonochrome, button: button)
        }

        var allIcons = [appIconCopy]
        allIcons.append(contentsOf: percentageIcons)

        let combined = combineIcons(allIcons, spacing: 3.0, height: 18)
        combined.isTemplate = isMonochrome
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

    private func loadAppIconImage(isMonochrome: Bool) -> NSImage? {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }

        let center = NSPoint(x: size.width / 2, y: size.height / 2)
        let outerRadius: CGFloat = size.width * 0.45
        let petalWidth: CGFloat = size.width * 0.20

        let fillColor: NSColor = isMonochrome ? .black : NSColor(srgbRed: 0.84, green: 0.45, blue: 0.27, alpha: 1.0)
        fillColor.setFill()

        let path = NSBezierPath()
        for arm in 0..<4 {
            let angle = CGFloat(arm) * .pi / 2
            let dx = cos(angle)
            let dy = sin(angle)
            let tipX = center.x + dx * outerRadius
            let tipY = center.y + dy * outerRadius
            let baseX = center.x - dx * (petalWidth * 0.4)
            let baseY = center.y - dy * (petalWidth * 0.4)
            let halfWidth = petalWidth / 2
            let perpX = -dy * halfWidth
            let perpY = dx * halfWidth

            path.move(to: NSPoint(x: tipX, y: tipY))
            path.curve(
                to: NSPoint(x: baseX + perpX, y: baseY + perpY),
                controlPoint1: NSPoint(x: center.x + dx * outerRadius * 0.4 + perpX * 0.6, y: center.y + dy * outerRadius * 0.4 + perpY * 0.6),
                controlPoint2: NSPoint(x: center.x + perpX, y: center.y + perpY)
            )
            path.line(to: NSPoint(x: baseX - perpX, y: baseY - perpY))
            path.curve(
                to: NSPoint(x: tipX, y: tipY),
                controlPoint1: NSPoint(x: center.x - perpX, y: center.y - perpY),
                controlPoint2: NSPoint(x: center.x + dx * outerRadius * 0.4 - perpX * 0.6, y: center.y + dy * outerRadius * 0.4 - perpY * 0.6)
            )
            path.close()
        }
        path.fill()

        image.isTemplate = isMonochrome
        return image
    }
}
