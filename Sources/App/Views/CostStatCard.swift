import SwiftUI
import Domain

/// A card that displays cost-based usage data for Claude accounts.
/// Shows total cost, optional budget progress, and reset time for Pro Extra usage.
struct CostStatCard: View {
    let costUsage: CostUsage
    let externalBudget: Decimal?
    let delay: Double

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovering = false
    @State private var animateProgress = false

    init(costUsage: CostUsage, budget: Decimal? = nil, delay: Double = 0) {
        self.costUsage = costUsage
        self.externalBudget = budget
        self.delay = delay
    }

    /// The effective budget - prefer built-in budget from CostUsage (Pro Extra usage),
    /// fall back to external budget (API account settings)
    private var effectiveBudget: Decimal? {
        costUsage.budget ?? externalBudget
    }

    private var budgetStatus: BudgetStatus? {
        guard let budget = effectiveBudget, budget > 0 else { return nil }
        return costUsage.budgetStatus(budget: budget)
    }

    private var budgetPercentUsed: Double {
        guard let budget = effectiveBudget, budget > 0 else { return 0 }
        return min(100, costUsage.budgetPercentUsed(budget: budget))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header row with icon and status badge
            HStack(alignment: .top, spacing: 0) {
                // Left side: icon and label
                HStack(spacing: 5) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(budgetStatusColor)

                    Text("API COST")
                        .font(.system(size: 8, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                        .tracking(0.3)
                }

                Spacer(minLength: 4)

                // Status badge
                if let status = budgetStatus {
                    Text(status.badgeText)
                        .badge(theme.statusColor(for: status.toQuotaStatus))
                }
            }

            // Large cost display
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(costUsage.formattedCost)
                    .font(.system(size: 28, weight: .heavy, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                    .contentTransition(.numericText())
            }

            // Budget progress bar (if budget is set)
            if let budget = effectiveBudget, budget > 0 {
                budgetProgressBar(budget: budget)
            }

            // Show API Duration if > 0, or reset time for Pro Extra usage
            if costUsage.apiDuration > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 7))

                    Text("API Time: \(costUsage.formattedApiDuration)")
                        .font(.system(size: 9, weight: .semibold, design: theme.fontDesign))
                }
                .foregroundStyle(theme.textTertiary)
                .lineLimit(1)
            } else if let resetText = costUsage.resetText {
                HStack(spacing: 3) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 7))

                    Text(resetText)
                        .font(.system(size: 9, weight: .semibold, design: theme.fontDesign))
                }
                .foregroundStyle(theme.textTertiary)
                .lineLimit(1)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: theme.cardCornerRadius)
                    .fill(theme.cardGradient)

                // Light mode shadow
                if colorScheme == .light {
                    RoundedRectangle(cornerRadius: theme.cardCornerRadius)
                        .fill(Color.clear)
                        .shadow(color: Color.black.opacity(0.1), radius: 6, y: 3)
                }

                RoundedRectangle(cornerRadius: theme.cardCornerRadius)
                    .stroke(cardBorderGradient, lineWidth: 1)
            }
        )
        .scaleEffect(isHovering ? 1.015 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isHovering)
        .onHover { isHovering = $0 }
        .onAppear {
            animateProgress = true
        }
    }

    // MARK: - Budget Progress Bar

    @ViewBuilder
    private func budgetProgressBar(budget: Decimal) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    RoundedRectangle(cornerRadius: 3)
                        .fill(theme.progressTrack)

                    // Fill
                    RoundedRectangle(cornerRadius: 3)
                        .fill(budgetProgressGradient)
                        .frame(width: animateProgress ? geo.size.width * budgetPercentUsed / 100 : 0)
                        .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(delay + 0.2), value: animateProgress)
                }
            }
            .frame(height: 5)

            // Budget label
            HStack {
                Text("\(Int(budgetPercentUsed))% of \(formatBudget(budget)) budget")
                    .font(.system(size: 8, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)

                Spacer()
            }
        }
    }

    // MARK: - Styling

    private var budgetStatusColor: Color {
        guard let status = budgetStatus else { return theme.statusHealthy }
        return theme.statusColor(for: status.toQuotaStatus)
    }

    private var budgetProgressGradient: LinearGradient {
        guard let status = budgetStatus else {
            return LinearGradient(colors: [theme.statusHealthy], startPoint: .leading, endPoint: .trailing)
        }

        let color = theme.statusColor(for: status.toQuotaStatus)
        return LinearGradient(
            colors: [color.opacity(0.8), color],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var cardBorderGradient: LinearGradient {
        LinearGradient(
            colors: [
                theme.glassBorder.opacity(isHovering ? 1.2 : 1.0),
                theme.glassBorder.opacity(0.3)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func formatBudget(_ budget: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter.string(from: budget as NSDecimalNumber) ?? "$\(budget)"
    }
}

