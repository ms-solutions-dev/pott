import Foundation
import PottCore
import Testing

@testable import PottStore

@MainActor
@Suite("Repository")
struct RepositoryTests {
    let repository: Repository

    init() throws {
        repository = Repository(persistence: try Persistence(mode: .inMemory))
    }

    @Test("Entries round-trip through Core Data unchanged")
    func roundTrip() throws {
        let cost = FixedCost(
            name: "Phone", amount: Money(units: 20), dueDay: 28, category: .subscriptions,
            note: "Contract 4711")
        let income = IncomeSource(
            name: "Main job", monthlyNet: Money(units: 2000),
            origin: .calculator(summary: "Gross €3,000 · class I"))
        let goal = SavingsGoal(
            name: "Holiday", target: Money(units: 1800), saved: Money(units: 600), months: 8)
        try repository.save(cost)
        try repository.save(income)
        try repository.save(goal)

        #expect(repository.costs() == [cost])
        #expect(repository.incomes() == [income])
        #expect(repository.goals() == [goal])
    }

    @Test("The mockup household computes the same numbers after a round trip")
    func householdBudget() throws {
        let me = Member(
            name: "Me", monthlyNetIncome: Money(units: 2240), fixedContribution: Money(units: 800))
        let partner = Member(
            name: "Partner", monthlyNetIncome: Money(units: 2000), fixedContribution: Money(units: 800))
        try repository.createHousehold(name: "Home", rule: .fixedAmounts, members: [me, partner])
        try repository.save(IncomeSource(name: "Main job", monthlyNet: Money(units: 2000)))
        try repository.save(IncomeSource(name: "Mini job", monthlyNet: Money(units: 240)))
        for (name, euros, scope) in [
            ("Rent", 820, Scope.household), ("Groceries", 350, .household), ("Power", 120, .household),
            ("Internet", 40, .household), ("Car", 210, .personal), ("Gym", 30, .personal),
            ("Phone", 20, .personal),
            ("Streaming", 18, .personal),
        ] {
            try repository.save(
                FixedCost(name: name, amount: Money(units: Int64(euros)), category: .housing, scope: scope))
        }
        try repository.save(
            FixedCost(
                name: "Insurance", amount: Money(units: 744), recurrence: .yearly, category: .insurance,
                scope: .household))
        try repository.save(
            SavingsGoal(
                name: "Holiday", target: Money(units: 1800), saved: Money(units: 600), months: 8,
                scope: .household))
        try repository.save(
            SavingsGoal(name: "Emergency", target: Money(units: 5000), saved: Money(units: 3200), months: 18))
        try repository.save(
            SavingsGoal(name: "Phone", target: Money(units: 900), saved: Money(units: 300), months: 8))

        let household = try #require(repository.household())
        #expect(household.members.map(\.name) == ["Me", "Partner"])
        #expect(household.isJoined == false)

        let result = BudgetCalculator.calculate(repository.budgetInput(me: me.id, householdEnabled: true))
        #expect(result.household?.balance == Money(units: 58))
        #expect(result.personal.left == Money(units: 987))

        let single = BudgetCalculator.calculate(repository.budgetInput(me: me.id, householdEnabled: false))
        #expect(single.household == nil)
        #expect(single.personal.left == Money(units: 245))
    }

    @Test("Changing the scope moves an entry into the household and back")
    func scopeChange() throws {
        try repository.createHousehold(name: "Home", rule: .equal, members: [Member(name: "Me")])
        var cost = FixedCost(name: "Internet", amount: Money(units: 40), category: .subscriptions)
        try repository.save(cost)
        cost.scope = .household
        try repository.save(cost)
        #expect(repository.costs().map(\.scope) == [.household])
        cost.scope = .personal
        try repository.save(cost)
        #expect(repository.costs().map(\.scope) == [.personal])
        #expect(repository.costs().count == 1)
    }

    @Test("Deleting entries and the split rule")
    func deleteAndRule() throws {
        try repository.createHousehold(
            name: "Home", rule: .fixedAmounts, members: [Member(name: "Me", sharePercent: 60)])
        try repository.setRule(.customShares)
        #expect(repository.household()?.rule == .customShares)
        #expect(repository.household()?.members.first?.sharePercent == 60)
        let income = IncomeSource(name: "Job", monthlyNet: Money(units: 100))
        try repository.save(income)
        try repository.deleteIncome(id: income.id)
        #expect(repository.incomes().isEmpty)
    }
}
