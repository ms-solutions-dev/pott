import Foundation

extension Money {
    /// Reads an amount the way people type it: "18,36", "1.525,50", "1525.5", "€ 20".
    ///
    /// With both separators present, the last one is the decimal separator. A single separator
    /// followed by exactly three digits is a thousands separator when the locale uses the other
    /// one for decimals ("1.525" in German is 1525). Returns nil for anything that is not a number.
    public static func parse(_ text: String, locale: Locale = .current) -> Money? {
        var cleaned = text.filter { $0.isNumber || $0 == "," || $0 == "." || $0 == "-" }
        guard cleaned.contains(where: \.isNumber) else { return nil }
        let negative = cleaned.hasPrefix("-")
        cleaned.removeAll { $0 == "-" }

        let localeDecimal = locale.decimalSeparator ?? "."
        let lastComma = cleaned.lastIndex(of: ",")
        let lastDot = cleaned.lastIndex(of: ".")
        var decimalSeparator: Character?
        switch (lastComma, lastDot) {
        case (let comma?, let dot?):
            decimalSeparator = comma > dot ? "," : "."
        case (let comma?, nil):
            decimalSeparator =
                isThousands(cleaned, after: comma, localeDecimal: localeDecimal, separator: ",") ? nil : ","
        case (nil, let dot?):
            decimalSeparator =
                isThousands(cleaned, after: dot, localeDecimal: localeDecimal, separator: ".") ? nil : "."
        case (nil, nil):
            decimalSeparator = nil
        }

        var normalized = ""
        var seenDecimal = false
        for character in cleaned.reversed() {
            if character == decimalSeparator && !seenDecimal {
                normalized.append(".")
                seenDecimal = true
            } else if character.isNumber {
                normalized.append(character)
            }
        }
        normalized = String(normalized.reversed())
        guard let value = Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX")) else {
            return nil
        }
        return Money(negative ? -value : value)
    }

    private static func isThousands(
        _ text: String, after index: String.Index, localeDecimal: String, separator: Character
    )
        -> Bool
    {
        let digitsAfter = text[text.index(after: index)...].filter(\.isNumber).count
        let occurrences = text.filter { $0 == separator }.count
        return occurrences > 1 || (digitsAfter == 3 && localeDecimal != String(separator))
    }

    /// The amount as an editable string without currency symbol, e.g. "18,36" or "1525".
    public func editingText(locale: Locale = .current) -> String {
        decimal.formatted(
            .number.locale(locale).grouping(.never).precision(.fractionLength(cents % 100 == 0 ? 0 : 2)))
    }
}
