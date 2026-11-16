import CloudKit
import CoreData
import Foundation
import PottCore
import PottStore

/// Fixed costs of one category, or all costs when sorted otherwise.
public struct CostGroup: Identifiable, Sendable, Equatable {
    /// The category, or nil for an unsorted flat list.
    public var category: CategoryID?
    public var costs: [FixedCost]
    public var total: Money

    public var id: String { category?.rawValue ?? "all" }
}

/// Which part of the overview is shown.
public enum OverviewScope: String, Sendable {
    /// Personal view: income minus my share.
    case me
    /// Household view: the shared pot.
    case together
}

/// The observable state behind every screen. Mutations go through the repository and refresh
/// the cached values, so views only read plain value types.
@MainActor
@Observable
public final class AppModel {
    public let settings: AppSettings
    @ObservationIgnored private let repository: Repository

    public private(set) var incomes: [IncomeSource] = []
    public private(set) var costs: [FixedCost] = []
    public private(set) var goals: [SavingsGoal] = []
    public private(set) var household: Repository.HouseholdInfo?
    /// The last failure, for an alert.
    public var failure: String?

    /// True when the household is shared with someone through iCloud.
    public private(set) var isHouseholdShared = false
    /// Recorded months, newest first.
    public private(set) var months: [MonthSummary] = []
    /// The clock; tests replace it.
    @ObservationIgnored public var now: () -> Date = Date.init
    /// Called after every change of the budget, e.g. to update the widget.
    @ObservationIgnored public var onBudgetChange: ((AppModel) -> Void)?
    @ObservationIgnored private var remoteChanges: NSObjectProtocol?

    public init(repository: Repository, settings: AppSettings) {
        self.repository = repository
        self.settings = settings
        reload()
        // Changes from other devices and members arrive through CloudKit; show them right away.
        remoteChanges = NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.reload() }
        }
    }

    /// Reads everything again, e.g. after a remote change.
    public func reload() {
        incomes = repository.incomes()
        costs = repository.costs()
        goals = repository.goals()
        household = repository.household()
        isHouseholdShared = repository.isCloudEnabled && repository.householdShare() != nil
        recordMonth()
        onBudgetChange?(self)
    }

    /// Keeps the summary of the current month up to date; past months stay as they ended.
    private func recordMonth() {
        var stored = repository.monthSummaries()
        let summary = MonthSummary(month: MonthSummary.key(for: now()), budget: budget.personal)
        if stored.first(where: { $0.month == summary.month }) != summary, !(incomes.isEmpty && costs.isEmpty)
        {
            try? repository.save(summary)
            stored = repository.monthSummaries()
        }
        months = stored
    }

    /// Fixed costs whose notice deadline lies ahead, soonest first.
    public var upcomingDeadlines: [(cost: FixedCost, deadline: Date)] {
        costs.compactMap { cost in
            guard let deadline = cost.noticeDeadline(), deadline > now() else { return nil }
            return (cost, deadline)
        }
        .sorted { $0.deadline < $1.deadline }
    }

    // MARK: Derived state

    /// True when the household module is on and this user is one of its members.
    public var householdActive: Bool {
        settings.isOn(.household) && isMember
    }

    /// The user belongs to the household as one of its members.
    public var isMember: Bool {
        guard let household, let me = settings.meMemberID else { return false }
        return household.members.contains { $0.id == me }
    }

    /// A household was joined but the app does not know yet which member this user is.
    public var needsIdentity: Bool {
        settings.isOn(.household) && household != nil && !isMember
    }

    /// The user owns the household or it is not shared.
    public var isHouseholdJoined: Bool { household?.isJoined ?? false }

    public var isCloudEnabled: Bool { repository.isCloudEnabled }

    public var savingsActive: Bool { settings.isOn(.savings) }

    /// The month as the calculator sees it, respecting the modules.
    public var budget: BudgetResult {
        let household: BudgetInput.HouseholdInput? =
            householdActive
            ? self.household.flatMap { info in
                settings.meMemberID.map { .init(me: $0, members: info.members, rule: info.rule) }
            }
            : nil
        return BudgetCalculator.calculate(
            BudgetInput(
                incomes: incomes, costs: costs, goals: savingsActive ? goals : [], household: household))
    }

    /// Costs shown for a scope: personal ones in the personal view (all without a household),
    /// household ones in the household view.
    public func costs(for scope: OverviewScope) -> [FixedCost] {
        guard householdActive else { return costs }
        return costs.filter { $0.scope == (scope == .me ? .personal : .household) }
    }

    /// Savings goals shown for a scope.
    public func goals(for scope: OverviewScope) -> [SavingsGoal] {
        guard savingsActive else { return [] }
        guard householdActive else { return goals }
        return goals.filter { $0.scope == (scope == .me ? .personal : .household) }
    }

    /// Costs grouped by category in the configured order, or one flat sorted list.
    public func groups(_ costs: [FixedCost]) -> [CostGroup] {
        switch settings.sort {
        case .category:
            return settings.categories.compactMap { category in
                let items = costs.filter { $0.category == category }
                guard !items.isEmpty else { return nil }
                return CostGroup(category: category, costs: items, total: items.map(\.monthlyAmount).sum())
            }
                + uncategorized(costs)
        case .amount:
            let sorted = costs.sorted {
                $0.monthlyAmount == $1.monthlyAmount ? $0.name < $1.name : $0.monthlyAmount > $1.monthlyAmount
            }
            return [CostGroup(category: nil, costs: sorted, total: sorted.map(\.monthlyAmount).sum())]
        case .dueDate:
            let sorted = costs.sorted { $0.dueDay == $1.dueDay ? $0.name < $1.name : $0.dueDay < $1.dueDay }
            return [CostGroup(category: nil, costs: sorted, total: sorted.map(\.monthlyAmount).sum())]
        }
    }

    /// Costs whose category no longer exists (e.g. a deleted custom category) end up together.
    private func uncategorized(_ costs: [FixedCost]) -> [CostGroup] {
        let known = Set(settings.categories)
        let rest = costs.filter { !known.contains($0.category) }
        return rest.isEmpty
            ? [] : [CostGroup(category: nil, costs: rest, total: rest.map(\.monthlyAmount).sum())]
    }

    // MARK: Mutations

    public func save(_ cost: FixedCost) { perform { try repository.save(cost) } }
    public func save(_ income: IncomeSource) { perform { try repository.save(income) } }
    public func save(_ goal: SavingsGoal) { perform { try repository.save(goal) } }
    public func save(_ member: Member) { perform { try repository.save(member) } }

    public func delete(_ cost: FixedCost) { perform { try repository.deleteCost(id: cost.id) } }
    public func delete(_ income: IncomeSource) { perform { try repository.deleteIncome(id: income.id) } }
    public func delete(_ goal: SavingsGoal) { perform { try repository.deleteGoal(id: goal.id) } }
    public func delete(_ member: Member) { perform { try repository.deleteMember(id: member.id) } }

    /// Adds one monthly rate to a goal and returns the goal as it was, for undo.
    @discardableResult
    public func deposit(into goal: SavingsGoal) -> SavingsGoal {
        var updated = goal
        updated.deposit(goal.monthlyRate)
        save(updated)
        return goal
    }

    public func setRule(_ rule: SplitRule) { perform { try repository.setRule(rule) } }

    /// Stores a past month, e.g. for demo data or an import.
    public func save(_ summary: MonthSummary) { perform { try repository.save(summary) } }

    /// Creates the household with this user and one partner and switches the module on.
    public func startHousehold(myName: String, partnerName: String) {
        let me = Member(name: myName, fixedContribution: .zero, sharePercent: 50)
        let partner = Member(name: partnerName, fixedContribution: .zero, sharePercent: 50)
        perform {
            if household == nil {
                try repository.createHousehold(name: "", rule: .equal, members: [me, partner])
                settings.meMemberID = me.id
            }
        }
        settings.set(.household, true)
    }

    /// After joining someone else's household: this user is the given member.
    public func claim(_ member: Member) {
        settings.meMemberID = member.id
        settings.set(.household, true)
        syncMyIncome()
    }

    /// After joining someone else's household: this user is a new member.
    public func joinAsNewMember(named name: String) {
        let member = Member(name: name)
        perform { try repository.save(member) }
        claim(member)
    }

    // MARK: Sharing

    /// Shares the household through iCloud and returns what the system sharing sheet needs.
    public func shareHousehold(title: String) async throws -> (share: CKShare, container: CKContainer) {
        let share = try await repository.shareHousehold(title: title)
        guard let container = repository.cloudContainer else { throw Repository.SharingError.noCloud }
        reload()
        return (share, container)
    }

    /// Accepts an invitation and switches the household module on.
    public func accept(_ metadata: CKShare.Metadata) async {
        do {
            try await repository.accept(metadata)
            settings.set(.household, true)
        } catch {
            failure = error.localizedDescription
        }
        reload()
    }

    /// Saves changes the sharing sheet made (participants added or removed, sharing stopped).
    public func shareDidChange(_ share: CKShare?) async {
        if let share {
            try? await repository.persistUpdatedShare(share)
        }
        reload()
    }

    /// Keeps the income of "me" in the household in step with the personal incomes,
    /// so the income-based split stays right.
    public func syncMyIncome() {
        guard let id = settings.meMemberID, var me = household?.members.first(where: { $0.id == id }) else {
            return
        }
        let total = incomes.map(\.monthlyNet).sum()
        guard me.monthlyNetIncome != total else { return }
        me.monthlyNetIncome = total
        save(me)
    }

    private func perform(_ work: () throws -> Void) {
        do {
            try work()
        } catch {
            failure = error.localizedDescription
        }
        reload()
    }

    // MARK: Export

    /// All entries as CSV (semicolon separated, the format German spreadsheet apps expect).
    public func csv(categoryName: (CategoryID) -> String) -> String {
        var lines = ["type;name;amount;recurrence;due day;category;scope;note"]
        func cell(_ text: String) -> String {
            "\"" + text.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        for income in incomes {
            lines.append(
                [
                    "income", cell(income.name), income.monthlyNet.decimal.description, "monthly", "", "",
                    "personal", cell(income.note),
                ].joined(separator: ";"))
        }
        for cost in costs {
            lines.append(
                [
                    "cost", cell(cost.name), cost.amount.decimal.description, cost.recurrence.rawValue,
                    String(cost.dueDay), cell(categoryName(cost.category)), cost.scope.rawValue,
                    cell(cost.note),
                ].joined(separator: ";"))
        }
        for goal in goals {
            lines.append(
                [
                    "savings goal", cell(goal.name), goal.target.decimal.description, "", "", "",
                    goal.scope.rawValue, cell(goal.note),
                ].joined(separator: ";"))
        }
        return lines.joined(separator: "\n") + "\n"
    }
}
