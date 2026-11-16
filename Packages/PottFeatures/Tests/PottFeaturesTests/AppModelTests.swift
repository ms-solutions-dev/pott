import Foundation
import PottCore
import PottStore
import Testing

@testable import PottFeatures

@MainActor
@Suite("AppModel")
struct AppModelTests {
    let model: AppModel

    init() throws {
        let defaults = UserDefaults(suiteName: "pott-tests-\(UUID().uuidString)")!
        model = AppModel(
            repository: Repository(persistence: try Persistence(mode: .inMemory)),
            settings: AppSettings(defaults: defaults))
        model.save(IncomeSource(name: "Main job", monthlyNet: Money(units: 2000)))
        model.save(FixedCost(name: "Rent", amount: Money(units: 820), category: .housing, scope: .household))
        model.save(FixedCost(name: "Phone", amount: Money(units: 20), dueDay: 28, category: .subscriptions))
        model.save(FixedCost(name: "Car", amount: Money(units: 210), dueDay: 5, category: .mobility))
        model.save(SavingsGoal(name: "Holiday", target: Money(units: 1200), months: 12))
    }

    @Test("Fresh settings start simple: calculator and explanations only")
    func defaults() {
        #expect(model.settings.modules == [.calculator, .explanations])
        #expect(!model.householdActive)
    }

    @Test("Without modules everything is personal and goals are ignored")
    func simpleMode() {
        #expect(model.budget.personal.fixedCosts == Money(units: 1050))
        #expect(model.budget.personal.savings == .zero)
        #expect(model.budget.personal.left == Money(units: 950))
        #expect(model.goals(for: .me).isEmpty)
    }

    @Test("Savings module adds the monthly rates")
    func savings() {
        model.settings.set(.savings, true)
        #expect(model.budget.personal.savings == Money(units: 100))
        #expect(model.goals(for: .me).count == 1)
    }

    @Test("Household splits costs into my view and the shared view")
    func household() throws {
        model.startHousehold(myName: "Me", partnerName: "Partner")
        #expect(model.householdActive)
        #expect(model.costs(for: .me).map(\.name).sorted() == ["Car", "Phone"])
        #expect(model.costs(for: .together).map(\.name) == ["Rent"])
        let pot = try #require(model.budget.household)
        #expect(pot.required == Money(units: 820))
        #expect(model.budget.personal.householdContribution == Money(units: 410))
        #expect(model.budget.personal.left == Money(units: 1360))
    }

    @Test("Sorting by category, amount and due date")
    func sorting() {
        #expect(model.groups(model.costs).map(\.category) == [.housing, .subscriptions, .mobility])
        model.settings.sort = .amount
        #expect(model.groups(model.costs).first?.costs.map(\.name) == ["Rent", "Car", "Phone"])
        model.settings.sort = .dueDate
        #expect(model.groups(model.costs).first?.costs.map(\.name) == ["Rent", "Car", "Phone"])
    }

    @Test("Deposit returns the previous goal for undo")
    func depositUndo() throws {
        let goal = try #require(model.goals.first)
        let before = model.deposit(into: goal)
        #expect(model.goals.first?.saved == Money(units: 100))
        model.save(before)
        #expect(model.goals.first?.saved == .zero)
    }

    @Test("CSV export quotes text and keeps amounts exact")
    func csv() {
        model.save(
            FixedCost(name: "Streaming \"Plus\"", amount: Money(cents: 1836), category: .subscriptions))
        let csv = model.csv { $0.rawValue }
        #expect(csv.contains("\"Streaming \"\"Plus\"\"\";18.36;monthly"))
        #expect(csv.hasPrefix("type;name;amount"))
    }

    @Test("My household income follows my incomes")
    func incomeSync() {
        model.startHousehold(myName: "Me", partnerName: "Partner")
        model.syncMyIncome()
        let me = model.household?.members.first { $0.id == model.settings.meMemberID }
        #expect(me?.monthlyNetIncome == Money(units: 2000))
    }
}
