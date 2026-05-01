//
//  IconShapePaths.swift
//  claude4usages
//
//  Created by Claude Code on 2025-12-18.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import SwiftUI

/// Icon shape path utilities.
/// Provides shape path generation methods for all limit type icons.
/// Supports both SwiftUI Path and NSBezierPath formats.
public struct IconShapePaths {

    // MARK: - SwiftUI Path Methods

    /// Creates a circle path (drawn clockwise from 12 o'clock, supports trimmedPath progress arc)
    /// - Parameter rect: Drawing area
    /// - Returns: Circle path
    public static func circlePath(in rect: CGRect) -> Path {
        let inset = rect.insetBy(dx: 3, dy: 3)
        let center = CGPoint(x: inset.midX, y: inset.midY)
        let radius = min(inset.width, inset.height) / 2
        return Path { path in
            // Draw full circle from 12 o'clock (-90°) clockwise
            path.addArc(center: center, radius: radius,
                        startAngle: .degrees(-90), endAngle: .degrees(270),
                        clockwise: false)
        }
    }

    /// Creates a rounded square path (Opus, drawn clockwise from top-center, scales with rect)
    /// - Parameter rect: Drawing area
    /// - Returns: Rounded square path
    public static func roundedSquarePath(in rect: CGRect) -> Path {
        let s = (min(rect.width, rect.height) - 8) / 2  // half side length (4pt inset to avoid stroke clipping)
        let cx = rect.midX, cy = rect.midY
        let r = s * 0.4  // corner radius (consistent with original 2/10 ratio)
        return Path { path in
            // Draw clockwise from top-center
            path.move(to: CGPoint(x: cx, y: cy - s))
            path.addLine(to: CGPoint(x: cx + s - r, y: cy - s))
            path.addArc(center: CGPoint(x: cx + s - r, y: cy - s + r),
                        radius: r, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
            path.addLine(to: CGPoint(x: cx + s, y: cy + s - r))
            path.addArc(center: CGPoint(x: cx + s - r, y: cy + s - r),
                        radius: r, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
            path.addLine(to: CGPoint(x: cx - s + r, y: cy + s))
            path.addArc(center: CGPoint(x: cx - s + r, y: cy + s - r),
                        radius: r, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
            path.addLine(to: CGPoint(x: cx - s, y: cy - s + r))
            path.addArc(center: CGPoint(x: cx - s + r, y: cy - s + r),
                        radius: r, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
            path.addLine(to: CGPoint(x: cx, y: cy - s))
            path.closeSubpath()
        }
    }

    /// Creates a chamfered (top-right clipped) rounded square path (Sonnet, clockwise from top-center, scales with rect)
    /// - Parameter rect: Drawing area
    /// - Returns: Chamfered rounded square path
    public static func chamferedSquarePath(in rect: CGRect) -> Path {
        let s = (min(rect.width, rect.height) - 8) / 2  // half side length (4pt inset to avoid stroke clipping)
        let cx = rect.midX, cy = rect.midY
        let r = s * 0.4    // corner radius
        let cut = s * 0.5  // top-right chamfer size (consistent with original 2.5/5 ratio)
        return Path { path in
            // Draw clockwise from top-center
            path.move(to: CGPoint(x: cx, y: cy - s))
            path.addLine(to: CGPoint(x: cx + s - cut, y: cy - s))  // top edge to chamfer start
            path.addLine(to: CGPoint(x: cx + s, y: cy - s + cut))  // chamfer
            path.addLine(to: CGPoint(x: cx + s, y: cy + s - r))    // right edge
            path.addArc(center: CGPoint(x: cx + s - r, y: cy + s - r),
                        radius: r, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
            path.addLine(to: CGPoint(x: cx - s + r, y: cy + s))
            path.addArc(center: CGPoint(x: cx - s + r, y: cy + s - r),
                        radius: r, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
            path.addLine(to: CGPoint(x: cx - s, y: cy - s + r))
            path.addArc(center: CGPoint(x: cx - s + r, y: cy - s + r),
                        radius: r, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
            path.addLine(to: CGPoint(x: cx, y: cy - s))
            path.closeSubpath()
        }
    }

    /// Creates a flat-top hexagon path (Extra Usage, drawn clockwise from upper-right vertex)
    /// - Parameters:
    ///   - center: Hexagon center point
    ///   - radius: Hexagon radius
    /// - Returns: Hexagon path
    public static func hexagonPath(center: CGPoint, radius: CGFloat) -> Path {
        Path { path in
            // Draw clockwise from upper-right vertex (-60°, closest to 12 o'clock)
            for i in 0..<6 {
                let angleDeg: CGFloat = -60 + CGFloat(i) * 60
                let angle = angleDeg * .pi / 180
                let x = center.x + radius * cos(angle)
                let y = center.y + radius * sin(angle)
                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            path.closeSubpath()
        }
    }

    /// Returns the shape path for a given limit type (scales dynamically with rect)
    /// - Parameters:
    ///   - type: Limit type
    ///   - rect: Drawing area
    /// - Returns: Corresponding shape path
    public static func pathForLimitType(_ type: IconLimitType, in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        // Hexagon radius: 3pt inset to ensure stroke isn't clipped
        let hexRadius = min(rect.width, rect.height) / 2 - 3

        switch type {
        case .fiveHour, .sevenDay:
            return circlePath(in: rect)

        case .opusWeekly:
            return roundedSquarePath(in: rect)

        case .sonnetWeekly:
            return chamferedSquarePath(in: rect)

        case .extraUsage:
            return hexagonPath(center: center, radius: hexRadius)
        }
    }

    // MARK: - NSBezierPath Methods (for MenuBarIconRenderer)

    /// Creates a rounded square NSBezierPath (Opus)
    /// - Parameters:
    ///   - center: Center point
    ///   - size: Square side length
    /// - Returns: NSBezierPath
    public static func roundedSquareNSPath(center: CGPoint, size: CGFloat) -> NSBezierPath {
        let path = NSBezierPath()
        let rect = CGRect(
            x: center.x - size / 2,
            y: center.y - size / 2,
            width: size,
            height: size
        )
        path.appendRoundedRect(rect, xRadius: 2, yRadius: 2)
        return path
    }

    /// Creates a chamfered (top-right clipped) rounded square NSBezierPath (Sonnet)
    /// - Parameters:
    ///   - center: Center point
    ///   - size: Square side length
    /// - Returns: NSBezierPath
    public static func chamferedSquareNSPath(center: CGPoint, size: CGFloat) -> NSBezierPath {
        let path = NSBezierPath()
        let rect = CGRect(
            x: center.x - size / 2,
            y: center.y - size / 2,
            width: size,
            height: size
        )
        let cornerRadius: CGFloat = 2.0
        let cutSize: CGFloat = 2.5

        // Start from bottom-left
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + cornerRadius))

        // Left to bottom-left corner
        path.appendArc(
            withCenter: CGPoint(x: rect.minX + cornerRadius, y: rect.minY + cornerRadius),
            radius: cornerRadius,
            startAngle: 180,
            endAngle: 270,
            clockwise: false
        )

        // Bottom to bottom-right corner
        path.line(to: CGPoint(x: rect.maxX - cornerRadius, y: rect.minY))
        path.appendArc(
            withCenter: CGPoint(x: rect.maxX - cornerRadius, y: rect.minY + cornerRadius),
            radius: cornerRadius,
            startAngle: 270,
            endAngle: 0,
            clockwise: false
        )

        // Right edge to chamfer position
        path.line(to: CGPoint(x: rect.maxX, y: rect.maxY - cutSize))

        // Chamfer line
        path.line(to: CGPoint(x: rect.maxX - cutSize, y: rect.maxY))

        // Top to top-left corner
        path.line(to: CGPoint(x: rect.minX + cornerRadius, y: rect.maxY))
        path.appendArc(
            withCenter: CGPoint(x: rect.minX + cornerRadius, y: rect.maxY - cornerRadius),
            radius: cornerRadius,
            startAngle: 90,
            endAngle: 180,
            clockwise: false
        )

        path.close()
        return path
    }

    /// Creates a flat-top hexagon NSBezierPath (Extra Usage)
    /// - Parameters:
    ///   - center: Center point
    ///   - radius: Radius
    /// - Returns: NSBezierPath
    public static func hexagonNSPath(center: CGPoint, radius: CGFloat) -> NSBezierPath {
        let path = NSBezierPath()

        for i in 0..<6 {
            let angle = CGFloat(i) * .pi / 3.0
            let x = center.x + radius * cos(angle)
            let y = center.y + radius * sin(angle)

            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.line(to: CGPoint(x: x, y: y))
            }
        }

        path.close()
        return path
    }
}
