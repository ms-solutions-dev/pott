import Foundation
import Testing

@testable import PottCore

@Suite("Money input")
struct MoneyInputTests {
    let de = Locale(identifier: "de_DE")
    let en = Locale(identifier: "en_US")

    @Test(
        "German input",
        arguments: [
            ("18,36", 1836), ("1.525,50", 152_550), ("1.525", 152_500), ("20", 2000), ("€ 20,5", 2050),
            ("0,99", 99),
            ("1525.5", 152_550), ("2.000.000", 200_000_000),
        ])
    func german(text: String, cents: Int64) {
        #expect(Money.parse(text, locale: de)?.cents == cents)
    }

    @Test(
        "English input",
        arguments: [("18.36", 1836), ("1,525.50", 152_550), ("1,525", 152_500), ("$20", 2000)])
    func english(text: String, cents: Int64) {
        #expect(Money.parse(text, locale: en)?.cents == cents)
    }

    @Test("Rejects text without digits")
    func invalid() {
        #expect(Money.parse("", locale: de) == nil)
        #expect(Money.parse("abc", locale: de) == nil)
        #expect(Money.parse("-12,5", locale: de)?.cents == -1250)
    }

    @Test("Editing text round-trips")
    func editing() {
        #expect(Money(cents: 1836).editingText(locale: de) == "18,36")
        #expect(Money(units: 1525).editingText(locale: de) == "1525")
        #expect(Money.parse(Money(cents: 152_550).editingText(locale: de), locale: de)?.cents == 152_550)
    }
}
