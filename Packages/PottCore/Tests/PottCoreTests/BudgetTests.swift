import Foundation
import Testing

@testable import PottCore

/// The example household from the design mockup: two members with €2,000 net each,
/// one of them with an additional €240 mini job.
@Suite("Budget")
struct BudgetTests {
    let me = Member(
        name: "Me", monthlyNetIncome: Money(units: 2240), fixedContribution: Money(units: 800),
        sharePercent: 60)
    let partner = Member(
        name: "Partner", monthlyNetIncome: Money(units: 2000), fixedContribution: Money(units: 800),
        sharePercent: 40)

    var incomes: [IncomeSource] {
        [
            IncomeSource(
                name: "Main job", monthlyNet: Money(units: 2000),
                origin: .calculator(summary: "Gross €3,000 · class I")),
            IncomeSource(name: "Mini job", monthlyNet: Money(units: 240)),
        ]
    }

    var costs: [FixedCost] {
        [
            FixedCost(name: "Rent", amount: Money(units: 820), category: .housing, scope: .household),
            FixedCost(name: "Groceries", amount: Money(units: 350), category: .everyday, scope: .household),
            FixedCost(
                name: "Power & gas", amount: Money(units: 120), dueDay: 15, category: .energy,
                scope: .household),
            FixedCost(
                name: "Insurance", amount: Money(units: 744), recurrence: .yearly, category: .insurance,
                scope: .household),
            FixedCost(
                name: "Internet", amount: Money(units: 40), dueDay: 3, category: .subscriptions,
                scope: .household),
            FixedCost(name: "Car", amount: Money(units: 210), dueDay: 5, category: .mobility),
            FixedCost(name: "Gym", amount: Money(units: 30), category: .subscriptions),
            FixedCost(
                name: "Phone", amount: Money(units: 20), dueDay: 28, category: .subscriptions,
                note: "Contract 4711"),
            FixedCost(name: "Streaming", amount: Money(units: 18), dueDay: 12, category: .subscriptions),
        ]
    }

    var goals: [SavingsGoal] {
        [
            SavingsGoal(
                name: "Holiday", target: Money(units: 1800), saved: Money(units: 600), months: 8,
                scope: .household),
            SavingsGoal(
                name: "Emergency fund", target: Money(units: 5000), saved: Money(units: 3200), months: 18),
            SavingsGoal(name: "New phone", target: Money(units: 900), saved: Money(units: 300), months: 8),
        ]
    }

    func input(_ rule: SplitRule) -> BudgetInput {
        BudgetInput(
            incomes: incomes, costs: costs, goals: goals,
            household: .init(me: me.id, members: [me, partner], rule: rule))
    }

    @Test("Fixed amounts: €58 stay in the pot, €987 are left for me")
    func fixedAmounts() throws {
        let result = BudgetCalculator.calculate(input(.fixedAmounts))
        let pot = try #require(result.household)
        #expect(pot.required == Money(units: 1542))
        #expect(pot.paidIn == Money(units: 1600))
        #expect(pot.balance == Money(units: 58))
        #expect(result.personal.fixedCosts == Money(units: 278))
        #expect(result.personal.savings == Money(units: 175))
        #expect(result.personal.left == Money(units: 987))
    }

    @Test("Equal split halves the household costs")
    func equal() throws {
        let pot = try #require(BudgetCalculator.calculate(input(.equal)).household)
        #expect(pot.contribution(of: me.id) == Money(units: 771))
        #expect(pot.contribution(of: partner.id) == Money(units: 771))
        #expect(pot.balance == .zero)
    }

    @Test("Income split is proportional and adds up to the cent")
    func byIncome() throws {
        let pot = try #require(BudgetCalculator.calculate(input(.byIncome)).household)
        #expect(pot.contribution(of: me.id) == Money(cents: 81_464))
        #expect(pot.contribution(of: partner.id) == Money(cents: 72_736))
        #expect(pot.paidIn == pot.required)
    }

    @Test("Custom shares 60/40")
    func customShares() throws {
        let pot = try #require(BudgetCalculator.calculate(input(.customShares)).household)
        #expect(pot.contribution(of: me.id) == Money(cents: 92_520))
        #expect(pot.contribution(of: partner.id) == Money(cents: 61_680))
    }

    @Test("Three flatmates: leftover cents go to the largest remainders")
    func flatShare() {
        let parts = HouseholdCalculator.distribute(Money(units: 100), weights: [1, 1, 1])
        #expect(parts == [Money(cents: 3334), Money(cents: 3333), Money(cents: 3333)])
        #expect(parts.sum() == Money(units: 100))
    }

    @Test("Without a household everything is personal")
    func single() {
        let result = BudgetCalculator.calculate(
            BudgetInput(incomes: incomes, costs: costs, goals: goals, household: nil))
        #expect(result.household == nil)
        #expect(result.personal.fixedCosts == Money(units: 1670))
        #expect(result.personal.savings == Money(units: 325))
        #expect(result.personal.left == Money(units: 245))
    }

    @Test("Negative months are reported, not hidden")
    func shortfall() {
        let result = BudgetCalculator.calculate(
            BudgetInput(
                incomes: [IncomeSource(name: "Job", monthlyNet: Money(units: 1000))], costs: costs, goals: [],
                household: nil))
        #expect(result.personal.left == Money(units: -670))
        #expect(result.personal.leftRatio == 0)
        #expect(result.personal.perDay(over: 30) == .zero)
    }

    @Test("Ratio and per-day value")
    func ratio() {
        let result = BudgetCalculator.calculate(input(.fixedAmounts))
        #expect(result.personal.perDay(over: 30) == Money(units: 32))
        #expect(
            result.personal.leftRatio > Decimal(string: "0.44")!
                && result.personal.leftRatio < Decimal(string: "0.45")!)
    }

    @Test("Recurrences, pauses and savings goals")
    func entries() {
        #expect(
            FixedCost(name: "Insurance", amount: Money(units: 744), recurrence: .yearly, category: .insurance)
                .monthlyAmount == Money(units: 62))
        #expect(
            FixedCost(name: "Paused", amount: Money(units: 50), category: .subscriptions, isPaused: true)
                .monthlyAmount == .zero)
        var goal = SavingsGoal(name: "Bike", target: Money(units: 1000), saved: Money(units: 900), months: 3)
        #expect(goal.monthlyRate == Money(cents: 3334))
        goal.deposit(Money(units: 500))
        #expect(goal.saved == Money(units: 1000) && goal.isReached)
    }
}
