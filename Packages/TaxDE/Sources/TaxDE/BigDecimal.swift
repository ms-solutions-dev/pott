import Foundation

/// The subset of Java's `BigDecimal` the BMF program flow chart uses, on top of `Decimal`.
///
/// The generated code calls exactly these methods with Java semantics: `add`, `subtract` and
/// `multiply` are exact, `divide` with a scale rounds with the given mode, `ROUND_DOWN` rounds
/// toward zero and `ROUND_UP` away from zero.
struct BigDecimal: Equatable, Sendable {
    enum Rounding: Sendable {
        case roundDown
        case roundUp
    }

    var value: Decimal

    static let zero = BigDecimal(Decimal(0))
    static let one = BigDecimal(Decimal(1))

    init(_ value: Decimal) {
        self.value = value
    }

    /// A literal from the flow chart, e.g. "0.093".
    init(literal: String) {
        guard let value = Decimal(string: literal, locale: Locale(identifier: "en_US_POSIX")) else {
            preconditionFailure("Invalid literal \(literal)")
        }
        self.value = value
    }

    static func valueOf(_ value: Int) -> BigDecimal { BigDecimal(Decimal(value)) }

    /// Java's `valueOf(double)` goes through the shortest decimal representation.
    static func valueOf(_ value: Double) -> BigDecimal { BigDecimal(literal: "\(value)") }

    func add(_ other: BigDecimal) -> BigDecimal { BigDecimal(value + other.value) }
    func subtract(_ other: BigDecimal) -> BigDecimal { BigDecimal(value - other.value) }
    func multiply(_ other: BigDecimal) -> BigDecimal { BigDecimal(value * other.value) }

    /// Exact division; the flow chart only uses it where the result terminates.
    func divide(_ other: BigDecimal) -> BigDecimal { BigDecimal(value / other.value) }

    func divide(_ other: BigDecimal, _ scale: Int, _ rounding: Rounding) -> BigDecimal {
        BigDecimal(Self.round(value / other.value, scale, rounding))
    }

    func setScale(_ scale: Int, _ rounding: Rounding) -> BigDecimal {
        BigDecimal(Self.round(value, scale, rounding))
    }

    func compareTo(_ other: BigDecimal) -> Int {
        value < other.value ? -1 : (value > other.value ? 1 : 0)
    }

    /// Integer part, truncated toward zero.
    func longValue() -> Int {
        NSDecimalNumber(decimal: Self.round(value, 0, .roundDown)).intValue
    }

    static func round(_ value: Decimal, _ scale: Int, _ rounding: Rounding) -> Decimal {
        var source = value
        var result = Decimal()
        let towardZero = rounding == .roundDown
        // NSDecimalRound's .down/.up round toward −∞/+∞; Java's modes are relative to zero.
        let mode: NSDecimalNumber.RoundingMode =
            value >= 0 ? (towardZero ? .down : .up) : (towardZero ? .up : .down)
        NSDecimalRound(&result, &source, scale, mode)
        return result
    }
}
