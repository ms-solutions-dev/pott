import PottCore
import PottDesign
import PottFeatures
import SwiftUI

extension Money {
    /// Currency text in the user's region.
    var text: String { formatted(currencyCode: Money.currencyCode) }

    /// All amounts are euros: the pay calculator is German. A calculator for another country brings
    /// its own currency; the region only decides how the amount is written.
    static let currencyCode = "EUR"
}

extension AppSettings {
    /// The display name of a category.
    func name(of category: CategoryID) -> String {
        switch category {
        case .housing: String(localized: "Housing")
        case .everyday: String(localized: "Everyday")
        case .energy: String(localized: "Energy")
        case .subscriptions: String(localized: "Subscriptions & contracts")
        case .mobility: String(localized: "Mobility")
        case .insurance: String(localized: "Insurance")
        default: customCategories.first { $0.id == category }?.name ?? String(localized: "Other")
        }
    }

    /// The color of a category in the current appearance.
    func color(of category: CategoryID) -> Color {
        Palette.category(colorIndex(of: category)).color
    }
}

extension FixedCost {
    /// "Monthly · day 3" or "€744 yearly".
    var rhythmText: String {
        switch recurrence {
        case .monthly: String(localized: "Monthly · day \(dueDay)")
        case .quarterly: String(localized: "\(amount.text) quarterly")
        case .yearly: String(localized: "\(amount.text) yearly")
        }
    }
}

/// Lays out children in rows and wraps, for chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed =
                rows[rows.count - 1].indices.isEmpty
                ? size.width : rows[rows.count - 1].width + spacing + size.width
            if needed > width && !rows[rows.count - 1].indices.isEmpty {
                rows.append(Row())
            }
            var row = rows[rows.count - 1]
            row.width = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            row.height = max(row.height, size.height)
            row.indices.append(index)
            rows[rows.count - 1] = row
        }
        return rows
    }
}

/// A text field for amounts that keeps the typed text and reports the parsed value.
struct AmountField: View {
    var title: LocalizedStringKey
    @Binding var text: String
    var large = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).textRole(.caption).foregroundStyle(Palette.secondaryText.color)
            TextField(text: $text, prompt: Text("0")) { Text(title) }
                .accessibilityLabel(Text(title))
                .keyboardType(.decimalPad)
                .textRole(large ? .figure : .amount)
                .padding(.horizontal, 14)
                .padding(.vertical, large ? 10 : 0)
                .frame(minHeight: large ? 76 : 52)
                .background(Palette.card.color, in: .rect(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(
                        Palette.control.color, lineWidth: 1))
        }
    }
}

/// A labeled single-line or multi-line text field in the app's style.
struct LabeledField: View {
    var title: LocalizedStringKey
    @Binding var text: String
    var prompt: LocalizedStringKey = ""
    var multiline = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).textRole(.caption).foregroundStyle(Palette.secondaryText.color)
            TextField(text: $text, prompt: Text(prompt), axis: multiline ? .vertical : .horizontal) {
                Text(title)
            }
            .accessibilityLabel(Text(title))
            .lineLimit(multiline ? 3...6 : 1...1)
            .textRole(.body)
            .padding(14)
            .frame(minHeight: 52)
            .background(Palette.card.color, in: .rect(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(
                    Palette.control.color, lineWidth: 1))
        }
    }
}

/// Section title in the overview style.
struct SectionTitle: View {
    var title: LocalizedStringKey

    var body: some View {
        Text(title)
            .textRole(.section)
            .textCase(.uppercase)
            .foregroundStyle(Palette.secondaryText.color)
            .accessibilityAddTraits(.isHeader)
    }
}
