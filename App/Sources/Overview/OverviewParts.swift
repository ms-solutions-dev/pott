import PottCore
import PottDesign
import PottFeatures
import SwiftUI

/// The ring with what is left (personal view) or what is free in the pot (household view).
struct HeroRing: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var size
    var budget: BudgetResult
    var scope: OverviewScope

    var body: some View {
        let info = content
        // With accessibility text sizes the subtitle moves below the ring instead of overflowing it.
        let outside = size.isAccessibilitySize
        VStack(spacing: 10) {
            RingGauge(progress: info.progress, tint: info.tint) {
                VStack(spacing: 4) {
                    Text(info.label).textRole(.body).foregroundStyle(Palette.secondaryText.color)
                        .minimumScaleFactor(0.6).lineLimit(1)
                    Text(info.value)
                        .textRole(.hero)
                        .foregroundStyle(info.valueColor)
                        .minimumScaleFactor(0.4)
                        .lineLimit(1)
                    if !outside { subtitle(info) }
                }
            }
            .frame(width: 236, height: 236)
            if outside { subtitle(info) }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func subtitle(_ info: Info) -> some View {
        Text(info.subtitle)
            .textRole(.caption)
            .foregroundStyle(Palette.secondaryText.color)
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.7)
            .lineLimit(3)
    }

    private struct Info {
        var label: String
        var value: String
        var subtitle: String
        var progress: Double
        var tint: Color
        var valueColor: Color
    }

    private var content: Info {
        if scope == .together, let pot = budget.household {
            let short = pot.balance.isNegative
            let free = pot.paidIn.cents > 0 ? max(0, Double(pot.balance.cents) / Double(pot.paidIn.cents)) : 0
            return Info(
                label: short ? String(localized: "missing in the pot") : String(localized: "left in the pot"),
                value: pot.balance.magnitude.text,
                subtitle: String(localized: "\(pot.required.text) of \(pot.paidIn.text) planned"),
                progress: free, tint: short ? Palette.negative.color : Palette.shared.color,
                valueColor: short ? Palette.negative.color : Palette.shared.color)
        }
        let personal = budget.personal
        if personal.income.cents == 0 {
            return Info(
                label: String(localized: "no income yet"), value: "–",
                subtitle: String(localized: "Tap “My income” below"), progress: 0,
                tint: Palette.ring.color, valueColor: Palette.secondaryText.color)
        }
        if personal.left.isNegative {
            return Info(
                label: String(localized: "you are short"), value: personal.left.magnitude.text,
                subtitle: String(localized: "Your costs are higher than your income"), progress: 0,
                tint: Palette.negative.color, valueColor: Palette.negative.color)
        }
        let percent = (personal.leftRatio as NSDecimalNumber).doubleValue
        let days = Calendar.current.range(of: .day, in: .month, for: .now)?.count ?? 30
        return Info(
            label: String(localized: "left for you"), value: personal.left.text,
            subtitle: String(
                localized:
                    "\(Int((percent * 100).rounded())) % of your income · ≈\u{00A0}\(personal.perDay(over: days).text) a day"
            ),
            progress: percent, tint: Palette.ring.color, valueColor: Palette.accentText.color)
    }
}

/// How the personal amount is computed, with the income as entry point.
struct BreakdownCard: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var size
    var budget: BudgetResult
    var openIncomes: () -> Void

    var body: some View {
        let personal = budget.personal
        VStack(spacing: 0) {
            Button(action: openIncomes) {
                // Large text sizes stack the amount below the title instead of squeezing both.
                let layout =
                    size.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
                    : AnyLayout(HStackLayout(spacing: 8))
                layout {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("My income").textRole(.bodyStrong)
                        Text(incomeHint).textRole(.caption).foregroundStyle(Palette.secondaryText.color)
                    }
                    if !size.isAccessibilitySize { Spacer() }
                    HStack {
                        Text(personal.income.text).textRole(.amount)
                        Image(systemName: "chevron.right").foregroundStyle(Palette.secondaryText.color)
                    }
                }
                .frame(minHeight: 52)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            Divider().overlay(Palette.separator.color)
            if model.householdActive {
                line("Share of the household pot", personal.householdContribution)
            }
            line(model.householdActive ? "My fixed costs" : "Fixed costs", personal.fixedCosts)
            if model.savingsActive {
                line("Savings goals", personal.savings)
            }
            Divider().overlay(Palette.separator.color).padding(.top, 4)
            HStack {
                Text(personal.left.isNegative ? "You are short" : "Left for you").textRole(.amount)
                Spacer()
                Text(personal.left.magnitude.text)
                    .textRole(.amount)
                    .foregroundStyle(
                        personal.left.isNegative ? Palette.negative.color : Palette.accentText.color)
            }
            .padding(.top, 10)
        }
        .card()
    }

    private var incomeHint: String {
        switch model.incomes.count {
        case 0: String(localized: "Nothing entered yet · tap to add")
        case 1: String(localized: "1 source · tap to manage")
        default: String(localized: "\(model.incomes.count) sources · tap to manage")
        }
    }

    private func line(_ title: LocalizedStringKey, _ amount: Money) -> some View {
        HStack {
            Text(title).textRole(.body).foregroundStyle(Palette.secondaryText.color)
            Spacer()
            Text("− \(amount.text)").textRole(.bodyStrong).foregroundStyle(Palette.negative.color)
        }
        .padding(.vertical, 6)
    }
}

/// A heading of a category group with its total.
struct GroupHeader: View {
    @Environment(AppModel.self) private var model
    var category: CategoryID
    var total: Money

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(model.settings.color(of: category)).frame(width: 12, height: 12)
            Text(model.settings.name(of: category)).textRole(.bodyStrong)
            Spacer()
            Text(total.text).textRole(.caption).foregroundStyle(Palette.secondaryText.color)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// One fixed cost.
struct CostRow: View {
    @Environment(AppModel.self) private var model
    var cost: FixedCost
    var showsCategory: Bool
    var open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 3).fill(model.settings.color(of: cost.category)).frame(
                    width: 6, height: 34)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(cost.name).textRole(.bodyStrong).lineLimit(1)
                        if !cost.note.isEmpty {
                            Image(systemName: "note.text").font(.footnote).foregroundStyle(
                                Palette.secondaryText.color
                            )
                            .accessibilityLabel("Has a note")
                        }
                        if cost.isPaused {
                            Text("Paused").textRole(.caption).foregroundStyle(Palette.secondaryText.color)
                        }
                    }
                    Text(subtitle).textRole(.caption).foregroundStyle(Palette.secondaryText.color).lineLimit(
                        1)
                }
                Spacer(minLength: 8)
                Text(cost.monthlyAmount.text)
                    .textRole(.amount)
                    .strikethrough(cost.isPaused)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 60)
            .background(Palette.card.color, in: .rect(cornerRadius: 14, style: .continuous))
            .opacity(cost.isPaused ? 0.6 : 1)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private var subtitle: String {
        showsCategory ? "\(cost.rhythmText) · \(model.settings.name(of: cost.category))" : cost.rhythmText
    }
}
