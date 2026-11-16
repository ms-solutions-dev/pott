import Foundation
import PottCore
import Testing

@testable import PottStore

@MainActor
@Suite("Scope")
struct ScopeTests {
    @Test("A household entry saved before the household exists keeps its scope and joins it later")
    func earlyHouseholdEntry() throws {
        let repository = Repository(persistence: try Persistence(mode: .inMemory))
        let rent = FixedCost(name: "Rent", amount: Money(units: 820), category: .housing, scope: .household)
        try repository.save(rent)
        #expect(repository.costs().first?.scope == .household)

        let me = Member(name: "Me")
        try repository.createHousehold(name: "Home", rule: .equal, members: [me, Member(name: "Partner")])
        let result = BudgetCalculator.calculate(repository.budgetInput(me: me.id, householdEnabled: true))
        #expect(result.household?.required == Money(units: 820))
        #expect(result.personal.householdContribution == Money(units: 410))
    }
}
