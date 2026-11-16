import Foundation
import PottCore
import PottFeatures
import PottStore
/// Example data for screenshots and checks, started with the launch argument `-PottDemo`.
///
/// `-PottDemo simple` shows one person without modules, `-PottDemo full` a couple with household
/// and savings goals (the numbers of the design mockup). Nothing is written to disk.
import TaxDE

enum DemoData {
    @MainActor
    static func model(for arguments: [String]) -> AppModel? {
        guard let index = arguments.firstIndex(of: "-PottDemo") else { return nil }
        let variant = arguments.indices.contains(index + 1) ? arguments[index + 1] : "full"
        guard let defaults = UserDefaults(suiteName: "pott-demo"),
            let persistence = try? Persistence(mode: .inMemory)
        else { return nil }
        defaults.removePersistentDomain(forName: "pott-demo")
        let settings = AppSettings(defaults: defaults)
        settings.hasOnboarded = true
        let model = AppModel(repository: Repository(persistence: persistence), settings: settings)
        fill(model, full: variant != "simple")
        if arguments.contains("-PottSelfEmployed") {
            // A trade business with statutory insurance, for screenshots of the self-employed view.
            model.settings.calculatorSelfEmployed = true
            model.settings.selfEmployedInput = SelfEmployedInput(
                monthlyProfit: Money(units: 6000), isTrade: true, pension: .statutory)
        }
        if arguments.contains("-PottSpecialCases") {
            // A company car and a Christmas bonus, for screenshots of the special cases.
            model.settings.payInput.gross = Money(units: 4500)
            model.settings.payInput.companyCar = CompanyCar(
                listPrice: Money(units: 60_000), kind: .electric, commuteKilometres: 20)
            model.settings.payInput.oneOffPayment = Money(units: 3000)
        }
        return model
    }

    @MainActor
    private static func fill(_ model: AppModel, full: Bool) {
        let shared: Scope = full ? .household : .personal
        // The gross that really gives €2,000 net, so the demo agrees with the calculator.
        let gross =
            GermanPayCalculator().grossNeeded(forNet: Money(units: 2000), PayInput(gross: .zero))?.gross
            ?? .zero
        model.save(
            IncomeSource(
                name: String(localized: "Main job"), monthlyNet: Money(units: 2000),
                origin: .calculator(summary: String(localized: "Gross \(gross.text) · class I"))))
        if full {
            model.save(IncomeSource(name: String(localized: "Mini job"), monthlyNet: Money(units: 240)))
        }
        let costs: [(String, CategoryID, Int64, Recurrence, Int, Scope, String)] = [
            (
                String(localized: "Rent"), .housing, 820, .monthly, 1, shared,
                String(localized: "Warm rent incl. service charges")
            ),
            (String(localized: "Groceries"), .everyday, 350, .monthly, 1, shared, ""),
            (String(localized: "Power & gas"), .energy, 120, .monthly, 15, shared, ""),
            (String(localized: "Insurance"), .insurance, 744, .yearly, 1, shared, ""),
            (String(localized: "Internet"), .subscriptions, 40, .monthly, 3, shared, "Kd.-Nr. 1234567"),
            (String(localized: "Car"), .mobility, 210, .monthly, 5, .personal, ""),
            (String(localized: "Gym"), .subscriptions, 30, .monthly, 1, .personal, ""),
            (String(localized: "Phone"), .subscriptions, 20, .monthly, 28, .personal, "Vertrag 4711-0815"),
            (String(localized: "Streaming"), .subscriptions, 18, .monthly, 12, .personal, ""),
        ]
        for (name, category, euros, recurrence, day, scope, note) in costs {
            model.save(
                FixedCost(
                    name: name, amount: Money(units: euros), recurrence: recurrence, dueDay: day,
                    category: category,
                    scope: scope, note: note))
        }
        guard full else { return }
        // A phone contract whose notice deadline is close, and five past months.
        if var phone = model.costs.first(where: { $0.dueDay == 28 }) {
            phone.contractEnd = Calendar.current.date(byAdding: .day, value: 50, to: .now)
            phone.noticePeriodDays = 30
            model.save(phone)
        }
        let history: [(Int, Int64)] = [(5, 760), (4, 905), (3, 640), (2, 1010), (1, 880)]
        for (offset, euros) in history {
            guard let date = Calendar.current.date(byAdding: .month, value: -offset, to: .now) else {
                continue
            }
            model.save(
                MonthSummary(
                    month: MonthSummary.key(for: date), income: Money(units: 2240),
                    fixedCosts: Money(units: 278),
                    savings: Money(units: 175), householdContribution: Money(units: 800),
                    left: Money(units: euros)))
        }
        model.settings.set(.monthlyReview, true)
        model.settings.set(.contractReminders, true)
        model.save(
            SavingsGoal(
                name: String(localized: "Holiday"), target: Money(units: 1800), saved: Money(units: 600),
                months: 8,
                scope: .household))
        model.save(
            SavingsGoal(
                name: String(localized: "Emergency fund"), target: Money(units: 5000),
                saved: Money(units: 3200), months: 18))
        model.save(
            SavingsGoal(
                name: String(localized: "New phone"), target: Money(units: 900), saved: Money(units: 300),
                months: 8))
        model.settings.set(.savings, true)
        model.startHousehold(myName: String(localized: "Me"), partnerName: String(localized: "Partner"))
        model.setRule(.fixedAmounts)
        for member in model.household?.members ?? [] {
            var updated = member
            updated.fixedContribution = Money(units: 800)
            model.save(updated)
        }
        model.syncMyIncome()
    }
}
