//
//  ClaudeSnapshotToIconData.swift
//  claude4usages
//
//  Created by Claude Code on 2026-05-01.
//

import Foundation
import Domain

/// Maps a domain `UsageSnapshot` (Claude provider) into the renderer-facing `IconUsageData`.
/// Returns `nil` when the snapshot itself is `nil` (no usage data fetched yet).
public func makeIconUsageData(from snapshot: UsageSnapshot?) -> IconUsageData? {
    guard let snapshot else { return nil }

    return IconUsageData(
        fiveHour: limitData(in: snapshot, where: { $0 == .session }),
        sevenDay: limitData(in: snapshot, where: { $0 == .weekly }),
        opus: limitData(in: snapshot, where: { isModel($0, named: "opus") }),
        sonnet: limitData(in: snapshot, where: { isModel($0, named: "sonnet") }),
        extraUsage: nil  // not surfaced by current Claude probes
    )
}

private func limitData(in snapshot: UsageSnapshot, where match: (QuotaType) -> Bool) -> IconUsageData.LimitData? {
    guard let quota = snapshot.quotas.first(where: { match($0.quotaType) }) else { return nil }
    // UsageQuota exposes percentRemaining; renderer expects percentage used (0–100)
    let percentageUsed = quota.percentUsed
    return IconUsageData.LimitData(percentage: percentageUsed, resetsAt: quota.resetsAt)
}

private func isModel(_ type: QuotaType, named target: String) -> Bool {
    guard case let .modelSpecific(name) = type else { return false }
    return name.lowercased().contains(target.lowercased())
}
