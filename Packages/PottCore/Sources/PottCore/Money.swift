import Foundation

/// An exact amount of money, stored as whole cents.
///
/// Money never passes through `Double`. Conversions from `Decimal` round half away
/// from zero to the cent, which is the commercial rounding used on German payslips.
public struct Money: Hashable, Sendable, Codable, Comparable {
    /// The amount in cents. Negative values are allowed.
    public var cents: Int64

    public static let zero = Money(cents: 0)

    public init(cents: Int64) {
        self.cents = cents
    }

    /// Creates an amount from a decimal value in currency units, rounded to the cent.
    public init(_ amount: Decimal) {
        var scaled = amount * 100
        var rounded = Decimal()
        NSDecimalRound(&rounded, &scaled, 0, .plain)
        self.cents = NSDecimalNumber(decimal: rounded).int64Value
    }

    /// Creates an amount from whole currency units.
    public init(units: Int64) {
        self.cents = units * 100
    }

    /// The amount in currency units.
    public var decimal: Decimal {
        Decimal(cents) / 100
    }

    public var isNegative: Bool { cents < 0 }

    public var magnitude: Money { Money(cents: Swift.abs(cents)) }

    public static func < (lhs: Money, rhs: Money) -> Bool { lhs.cents < rhs.cents }

    public static func + (lhs: Money, rhs: Money) -> Money { Money(cents: lhs.cents + rhs.cents) }

    public static func - (lhs: Money, rhs: Money) -> Money { Money(cents: lhs.cents - rhs.cents) }

    public static prefix func - (value: Money) -> Money { Money(cents: -value.cents) }

    public static func += (lhs: inout Money, rhs: Money) { lhs = lhs + rhs }

    public static func -= (lhs: inout Money, rhs: Money) { lhs = lhs - rhs }

    /// Multiplies by a decimal factor and rounds to the cent.
    public static func * (lhs: Money, rhs: Decimal) -> Money { Money(lhs.decimal * rhs) }

    /// Divides by a decimal divisor and rounds to the cent.
    public static func / (lhs: Money, rhs: Decimal) -> Money { Money(lhs.decimal / rhs) }

    /// Formats the amount as currency. Whole amounts are shown without decimals.
    public func formatted(currencyCode: String = "EUR", locale: Locale = .current) -> String {
        let style = Decimal.FormatStyle.Currency(code: currencyCode, locale: locale)
        let whole = cents % 100 == 0
        return decimal.formatted(style.precision(.fractionLength(whole ? 0 : 2)))
    }
}

extension Sequence where Element == Money {
    /// The total of all amounts.
    public func sum() -> Money {
        reduce(.zero, +)
    }
}
