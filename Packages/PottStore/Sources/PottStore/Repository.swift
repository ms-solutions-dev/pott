import CoreData
import Foundation
import PottCore

/// Reads and writes Pott's data as PottCore value types. Core Data stays behind this type.
///
/// Personal entries live in the private store. Household entries live in the store that holds
/// the household: the private store for its owner, the shared store for everyone who joined.
@MainActor
public final class Repository {
    /// The household as the app sees it.
    public struct HouseholdInfo: Sendable, Equatable {
        public var id: UUID
        public var name: String
        public var rule: SplitRule
        public var members: [Member]
        /// True when someone else owns the household and shared it with this user.
        public var isJoined: Bool
    }

    public let persistence: Persistence
    private var context: NSManagedObjectContext { persistence.container.viewContext }

    public init(persistence: Persistence) {
        self.persistence = persistence
    }

    // MARK: Household

    public func household() -> HouseholdInfo? {
        guard let object = householdObject() else { return nil }
        let members = (object.value(forKey: "members") as? Set<NSManagedObject> ?? [])
            .sorted { date($0) < date($1) }
            .map(member(from:))
        return HouseholdInfo(
            id: uuid(object), name: string(object, "name"),
            rule: SplitRule(rawValue: string(object, "rule")) ?? .fixedAmounts,
            members: members,
            isJoined: persistence.sharedStore != nil
                && object.objectID.persistentStore == persistence.sharedStore)
    }

    /// Creates the household in the private store. There is at most one household.
    @discardableResult
    public func createHousehold(name: String, rule: SplitRule, members: [Member]) throws -> UUID {
        if let existing = householdObject() { return uuid(existing) }
        let object = insert(PottModel.Entity.household, id: UUID(), into: persistence.privateStore)
        object.setValue(name, forKey: "name")
        object.setValue(rule.rawValue, forKey: "rule")
        for member in members { try save(member) }
        // Household entries created before the household existed join it now.
        for entity in [PottModel.Entity.fixedCost, PottModel.Entity.savingsGoal] {
            for entry in all(entity) where string(entry, "scope") == Scope.household.rawValue {
                entry.setValue(object, forKey: "household")
            }
        }
        try commit()
        return uuid(object)
    }

    public func setRule(_ rule: SplitRule) throws {
        householdObject()?.setValue(rule.rawValue, forKey: "rule")
        try commit()
    }

    public func save(_ member: Member) throws {
        guard let household = householdObject() else { return }
        let object =
            fetch(PottModel.Entity.member, id: member.id)
            ?? insert(PottModel.Entity.member, id: member.id, into: store(of: household))
        object.setValue(member.name, forKey: "name")
        object.setValue(member.monthlyNetIncome.cents, forKey: "monthlyNetIncomeCents")
        object.setValue(member.fixedContribution.cents, forKey: "fixedContributionCents")
        object.setValue(basisPoints(member.sharePercent), forKey: "shareBasisPoints")
        object.setValue(household, forKey: "household")
        try commit()
    }

    public func deleteMember(id: UUID) throws {
        try delete(PottModel.Entity.member, id: id)
    }

    // MARK: Fixed costs

    public func costs() -> [FixedCost] {
        all(PottModel.Entity.fixedCost).map { object in
            FixedCost(
                id: uuid(object), name: string(object, "name"),
                amount: Money(cents: int(object, "amountCents")),
                recurrence: Recurrence(rawValue: string(object, "recurrence")) ?? .monthly,
                dueDay: Int(int(object, "dueDay")),
                category: CategoryID(rawValue: string(object, "category")),
                scope: Scope(rawValue: string(object, "scope")) ?? .personal,
                note: string(object, "note"),
                isPaused: object.value(forKey: "isPaused") as? Bool ?? false,
                contractEnd: object.value(forKey: "contractEnd") as? Date,
                noticePeriodDays: (object.value(forKey: "noticePeriodDays") as? NSNumber)?.intValue)
        }
    }

    public func save(_ cost: FixedCost) throws {
        let object = try placed(PottModel.Entity.fixedCost, id: cost.id, scope: cost.scope)
        object.setValue(cost.name, forKey: "name")
        object.setValue(cost.amount.cents, forKey: "amountCents")
        object.setValue(cost.recurrence.rawValue, forKey: "recurrence")
        object.setValue(Int16(cost.dueDay), forKey: "dueDay")
        object.setValue(cost.category.rawValue, forKey: "category")
        object.setValue(cost.note, forKey: "note")
        object.setValue(cost.isPaused, forKey: "isPaused")
        object.setValue(cost.contractEnd, forKey: "contractEnd")
        object.setValue(cost.noticePeriodDays.map { Int16(clamping: $0) }, forKey: "noticePeriodDays")
        try commit()
    }

    public func deleteCost(id: UUID) throws {
        try delete(PottModel.Entity.fixedCost, id: id)
    }

    // MARK: Incomes

    public func incomes() -> [IncomeSource] {
        all(PottModel.Entity.income).map { object in
            let summary = object.value(forKey: "originSummary") as? String
            return IncomeSource(
                id: uuid(object), name: string(object, "name"),
                monthlyNet: Money(cents: int(object, "monthlyNetCents")),
                origin: summary.map { .calculator(summary: $0) } ?? .manual,
                note: string(object, "note"))
        }
    }

    public func save(_ income: IncomeSource) throws {
        let object =
            fetch(PottModel.Entity.income, id: income.id)
            ?? insert(PottModel.Entity.income, id: income.id, into: persistence.privateStore)
        object.setValue(income.name, forKey: "name")
        object.setValue(income.monthlyNet.cents, forKey: "monthlyNetCents")
        if case .calculator(let summary) = income.origin {
            object.setValue(summary, forKey: "originSummary")
        } else {
            object.setValue(nil, forKey: "originSummary")
        }
        object.setValue(income.note, forKey: "note")
        try commit()
    }

    public func deleteIncome(id: UUID) throws {
        try delete(PottModel.Entity.income, id: id)
    }

    // MARK: Savings goals

    public func goals() -> [SavingsGoal] {
        all(PottModel.Entity.savingsGoal).map { object in
            SavingsGoal(
                id: uuid(object), name: string(object, "name"),
                target: Money(cents: int(object, "targetCents")),
                saved: Money(cents: int(object, "savedCents")),
                months: Int(int(object, "months")),
                scope: Scope(rawValue: string(object, "scope")) ?? .personal,
                note: string(object, "note"))
        }
    }

    public func save(_ goal: SavingsGoal) throws {
        let object = try placed(PottModel.Entity.savingsGoal, id: goal.id, scope: goal.scope)
        object.setValue(goal.name, forKey: "name")
        object.setValue(goal.target.cents, forKey: "targetCents")
        object.setValue(goal.saved.cents, forKey: "savedCents")
        object.setValue(Int16(goal.months), forKey: "months")
        object.setValue(goal.note, forKey: "note")
        try commit()
    }

    public func deleteGoal(id: UUID) throws {
        try delete(PottModel.Entity.savingsGoal, id: id)
    }

    // MARK: Monthly review

    /// Recorded months, newest first.
    public func monthSummaries() -> [MonthSummary] {
        all(PottModel.Entity.monthSummary).map { object in
            MonthSummary(
                month: string(object, "month"), income: Money(cents: int(object, "incomeCents")),
                fixedCosts: Money(cents: int(object, "fixedCostsCents")),
                savings: Money(cents: int(object, "savingsCents")),
                householdContribution: Money(cents: int(object, "contributionCents")),
                left: Money(cents: int(object, "leftCents")))
        }
        .sorted { $0.month > $1.month }
    }

    /// Stores the summary of a month, replacing an earlier one of the same month. Personal data,
    /// so it stays in the private store.
    public func save(_ summary: MonthSummary) throws {
        let request = NSFetchRequest<NSManagedObject>(entityName: PottModel.Entity.monthSummary)
        request.predicate = NSPredicate(format: "month == %@", summary.month)
        let object =
            (try? context.fetch(request))?.first
            ?? insert(PottModel.Entity.monthSummary, id: UUID(), into: persistence.privateStore)
        object.setValue(summary.month, forKey: "month")
        object.setValue(summary.income.cents, forKey: "incomeCents")
        object.setValue(summary.fixedCosts.cents, forKey: "fixedCostsCents")
        object.setValue(summary.savings.cents, forKey: "savingsCents")
        object.setValue(summary.householdContribution.cents, forKey: "contributionCents")
        object.setValue(summary.left.cents, forKey: "leftCents")
        try commit()
    }

    // MARK: Budget

    /// Everything the calculator needs. Without `me` or with the household module off,
    /// all entries count as personal.
    public func budgetInput(me: UUID?, householdEnabled: Bool) -> BudgetInput {
        let householdInput: BudgetInput.HouseholdInput?
        if householdEnabled, let me, let household = household() {
            householdInput = .init(me: me, members: household.members, rule: household.rule)
        } else {
            householdInput = nil
        }
        return BudgetInput(incomes: incomes(), costs: costs(), goals: goals(), household: householdInput)
    }

    // MARK: Helpers

    /// The household: one shared with this user wins over an own one, so joining a partner's
    /// household replaces a household created before.
    func householdObject() -> NSManagedObject? {
        let households = all(PottModel.Entity.household)
        if let shared = persistence.sharedStore,
            let joined = households.first(where: { $0.objectID.persistentStore == shared })
        {
            return joined
        }
        return households.first
    }

    private func store(of object: NSManagedObject) -> NSPersistentStore {
        object.objectID.persistentStore ?? persistence.privateStore
    }

    /// Returns the object for `id` in the store its scope requires. An entry that changes scope
    /// is recreated in the other store, because Core Data cannot move objects between stores.
    ///
    /// The scope is stored explicitly: a household entry saved before the household exists stays
    /// a household entry and joins the household once it is created.
    private func placed(_ entity: String, id: UUID, scope: Scope) throws -> NSManagedObject {
        let household = scope == .household ? householdObject() : nil
        let target = household.map(store(of:)) ?? persistence.privateStore
        var object = fetch(entity, id: id)
        if let existing = object, existing.objectID.persistentStore != target {
            context.delete(existing)
            object = nil
        }
        let result = object ?? insert(entity, id: id, into: target)
        result.setValue(scope.rawValue, forKey: "scope")
        result.setValue(household, forKey: "household")
        return result
    }

    private func insert(_ entity: String, id: UUID, into store: NSPersistentStore) -> NSManagedObject {
        let object = NSEntityDescription.insertNewObject(forEntityName: entity, into: context)
        context.assign(object, to: store)
        object.setValue(id, forKey: "id")
        object.setValue(Date(), forKey: "createdAt")
        return object
    }

    private func fetch(_ entity: String, id: UUID) -> NSManagedObject? {
        let request = NSFetchRequest<NSManagedObject>(entityName: entity)
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return (try? context.fetch(request))?.first
    }

    private func all(_ entity: String) -> [NSManagedObject] {
        let request = NSFetchRequest<NSManagedObject>(entityName: entity)
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        return (try? context.fetch(request)) ?? []
    }

    private func delete(_ entity: String, id: UUID) throws {
        if let object = fetch(entity, id: id) {
            context.delete(object)
            try commit()
        }
    }

    private func commit() throws {
        if context.hasChanges { try context.save() }
    }

    private func member(from object: NSManagedObject) -> Member {
        Member(
            id: uuid(object), name: string(object, "name"),
            monthlyNetIncome: Money(cents: int(object, "monthlyNetIncomeCents")),
            fixedContribution: Money(cents: int(object, "fixedContributionCents")),
            sharePercent: Decimal(int(object, "shareBasisPoints")) / 100)
    }

    private func basisPoints(_ percent: Decimal) -> Int64 {
        Money(percent).cents
    }

    private func uuid(_ object: NSManagedObject) -> UUID { object.value(forKey: "id") as? UUID ?? UUID() }
    private func string(_ object: NSManagedObject, _ key: String) -> String {
        object.value(forKey: key) as? String ?? ""
    }
    private func int(_ object: NSManagedObject, _ key: String) -> Int64 {
        (object.value(forKey: key) as? NSNumber)?.int64Value ?? 0
    }
    private func date(_ object: NSManagedObject) -> Date {
        object.value(forKey: "createdAt") as? Date ?? .distantPast
    }
}
