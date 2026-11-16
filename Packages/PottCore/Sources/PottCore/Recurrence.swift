import Foundation

/// How often a fixed cost is due.
public enum Recurrence: String, Sendable, Codable, CaseIterable {
    case monthly
    case quarterly
    case yearly

    /// Number of months one payment covers.
    public var months: Int {
        switch self {
        case .monthly: 1
        case .quarterly: 3
        case .yearly: 12
        }
    }

    /// The share of one payment that falls on a single month, rounded to the cent.
    public func monthlyShare(of amount: Money) -> Money {
        amount / Decimal(months)
    }
}
