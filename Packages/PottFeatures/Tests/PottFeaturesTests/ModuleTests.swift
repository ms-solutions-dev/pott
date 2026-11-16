import Foundation
import PottCore
import PottStore
import Testing

@testable import PottFeatures

@MainActor
@Suite("Monthly review and reminders")
struct ModuleTests {
    func makeModel() throws -> AppModel {
        let defaults = UserDefaults(suiteName: "pott-modules-\(UUID().uuidString)")!
        return AppModel(
            repository: Repository(persistence: try Persistence(mode: .inMemory)),
            settings: AppSettings(defaults: defaults))
    }

    func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    @Test("Every month keeps how it ended")
    func months() throws {
        let model = try makeModel()
        model.now = { self.date(2026, 10, 15) }
        model.save(IncomeSource(name: "Job", monthlyNet: Money(units: 2000)))
        model.save(FixedCost(name: "Rent", amount: Money(units: 800), category: .housing))
        model.now = { self.date(2026, 11, 3) }
        model.save(FixedCost(name: "Gym", amount: Money(units: 30), category: .subscriptions))
        #expect(model.months.map(\.month) == ["2026-11", "2026-10"])
        #expect(model.months.first?.left == Money(units: 1170))
        #expect(model.months.last?.left == Money(units: 1200))
    }

    @Test("Notice deadlines ahead, soonest first; contract dates survive a round trip")
    func deadlines() throws {
        let model = try makeModel()
        model.now = { self.date(2026, 11, 1) }
        model.save(
            FixedCost(
                name: "Phone", amount: Money(units: 20), category: .subscriptions,
                contractEnd: date(2027, 3, 31),
                noticePeriodDays: 30))
        model.save(
            FixedCost(
                name: "Internet", amount: Money(units: 40), category: .subscriptions,
                contractEnd: date(2027, 1, 31),
                noticePeriodDays: 90))
        model.save(
            FixedCost(
                name: "Old", amount: Money(units: 5), category: .subscriptions, contractEnd: date(2026, 10, 1)
            ))
        #expect(model.upcomingDeadlines.map(\.cost.name) == ["Internet", "Phone"])
        #expect(model.costs.first { $0.name == "Phone" }?.noticePeriodDays == 30)
    }

    @Test("The budget hook runs after changes")
    func hook() throws {
        let model = try makeModel()
        var calls = 0
        model.onBudgetChange = { _ in calls += 1 }
        model.save(IncomeSource(name: "Job", monthlyNet: Money(units: 1000)))
        #expect(calls == 1)
    }
}
