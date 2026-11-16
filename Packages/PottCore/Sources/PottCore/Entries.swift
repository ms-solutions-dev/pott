import Foundation

/// Who an entry belongs to.
public enum Scope: String, Sendable, Codable {
    /// Visible to and paid by one person only.
    case personal
    /// Part of the household and paid from the household pot.
    case household
}

/// A category that groups fixed costs. Built-in categories have stable identifiers;
/// users can add their own.
public struct CategoryID: Hashable, Sendable, Codable, RawRepresentable {
    public var rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static let housing = CategoryID(rawValue: "housing")
    public static let everyday = CategoryID(rawValue: "everyday")
    public static let energy = CategoryID(rawValue: "energy")
    public static let subscriptions = CategoryID(rawValue: "subscriptions")
    public static let mobility = CategoryID(rawValue: "mobility")
    public static let insurance = CategoryID(rawValue: "insurance")

    /// The built-in categories in their default order.
    public static let builtIn: [CategoryID] = [
        .housing, .everyday, .energy, .subscriptions, .mobility, .insurance,
    ]
}

/// A recurring cost such as rent, a phone contract or insurance.
public struct FixedCost: Identifiable, Hashable, Sendable, Codable {
    public var id: UUID
    public var name: String
    /// The amount of one payment.
    public var amount: Money
    public var recurrence: Recurrence
    /// Day of the month the payment is due, 1…31.
    public var dueDay: Int
    public var category: CategoryID
    public var scope: Scope
    public var note: String
    /// Paused costs are kept but not counted.
    public var isPaused: Bool
    /// When the contract ends unless it is renewed, for reminders.
    public var contractEnd: Date?
    /// Notice period in days before `contractEnd`.
    public var noticePeriodDays: Int?

    public init(
        id: UUID = UUID(), name: String, amount: Money, recurrence: Recurrence = .monthly, dueDay: Int = 1,
        category: CategoryID, scope: Scope = .personal, note: String = "", isPaused: Bool = false,
        contractEnd: Date? = nil, noticePeriodDays: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.amount = amount
        self.recurrence = recurrence
        self.dueDay = min(max(dueDay, 1), 31)
        self.category = category
        self.scope = scope
        self.note = note
        self.isPaused = isPaused
        self.contractEnd = contractEnd
        self.noticePeriodDays = noticePeriodDays
    }

    /// What this cost takes from a single month.
    public var monthlyAmount: Money {
        isPaused ? .zero : recurrence.monthlyShare(of: amount)
    }

    /// The last day to give notice, if a contract end is known.
    public func noticeDeadline(calendar: Calendar = .current) -> Date? {
        guard let contractEnd else { return nil }
        return calendar.date(byAdding: .day, value: -(noticePeriodDays ?? 0), to: contractEnd)
    }

    /// When to remind: two weeks before the notice deadline, or the deadline itself if that is
    /// closer than two weeks from `now`. Nil when the deadline has passed.
    public func reminderDate(now: Date = .now, calendar: Calendar = .current) -> Date? {
        guard let deadline = noticeDeadline(calendar: calendar), deadline > now else { return nil }
        let early = calendar.date(byAdding: .day, value: -14, to: deadline) ?? deadline
        return early > now ? early : deadline
    }
}

/// What one month looked like, kept for the monthly review.
public struct MonthSummary: Identifiable, Hashable, Sendable, Codable {
    /// "2026-10".
    public var month: String
    public var income: Money
    public var fixedCosts: Money
    public var savings: Money
    public var householdContribution: Money
    public var left: Money

    public var id: String { month }

    public init(month: String, budget: PersonalBudget) {
        self.month = month
        income = budget.income
        fixedCosts = budget.fixedCosts
        savings = budget.savings
        householdContribution = budget.householdContribution
        left = budget.left
    }

    public init(
        month: String, income: Money, fixedCosts: Money, savings: Money, householdContribution: Money,
        left: Money
    ) {
        self.month = month
        self.income = income
        self.fixedCosts = fixedCosts
        self.savings = savings
        self.householdContribution = householdContribution
        self.left = left
    }

    /// The key of the month that contains `date`.
    public static func key(for date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", parts.year ?? 0, parts.month ?? 0)
    }
}

/// A source of income, already net.
public struct IncomeSource: Identifiable, Hashable, Sendable, Codable {
    /// Where the amount comes from.
    public enum Origin: Hashable, Sendable, Codable {
        case manual
        /// Taken over from the pay calculator; `summary` describes the inputs, e.g. "Gross €3,000 · class I".
        case calculator(summary: String)
    }

    public var id: UUID
    public var name: String
    public var monthlyNet: Money
    public var origin: Origin
    public var note: String

    public init(
        id: UUID = UUID(), name: String, monthlyNet: Money, origin: Origin = .manual, note: String = ""
    ) {
        self.id = id
        self.name = name
        self.monthlyNet = monthlyNet
        self.origin = origin
        self.note = note
    }
}

/// Something saved for, such as a holiday or an emergency fund.
public struct SavingsGoal: Identifiable, Hashable, Sendable, Codable {
    public var id: UUID
    public var name: String
    public var target: Money
    public var saved: Money
    /// Months planned to reach the target, counted from now.
    public var months: Int
    public var scope: Scope
    public var note: String

    public init(
        id: UUID = UUID(), name: String, target: Money, saved: Money = .zero, months: Int,
        scope: Scope = .personal,
        note: String = ""
    ) {
        self.id = id
        self.name = name
        self.target = target
        self.saved = saved
        self.months = max(months, 1)
        self.scope = scope
        self.note = note
    }

    /// What is still missing.
    public var remaining: Money {
        max(target - saved, .zero)
    }

    /// The monthly rate needed to reach the target in time, rounded up to the cent.
    public var monthlyRate: Money {
        let cents = remaining.cents
        let months = Int64(self.months)
        return Money(cents: (cents + months - 1) / months)
    }

    /// Progress between 0 and 1.
    public var progress: Decimal {
        guard target.cents > 0 else { return 1 }
        return min(saved.decimal / target.decimal, 1)
    }

    public var isReached: Bool { saved >= target }

    /// Adds one monthly rate, capped at the target.
    public mutating func deposit(_ amount: Money) {
        saved = min(saved + amount, target)
    }
}
