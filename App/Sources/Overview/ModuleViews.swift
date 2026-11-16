import Charts
import PottCore
import PottDesign
import PottFeatures
import SwiftUI

/// The last months as bars: what was left at the end of each.
struct MonthlyReviewCard: View {
    @Environment(AppModel.self) private var model
    @State private var showsAll = false

    private var recent: [MonthSummary] { Array(model.months.prefix(6).reversed()) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionTitle(title: "Monthly review")
                Spacer()
                if model.months.count > 1 {
                    Button("All months") { showsAll = true }
                        .textRole(.bodyStrong)
                        .foregroundStyle(Palette.accentText.color)
                        .frame(minHeight: 44)
                }
            }
            if recent.count < 2 {
                Text("From next month on you see here how much was left at the end of each month.")
                    .textRole(.caption)
                    .foregroundStyle(Palette.secondaryText.color)
                    .card()
            } else {
                Chart(recent) { month in
                    BarMark(
                        x: .value("Month", label(month.month)),
                        y: .value("Left", (month.left.decimal as NSDecimalNumber).doubleValue)
                    )
                    .foregroundStyle(month.left.isNegative ? Palette.negative.color : Palette.ring.color)
                    .cornerRadius(6)
                    .annotation(position: .top) {
                        Text(month.left.text).textRole(.caption).foregroundStyle(Palette.secondaryText.color)
                    }
                }
                .chartYAxis(.hidden)
                .frame(height: 150)
                .card()
                .accessibilityLabel("What was left in the last months")
            }
        }
        .padding(.top, 18)
        .sheet(isPresented: $showsAll) { MonthsSheet() }
    }

    private func label(_ key: String) -> String {
        guard let date = Self.parser.date(from: key) else { return key }
        return date.formatted(.dateTime.month(.abbreviated))
    }

    static let parser: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM"
        return formatter
    }()
}

/// Every recorded month with its breakdown.
private struct MonthsSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(model.months) { month in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(title(month.month)).textRole(.bodyStrong)
                        Spacer()
                        Text(month.left.text)
                            .textRole(.amount)
                            .foregroundStyle(
                                month.left.isNegative ? Palette.negative.color : Palette.accentText.color)
                    }
                    Text(
                        "Income \(month.income.text) · fixed costs \(month.fixedCosts.text) · savings \(month.savings.text)"
                    )
                    .textRole(.caption)
                    .foregroundStyle(Palette.secondaryText.color)
                }
                .padding(.vertical, 4)
                .listRowBackground(Palette.card.color)
            }
            .scrollContentBackground(.hidden)
            .background(Palette.background.color)
            .navigationTitle("Monthly review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    private func title(_ key: String) -> String {
        MonthlyReviewCard.parser.date(from: key)?.formatted(.dateTime.month(.wide).year()) ?? key
    }
}

/// Contracts whose notice deadline is within the next 60 days.
struct DeadlinesCard: View {
    @Environment(AppModel.self) private var model
    var open: (FixedCost) -> Void

    var body: some View {
        let soon = model.upcomingDeadlines.filter {
            $0.deadline < Calendar.current.date(byAdding: .day, value: 60, to: .now) ?? .now
        }
        if !soon.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(title: "Cancel soon?")
                ForEach(soon, id: \.cost.id) { item in
                    Button {
                        open(item.cost)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "calendar.badge.exclamationmark")
                                .font(.title3)
                                .foregroundStyle(Palette.negative.color)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.cost.name).textRole(.bodyStrong)
                                Text("Notice by \(item.deadline.formatted(date: .long, time: .omitted))")
                                    .textRole(.caption)
                                    .foregroundStyle(Palette.secondaryText.color)
                            }
                            Spacer()
                            Text(item.cost.monthlyAmount.text).textRole(.amount)
                        }
                        .card(padding: 12)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 18)
        }
    }
}
