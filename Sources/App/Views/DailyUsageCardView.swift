import SwiftUI
import Domain

/// Displays a single daily usage metric (cost, tokens, or working time)
/// matching the existing WrappedStatCard glassmorphism style.
struct DailyUsageCardView: View {
    let metric: DailyUsageMetric
    let report: DailyUsageReport
    let delay: Double

    @Environment(\.appTheme) private var theme
    @State private var isHovering = false
    @State private var animateProgress = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header row with icon and label
            HStack(alignment: .top, spacing: 0) {
                HStack(spacing: 5) {
                    Image(systemName: metric.iconName)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(metric.color)

                    Text(metric.label.uppercased())
                        .font(.system(size: 8, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                        .tracking(0.3)
                }

                Spacer(minLength: 4)
            }

            // Large value display
            HStack(alignment: .firstTextBaseline) {
                Text(primaryValue)
                    .font(.system(size: 24, weight: .bold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                    .contentTransition(.numericText())

                Spacer()

                Text(metric.unitLabel)
                    .font(.system(size: 11, weight: .medium, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
            }

            // Progress bar — only useful for working time (a fraction of a day);
            // for cost/tokens the bar is a confusing "today vs yesterday" ratio
            // that the delta line below already states clearly.
            if metric == .workingTime {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(theme.progressTrack)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(LinearGradient(
                                colors: [metric.color.opacity(0.8), metric.color],
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                            .frame(width: animateProgress ? geo.size.width * progress : 0)
                            .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(delay + 0.2), value: animateProgress)
                    }
                }
                .frame(height: 5)
            }

            // Delta vs previous day — split into two lines so the long
            // "+$440.34 (440.8%)" payload stays legible on narrow cards.
            if let parts = formattedDeltaParts {
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 3) {
                        Image(systemName: parts.arrow)
                            .font(.system(size: 8, weight: .bold))
                        Text(parts.headline)
                            .font(.system(size: 10, weight: .semibold, design: theme.fontDesign))
                    }
                    .foregroundStyle(deltaColor)

                    Text(parts.subline)
                        .font(.system(size: 8, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                }
                .lineLimit(1)
            }
        }
        .padding(12)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: theme.cardCornerRadius)
                    .fill(theme.cardGradient)

                RoundedRectangle(cornerRadius: theme.cardCornerRadius)
                    .stroke(theme.glassBorder, lineWidth: 1)
            }
        )
        .scaleEffect(isHovering ? 1.015 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isHovering)
        .onHover { isHovering = $0 }
        .onAppear {
            animateProgress = true
        }
    }

    // MARK: - Computed Properties

    private var primaryValue: String {
        switch metric {
        case .cost: return report.today.formattedCost
        case .tokens: return report.today.formattedTokens
        case .workingTime: return report.today.formattedWorkingTime
        }
    }

    private var progress: Double {
        switch metric {
        case .cost: return min(1, max(0, report.costProgress))
        case .tokens: return min(1, max(0, report.tokenProgress))
        case .workingTime: return min(1, max(0, report.timeProgress))
        }
    }

    private var formattedDelta: String? {
        guard !report.previous.isEmpty else { return nil }
        let date = report.previous.formattedDate
        switch metric {
        case .cost:
            let delta = report.formattedCostDelta
            if let pct = report.costChangePercent {
                return "Vs \(date) \(delta) (\(String(format: "%.1f", abs(pct)))%)"
            }
            return "Vs \(date) \(delta)"
        case .tokens:
            let delta = report.formattedTokenDelta
            if let pct = report.tokenChangePercent {
                return "Vs \(date) \(delta) (\(String(format: "%.1f", abs(pct)))%)"
            }
            return "Vs \(date) \(delta)"
        case .workingTime:
            let delta = report.formattedTimeDelta
            if let pct = report.timeChangePercent {
                return "Vs \(date) \(delta) (\(String(format: "%.1f", abs(pct)))%)"
            }
            return "Vs \(date) \(delta)"
        }
    }

    private var deltaColor: Color {
        switch metric {
        case .cost:
            return report.costDelta <= 0 ? .green : .orange
        case .tokens:
            return report.tokenDelta <= 0 ? .green : .orange
        case .workingTime:
            return theme.textTertiary
        }
    }

    /// Two-line breakdown of the delta — `headline` is the ↑/↓ delta value,
    /// `subline` is the calendar context. Easier to scan than the original
    /// crammed single line.
    private var formattedDeltaParts: (arrow: String, headline: String, subline: String)? {
        guard !report.previous.isEmpty else { return nil }
        let date = report.previous.formattedDate

        let (delta, pct, isUp): (String, Double?, Bool)
        switch metric {
        case .cost:
            delta = report.formattedCostDelta
            pct = report.costChangePercent
            isUp = report.costDelta > 0
        case .tokens:
            delta = report.formattedTokenDelta
            pct = report.tokenChangePercent
            isUp = report.tokenDelta > 0
        case .workingTime:
            delta = report.formattedTimeDelta
            pct = report.timeChangePercent
            isUp = report.timeDelta > 0
        }

        let arrow = isUp ? "arrow.up" : "arrow.down"
        let headline: String
        if let pct {
            headline = "\(delta) (\(String(format: "%.0f", abs(pct)))%)"
        } else {
            headline = delta
        }
        return (arrow, headline, "vs \(date)")
    }
}

// MARK: - Metric Type

enum DailyUsageMetric {
    case cost
    case tokens
    case workingTime

    var label: String {
        switch self {
        case .cost: return "Cost Usage"
        case .tokens: return "Token Usage"
        case .workingTime: return "Working Time"
        }
    }

    var iconName: String {
        switch self {
        case .cost: return "dollarsign.circle.fill"
        case .tokens: return "number.circle.fill"
        case .workingTime: return "clock.fill"
        }
    }

    var unitLabel: String {
        switch self {
        case .cost: return "Spent"
        case .tokens: return "Tokens"
        case .workingTime: return "Duration"
        }
    }

    var color: Color {
        switch self {
        case .cost: return .yellow
        case .tokens: return .green
        case .workingTime: return .purple
        }
    }
}
