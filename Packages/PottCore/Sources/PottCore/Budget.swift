import Foundation

/// Everything the overview needs to answer "how much is left this month?" for one person.
public struct PersonalBudget: Sendable, Equatable {
    public var income: Money
    /// Contribution to the household pot; zero without a household.
    public var householdContribution: Money
    /// Personal fixed costs per month (all costs when there is no household).
    public var fixedCosts: Money
    /// Personal savings rates per month.
    public var savings: Money

    /// Income minus everything else. Negative means the person is short.
    public var left: Money {
        income - householdContribution - fixedCosts - savings
    }

    /// Share of the income that is left, between 0 and 1. Zero without income.
    public var leftRatio: Decimal {
        guard income.cents > 0, !left.isNegative else { return 0 }
        return min(left.decimal / income.decimal, 1)
    }

    /// What is left per day over `days`, rounded down to whole currency units.
    public func perDay(over days: Int) -> Money {
        guard days > 0, !left.isNegative else { return .zero }
        return Money(cents: left.cents / Int64(days) / 100 * 100)
    }
}

/// The inputs of a month, as stored by the app.
public struct BudgetInput: Sendable {
    public var incomes: [IncomeSource]
    public var costs: [FixedCost]
    public var goals: [SavingsGoal]
    /// The household, or nil when the household module is off.
    public var household: HouseholdInput?

    public struct HouseholdInput: Sendable {
        public var me: UUID
        public var members: [Member]
        public var rule: SplitRule

        public init(me: UUID, members: [Member], rule: SplitRule) {
            self.me = me
            self.members = members
            self.rule = rule
        }
    }

    public init(incomes: [IncomeSource], costs: [FixedCost], goals: [SavingsGoal], household: HouseholdInput?)
    {
        self.incomes = incomes
        self.costs = costs
        self.goals = goals
        self.household = household
    }
}

/// The complete monthly picture: the personal view and, with a household, the pot.
public struct BudgetResult: Sendable, Equatable {
    public var personal: PersonalBudget
    public var household: HouseholdSplit?
}

public enum BudgetCalculator {
    /// Computes the month.
    ///
    /// Without a household every cost and goal counts as personal. With a household, entries
    /// scoped `.household` are paid from the pot and the person pays their split contribution instead.
    public static func calculate(_ input: BudgetInput) -> BudgetResult {
        let income = input.incomes.map(\.monthlyNet).sum()
        guard let household = input.household else {
            let personal = PersonalBudget(
                income: income, householdContribution: .zero,
                fixedCosts: input.costs.map(\.monthlyAmount).sum(),
                savings: input.goals.filter { !$0.isReached }.map(\.monthlyRate).sum())
            return BudgetResult(personal: personal, household: nil)
        }
        let sharedCosts = input.costs.filter { $0.scope == .household }.map(\.monthlyAmount).sum()
        let sharedGoals = input.goals.filter { $0.scope == .household && !$0.isReached }.map(\.monthlyRate)
            .sum()
        let split = HouseholdCalculator.split(
            required: sharedCosts + sharedGoals, members: household.members, rule: household.rule)
        let personal = PersonalBudget(
            income: income,
            householdContribution: split.contribution(of: household.me),
            fixedCosts: input.costs.filter { $0.scope == .personal }.map(\.monthlyAmount).sum(),
            savings: input.goals.filter { $0.scope == .personal && !$0.isReached }.map(\.monthlyRate).sum())
        return BudgetResult(personal: personal, household: split)
    }
}
