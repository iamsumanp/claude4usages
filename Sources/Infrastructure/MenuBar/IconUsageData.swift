//
//  IconUsageData.swift
//  claude4usages
//
//  Created by Claude Code on 2026-05-01.
//

import Foundation

/// Flat, renderer-facing snapshot of Claude usage limits.
/// Owned by claude4usages — independent of `UsageSnapshot` so the renderer
/// can be tested and refactored without coupling to the domain layer.
public struct IconUsageData: Sendable, Equatable {
    public let fiveHour: LimitData?
    public let sevenDay: LimitData?
    public let opus: LimitData?
    public let sonnet: LimitData?
    public let extraUsage: ExtraUsageData?

    public init(
        fiveHour: LimitData? = nil,
        sevenDay: LimitData? = nil,
        opus: LimitData? = nil,
        sonnet: LimitData? = nil,
        extraUsage: ExtraUsageData? = nil
    ) {
        self.fiveHour = fiveHour
        self.sevenDay = sevenDay
        self.opus = opus
        self.sonnet = sonnet
        self.extraUsage = extraUsage
    }

    public struct LimitData: Sendable, Equatable {
        public let percentage: Double
        public let resetsAt: Date?

        public init(percentage: Double, resetsAt: Date? = nil) {
            self.percentage = percentage
            self.resetsAt = resetsAt
        }
    }

    public struct ExtraUsageData: Sendable, Equatable {
        public let enabled: Bool
        public let percentage: Double?

        public init(enabled: Bool, percentage: Double?) {
            self.enabled = enabled
            self.percentage = percentage
        }
    }
}

/// Which limit shape is rendered. Values match the renderer's enum cases.
public enum IconLimitType: String, Sendable, CaseIterable, Codable {
    case fiveHour
    case sevenDay
    case opusWeekly
    case sonnetWeekly
    case extraUsage
}
