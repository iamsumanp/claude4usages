//
//  ShapeIconRenderer.swift
//  claude4usages
//
//  Created by Claude Code on 2025-12-18.
//  Copyright © 2026 Suman Pokharel. All rights reserved.
//

import AppKit

/// Shape icon renderer.
/// Renders non-circle icons (rounded square, chamfered square, hexagon) with progress rings.
@MainActor
public final class ShapeIconRenderer {

    // MARK: - Helper Methods

    /// Returns the monochrome opacity based on usage percentage (0.8–1.0)
    public static func monochromeOpacity(for percentage: Double) -> CGFloat {
        if percentage <= 50 {
            return 0.8
        } else if percentage <= 75 {
            return 0.9
        } else {
            return 1.0
        }
    }

    // MARK: - Shape Drawing Methods

    /// Draws a rounded-square progress ring with percentage label (used for Opus)
    public static func drawRoundedSquareWithPercentage(in rect: NSRect, percentage: Double, isMonochrome: Bool, button: NSStatusBarButton?, removeBackground: Bool = false) {
        let cornerRadius: CGFloat = 3.0
        let borderWidth: CGFloat = 1.5
        let progressWidth: CGFloat = 2.5
        let center = NSPoint(x: rect.midX, y: rect.midY)

        // 1. Draw background fill (colored-background mode)
        if !removeBackground && !isMonochrome {
            let backgroundFillPath = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
            NSColor.white.withAlphaComponent(0.5).setFill()
            backgroundFillPath.fill()
        }

        // 2. Draw background border
        let backgroundPath = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
        if isMonochrome {
            NSColor.controlTextColor.withAlphaComponent(0.3).setStroke()
        } else {
            NSColor.gray.withAlphaComponent(0.5).setStroke()
        }
        backgroundPath.lineWidth = borderWidth
        backgroundPath.stroke()

        // 3. Draw progress border (clockwise from 12 o'clock)
        if percentage > 0 {
            // Perimeter = 4 straight segments + 4 corner arcs
            let straightLength = 4 * (rect.width - 2 * cornerRadius)
            let arcLength = 2 * CGFloat.pi * cornerRadius
            let perimeter = straightLength + arcLength

            let baseProgressLength = perimeter * CGFloat(percentage / 100.0)
            let progressLength = percentage >= 100 ? baseProgressLength : (baseProgressLength - progressWidth * min(1.0, CGFloat(percentage / 50.0)))

            let progressPath = NSBezierPath()
            let startPoint = NSPoint(x: rect.midX, y: rect.maxY)
            progressPath.move(to: startPoint)

            // Clockwise: 12 o'clock → 3 → 6 → 9 → back to 12
            progressPath.line(to: NSPoint(x: rect.maxX - cornerRadius, y: rect.maxY))
            progressPath.appendArc(
                withCenter: NSPoint(x: rect.maxX - cornerRadius, y: rect.maxY - cornerRadius),
                radius: cornerRadius, startAngle: 90, endAngle: 0, clockwise: true)

            progressPath.line(to: NSPoint(x: rect.maxX, y: rect.minY + cornerRadius))
            progressPath.appendArc(
                withCenter: NSPoint(x: rect.maxX - cornerRadius, y: rect.minY + cornerRadius),
                radius: cornerRadius, startAngle: 0, endAngle: 270, clockwise: true)

            progressPath.line(to: NSPoint(x: rect.minX + cornerRadius, y: rect.minY))
            progressPath.appendArc(
                withCenter: NSPoint(x: rect.minX + cornerRadius, y: rect.minY + cornerRadius),
                radius: cornerRadius, startAngle: 270, endAngle: 180, clockwise: true)

            progressPath.line(to: NSPoint(x: rect.minX, y: rect.maxY - cornerRadius))
            progressPath.appendArc(
                withCenter: NSPoint(x: rect.minX + cornerRadius, y: rect.maxY - cornerRadius),
                radius: cornerRadius, startAngle: 180, endAngle: 90, clockwise: true)

            progressPath.line(to: startPoint)

            let phase: CGFloat = percentage >= 100 ? 0 : -progressWidth / 2
            let pattern: [CGFloat] = [progressLength, perimeter - progressLength]
            progressPath.setLineDash(pattern, count: 2, phase: phase)
            progressPath.lineWidth = progressWidth
            progressPath.lineCapStyle = percentage >= 100 ? .butt : .round

            if isMonochrome {
                let opacity = monochromeOpacity(for: percentage)
                NSColor.controlTextColor.withAlphaComponent(opacity).setStroke()
            } else {
                MenuBarIconColorScheme.opusWeeklyColorAdaptive(percentage, for: button).setStroke()
            }
            progressPath.stroke()
        }

        // 4. Draw percentage label
        let percentageText = "\(Int(percentage))"
        let percentageFontSize: CGFloat = percentage >= 100 ? 5.0 : 7.2
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: percentageFontSize, weight: percentage >= 100 ? .bold : .semibold),
            .foregroundColor: NSColor.black
        ]
        let textSize = percentageText.size(withAttributes: attributes)
        let textRect = NSRect(x: center.x - textSize.width / 2, y: center.y - textSize.height / 2, width: textSize.width, height: textSize.height)
        percentageText.draw(in: textRect, withAttributes: attributes)
    }

    /// Draws a chamfered (top-right clipped) rounded-square progress ring with percentage label (used for Sonnet)
    public static func drawDiamondWithPercentage(in rect: NSRect, percentage: Double, isMonochrome: Bool, button: NSStatusBarButton?, removeBackground: Bool = false) {
        let cornerRadius: CGFloat = 3.0
        let borderWidth: CGFloat = 1.5
        let progressWidth: CGFloat = 2.5
        let cutSize: CGFloat = 3.5
        let center = NSPoint(x: rect.midX, y: rect.midY)

        func createChamferedRectPath(_ rect: NSRect) -> NSBezierPath {
            let path = NSBezierPath()
            path.move(to: NSPoint(x: rect.minX, y: rect.minY + cornerRadius))
            path.appendArc(
                withCenter: NSPoint(x: rect.minX + cornerRadius, y: rect.minY + cornerRadius),
                radius: cornerRadius, startAngle: 180, endAngle: 270, clockwise: false)
            path.line(to: NSPoint(x: rect.maxX - cornerRadius, y: rect.minY))
            path.appendArc(
                withCenter: NSPoint(x: rect.maxX - cornerRadius, y: rect.minY + cornerRadius),
                radius: cornerRadius, startAngle: 270, endAngle: 0, clockwise: false)
            path.line(to: NSPoint(x: rect.maxX, y: rect.maxY - cutSize))
            path.line(to: NSPoint(x: rect.maxX - cutSize, y: rect.maxY))
            path.line(to: NSPoint(x: rect.minX + cornerRadius, y: rect.maxY))
            path.appendArc(
                withCenter: NSPoint(x: rect.minX + cornerRadius, y: rect.maxY - cornerRadius),
                radius: cornerRadius, startAngle: 90, endAngle: 180, clockwise: false)
            path.close()
            return path
        }

        // 1. Draw background fill
        if !removeBackground && !isMonochrome {
            let backgroundFillPath = createChamferedRectPath(rect)
            NSColor.white.withAlphaComponent(0.5).setFill()
            backgroundFillPath.fill()
        }

        // 2. Draw background border
        let backgroundPath = createChamferedRectPath(rect)
        if isMonochrome {
            NSColor.controlTextColor.withAlphaComponent(0.3).setStroke()
        } else {
            NSColor.gray.withAlphaComponent(0.5).setStroke()
        }
        backgroundPath.lineWidth = borderWidth
        backgroundPath.stroke()

        // 3. Draw progress border
        if percentage > 0 {
            let progressPath = NSBezierPath()
            let startPoint = NSPoint(x: rect.midX, y: rect.maxY)
            progressPath.move(to: startPoint)

            progressPath.line(to: NSPoint(x: rect.maxX - cutSize, y: rect.maxY))
            progressPath.line(to: NSPoint(x: rect.maxX, y: rect.maxY - cutSize))
            progressPath.line(to: NSPoint(x: rect.maxX, y: rect.minY + cornerRadius))
            progressPath.appendArc(
                withCenter: NSPoint(x: rect.maxX - cornerRadius, y: rect.minY + cornerRadius),
                radius: cornerRadius, startAngle: 0, endAngle: 270, clockwise: true)
            progressPath.line(to: NSPoint(x: rect.minX + cornerRadius, y: rect.minY))
            progressPath.appendArc(
                withCenter: NSPoint(x: rect.minX + cornerRadius, y: rect.minY + cornerRadius),
                radius: cornerRadius, startAngle: 270, endAngle: 180, clockwise: true)
            progressPath.line(to: NSPoint(x: rect.minX, y: rect.maxY - cornerRadius))
            progressPath.appendArc(
                withCenter: NSPoint(x: rect.minX + cornerRadius, y: rect.maxY - cornerRadius),
                radius: cornerRadius, startAngle: 180, endAngle: 90, clockwise: true)
            progressPath.line(to: startPoint)

            // Compute chamfered perimeter
            let opusStraightLength = 4 * (rect.width - 2 * cornerRadius)
            let opusArcLength = 2 * CGFloat.pi * cornerRadius
            let opusPerimeter = opusStraightLength + opusArcLength
            let cornerArcReduction = -cornerRadius * .pi / 2
            let edgeAdjustment = 2.0 * cornerRadius
            let cutAdjustment = cutSize * (sqrt(2.0) - 2.0)
            let perimeter = opusPerimeter + cornerArcReduction + edgeAdjustment + cutAdjustment

            let baseProgressLength = perimeter * CGFloat(percentage / 100.0)
            let progressLength = percentage >= 100 ? baseProgressLength : (baseProgressLength - progressWidth * min(1.0, CGFloat(percentage / 50.0)))

            let phase: CGFloat = percentage >= 100 ? 0 : -progressWidth / 2
            let pattern: [CGFloat] = [progressLength, perimeter - progressLength]
            progressPath.setLineDash(pattern, count: 2, phase: phase)
            progressPath.lineWidth = progressWidth
            progressPath.lineCapStyle = percentage >= 100 ? .butt : .round

            if isMonochrome {
                let opacity = monochromeOpacity(for: percentage)
                NSColor.controlTextColor.withAlphaComponent(opacity).setStroke()
            } else {
                MenuBarIconColorScheme.sonnetWeeklyColorAdaptive(percentage, for: button).setStroke()
            }
            progressPath.stroke()
        }

        // 4. Draw percentage label
        let percentageText = "\(Int(percentage))"
        let percentageFontSize: CGFloat = percentage >= 100 ? 5.0 : 7.2
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: percentageFontSize, weight: percentage >= 100 ? .bold : .semibold),
            .foregroundColor: NSColor.black
        ]
        let textSize = percentageText.size(withAttributes: attributes)
        let textRect = NSRect(x: center.x - textSize.width / 2, y: center.y - textSize.height / 2, width: textSize.width, height: textSize.height)
        percentageText.draw(in: textRect, withAttributes: attributes)
    }

    /// Draws a flat-top hexagon progress ring with percentage label (used for Extra Usage)
    public static func drawHexagonWithPercentage(center: NSPoint, size: CGFloat, percentage: Double, isMonochrome: Bool, button: NSStatusBarButton?, removeBackground: Bool = false) {
        let radius = size / 2
        let borderWidth: CGFloat = 1.5
        let progressWidth: CGFloat = 2.5

        let hexagonPath = NSBezierPath()
        for i in 0..<6 {
            let angle = CGFloat(i) * CGFloat.pi / 3.0
            let x = center.x + radius * cos(angle)
            let y = center.y + radius * sin(angle)
            if i == 0 {
                hexagonPath.move(to: NSPoint(x: x, y: y))
            } else {
                hexagonPath.line(to: NSPoint(x: x, y: y))
            }
        }
        hexagonPath.close()

        // 1. Draw background fill
        if !removeBackground && !isMonochrome {
            NSColor.white.withAlphaComponent(0.5).setFill()
            hexagonPath.fill()
        }

        // 2. Draw background border
        if isMonochrome {
            NSColor.controlTextColor.withAlphaComponent(0.3).setStroke()
        } else {
            NSColor.gray.withAlphaComponent(0.5).setStroke()
        }
        hexagonPath.lineWidth = borderWidth
        hexagonPath.lineJoinStyle = .round
        hexagonPath.stroke()

        // 3. Draw progress border
        if percentage > 0 {
            let sideLength = radius
            let perimeter = sideLength * 6

            let baseProgressLength = perimeter * CGFloat(percentage / 100.0)
            let progressLength = percentage >= 100 ? baseProgressLength : (baseProgressLength - progressWidth * min(1.0, CGFloat(percentage / 50.0)))

            var vertices: [NSPoint] = []
            for i in 0..<6 {
                let angle = CGFloat(i) * CGFloat.pi / 3.0
                let x = center.x + radius * cos(angle)
                let y = center.y + radius * sin(angle)
                vertices.append(NSPoint(x: x, y: y))
            }

            let topMidpoint = NSPoint(
                x: (vertices[1].x + vertices[2].x) / 2,
                y: (vertices[1].y + vertices[2].y) / 2
            )

            let progressHexagon = NSBezierPath()
            progressHexagon.move(to: topMidpoint)
            progressHexagon.line(to: vertices[1])
            progressHexagon.line(to: vertices[0])
            progressHexagon.line(to: vertices[5])
            progressHexagon.line(to: vertices[4])
            progressHexagon.line(to: vertices[3])
            progressHexagon.line(to: vertices[2])
            progressHexagon.line(to: topMidpoint)

            let phase: CGFloat = percentage >= 100 ? 0 : -progressWidth / 2
            let pattern: [CGFloat] = [progressLength, perimeter - progressLength]
            progressHexagon.setLineDash(pattern, count: 2, phase: phase)
            progressHexagon.lineWidth = progressWidth
            progressHexagon.lineCapStyle = percentage >= 100 ? .butt : .round
            progressHexagon.lineJoinStyle = .round

            if isMonochrome {
                let opacity = monochromeOpacity(for: percentage)
                NSColor.controlTextColor.withAlphaComponent(opacity).setStroke()
            } else {
                MenuBarIconColorScheme.extraUsageColorAdaptive(percentage, for: button).setStroke()
            }
            progressHexagon.stroke()
        }

        // 4. Draw percentage label
        let percentageText = "\(Int(percentage))"
        let percentageFontSize: CGFloat = percentage >= 100 ? 5.0 : 7.2
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: percentageFontSize, weight: percentage >= 100 ? .bold : .semibold),
            .foregroundColor: NSColor.black
        ]
        let textSize = percentageText.size(withAttributes: attributes)
        let textRect = NSRect(x: center.x - textSize.width / 2, y: center.y - textSize.height / 2, width: textSize.width, height: textSize.height)
        percentageText.draw(in: textRect, withAttributes: attributes)
    }

    // MARK: - Icon Creation Methods

    /// Creates a rounded-square icon (Opus) — 18×18
    public static func createVerticalRectangleIcon(percentage: Double, isMonochrome: Bool, button: NSStatusBarButton?, removeBackground: Bool = false) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()
        let rect = NSRect(x: 0, y: 0, width: size.width, height: size.height).insetBy(dx: 2, dy: 2)
        drawRoundedSquareWithPercentage(in: rect, percentage: percentage, isMonochrome: isMonochrome, button: button, removeBackground: removeBackground)
        image.unlockFocus()
        image.isTemplate = isMonochrome
        return image
    }

    /// Creates a chamfered-square icon (Sonnet) — 18×18
    public static func createHorizontalRectangleIcon(percentage: Double, isMonochrome: Bool, button: NSStatusBarButton?, removeBackground: Bool = false) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()
        let rect = NSRect(x: 0, y: 0, width: size.width, height: size.height).insetBy(dx: 2, dy: 2)
        drawDiamondWithPercentage(in: rect, percentage: percentage, isMonochrome: isMonochrome, button: button, removeBackground: removeBackground)
        image.unlockFocus()
        image.isTemplate = isMonochrome
        return image
    }

    /// Creates a flat-top hexagon icon (Extra Usage) — 18×18
    public static func createHexagonIcon(percentage: Double, isMonochrome: Bool, button: NSStatusBarButton?, removeBackground: Bool = false) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()
        let center = NSPoint(x: size.width / 2, y: size.height / 2)
        drawHexagonWithPercentage(center: center, size: 16, percentage: percentage, isMonochrome: isMonochrome, button: button, removeBackground: removeBackground)
        image.unlockFocus()
        image.isTemplate = isMonochrome
        return image
    }
}
