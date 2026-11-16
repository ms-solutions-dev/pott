import Foundation
import Testing

@testable import PottCore

@Suite("Money")
struct MoneyTests {
    @Test("Decimal amounts round half away from zero to the cent")
    func rounding() {
        #expect(Money(Decimal(string: "18.365")!).cents == 1837)
        #expect(Money(Decimal(string: "18.364")!).cents == 1836)
        #expect(Money(Decimal(string: "-18.365")!).cents == -1837)
    }

    @Test("Division keeps cents exact where possible")
    func division() {
        #expect((Money(units: 744) / 12).cents == 6200)
        #expect((Money(Decimal(string: "55.08")!) / 3).cents == 1836)
        #expect((Money(units: 100) / 3).cents == 3333)
    }

    @Test("Arithmetic and sums")
    func arithmetic() {
        let total = [Money(units: 820), Money(units: 120), Money(cents: 1836)].sum()
        #expect(total.cents == 95_836)
        #expect((Money(units: 2000) - Money(units: 2100)).isNegative)
        #expect((-Money(units: 5)).magnitude == Money(units: 5))
    }

    @Test("German formatting drops zero cents")
    func formatting() {
        let de = Locale(identifier: "de_DE")
        #expect(Money(units: 1525).formatted(locale: de) == "1.525\u{a0}€")
        #expect(Money(cents: 1836).formatted(locale: de) == "18,36\u{a0}€")
    }
}
