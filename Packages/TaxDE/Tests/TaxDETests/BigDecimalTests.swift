import Foundation
import Testing

@testable import TaxDE

@Suite("BigDecimal (Java semantics)")
struct BigDecimalTests {
    func value(_ text: String) -> BigDecimal { BigDecimal(literal: text) }

    @Test("ROUND_DOWN truncates toward zero, ROUND_UP rounds away from zero")
    func rounding() {
        #expect(value("1.239").setScale(2, .roundDown) == value("1.23"))
        #expect(value("-1.239").setScale(2, .roundDown) == value("-1.23"))
        #expect(value("1.231").setScale(2, .roundUp) == value("1.24"))
        #expect(value("-1.231").setScale(2, .roundUp) == value("-1.24"))
        #expect(value("1.230").setScale(2, .roundUp) == value("1.23"))
    }

    @Test("Division with scale")
    func division() {
        #expect(value("300000").divide(value("100"), 2, .roundDown) == value("3000"))
        #expect(value("1").divide(value("3"), 2, .roundUp) == value("0.34"))
        #expect(value("2.9").divide(value("2")).divide(value("100")) == value("0.0145"))
    }

    @Test("Comparisons and integer part")
    func compare() {
        #expect(value("1").compareTo(value("2")) == -1)
        #expect(value("2").compareTo(value("2.00")) == 0)
        #expect(value("12.99").longValue() == 12)
        #expect(BigDecimal.valueOf(0.093) == value("0.093"))
    }
}
