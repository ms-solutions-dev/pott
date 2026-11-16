import Foundation

/// A person in a household.
public struct Member: Identifiable, Hashable, Sendable, Codable {
    public var id: UUID
    public var name: String
    /// Net income per month, used by `SplitRule.byIncome`.
    public var monthlyNetIncome: Money
    /// Amount paid in per month, used by `SplitRule.fixedAmounts`.
    public var fixedContribution: Money
    /// Share in percent (0…100), used by `SplitRule.customShares`.
    public var sharePercent: Decimal

    public init(
        id: UUID = UUID(), name: String, monthlyNetIncome: Money = .zero, fixedContribution: Money = .zero,
        sharePercent: Decimal = 0
    ) {
        self.id = id
        self.name = name
        self.monthlyNetIncome = monthlyNetIncome
        self.fixedContribution = fixedContribution
        self.sharePercent = sharePercent
    }
}

/// How members pay into the household pot.
public enum SplitRule: String, Sendable, Codable, CaseIterable {
    /// Every member pays a fixed amount; whatever is not needed stays in the pot.
    case fixedAmounts
    /// The household costs are divided equally.
    case equal
    /// Members pay in proportion to their net income.
    case byIncome
    /// Members pay agreed percentages that add up to 100.
    case customShares
}

/// The result of splitting the household costs.
public struct HouseholdSplit: Sendable, Equatable {
    /// What the household needs per month: shared costs plus shared savings rates.
    public var required: Money
    /// Contribution per member, in member order.
    public var contributions: [UUID: Money]
    /// Total paid in.
    public var paidIn: Money
    /// Paid in minus required. Negative means the pot is short.
    public var balance: Money

    public func contribution(of member: UUID) -> Money {
        contributions[member] ?? .zero
    }
}

public enum HouseholdCalculator {
    /// Splits `required` between `members` according to `rule`.
    ///
    /// Equal, income-based and percentage splits distribute leftover cents by the largest
    /// remainder, so the contributions always add up to `required` exactly.
    public static func split(required: Money, members: [Member], rule: SplitRule) -> HouseholdSplit {
        guard !members.isEmpty else {
            return HouseholdSplit(required: required, contributions: [:], paidIn: .zero, balance: -required)
        }
        let weights: [Decimal]
        switch rule {
        case .fixedAmounts:
            let contributions = Dictionary(
                uniqueKeysWithValues: members.map { ($0.id, $0.fixedContribution) })
            let paid = members.map(\.fixedContribution).sum()
            return HouseholdSplit(
                required: required, contributions: contributions, paidIn: paid, balance: paid - required)
        case .equal:
            weights = members.map { _ in 1 }
        case .byIncome:
            let incomes = members.map { $0.monthlyNetIncome.decimal }
            weights = incomes.allSatisfy { $0 <= 0 } ? members.map { _ in 1 } : incomes.map { max($0, 0) }
        case .customShares:
            let shares = members.map { max($0.sharePercent, 0) }
            weights = shares.allSatisfy { $0 == 0 } ? members.map { _ in 1 } : shares
        }
        let parts = distribute(required, weights: weights)
        let contributions = Dictionary(uniqueKeysWithValues: zip(members.map(\.id), parts))
        let paid = parts.sum()
        return HouseholdSplit(
            required: required, contributions: contributions, paidIn: paid, balance: paid - required)
    }

    /// Distributes an amount by weights; the parts add up to the amount to the cent.
    static func distribute(_ amount: Money, weights: [Decimal]) -> [Money] {
        let total = weights.reduce(0, +)
        guard total > 0 else { return weights.map { _ in .zero } }
        var floors: [Int64] = []
        var remainders: [(index: Int, rest: Decimal)] = []
        for (index, weight) in weights.enumerated() {
            let exact = Decimal(amount.cents) * weight / total
            var source = exact
            var floored = Decimal()
            NSDecimalRound(&floored, &source, 0, .down)
            floors.append(NSDecimalNumber(decimal: floored).int64Value)
            remainders.append((index, exact - floored))
        }
        var leftover = amount.cents - floors.reduce(0, +)
        for entry in remainders.sorted(by: { $0.rest == $1.rest ? $0.index < $1.index : $0.rest > $1.rest }) {
            guard leftover > 0 else { break }
            floors[entry.index] += 1
            leftover -= 1
        }
        return floors.map { Money(cents: $0) }
    }
}
