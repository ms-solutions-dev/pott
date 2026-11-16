import Foundation
import PottCore
import Testing

@testable import TaxDE

@Suite("German pay calculator 2026")
struct PayCalculatorTests {
    let calculator = GermanPayCalculator()

    @Test("€3,000 in class I without church and children")
    func standard() {
        let result = calculator.calculate(PayInput(gross: Money(units: 3000)))
        #expect(result.amount(of: .incomeTax) == Money(cents: 29_308))  // BMF interface
        #expect(result.amount(of: .solidaritySurcharge) == .zero)
        #expect(result.amount(of: .healthInsurance) == Money(cents: 26_250))  // 7.3 % + 1.45 %
        #expect(result.amount(of: .careInsurance) == Money(units: 72))  // 1.8 % + 0.6 % childless
        #expect(result.amount(of: .pensionInsurance) == Money(units: 279))
        #expect(result.amount(of: .unemploymentInsurance) == Money(units: 39))
        #expect(result.net == Money(cents: 205_442))
    }

    @Test("Contributions stop at the ceilings")
    func ceilings() {
        let result = calculator.calculate(PayInput(gross: Money(units: 9000), isParent: true))
        #expect(result.amount(of: .healthInsurance) == Money(cents: 50_859))  // 5,812.50 × 8.75 %
        #expect(result.amount(of: .careInsurance) == Money(cents: 10_463))  // 5,812.50 × 1.8 %
        #expect(result.amount(of: .pensionInsurance) == Money(cents: 78_585))  // 8,450 × 9.3 %
    }

    @Test("Care insurance: Saxony, children and childless surcharge")
    func care() {
        let saxony = calculator.calculate(PayInput(gross: Money(units: 3000), region: "SN", isParent: true))
        #expect(saxony.amount(of: .careInsurance) == Money(units: 69))  // 2.3 %
        let threeKids = calculator.calculate(
            PayInput(gross: Money(units: 3000), childrenUnder25: 3, isParent: true))
        #expect(threeKids.amount(of: .careInsurance) == Money(units: 39))  // 1.8 − 2 × 0.25 = 1.3 %
    }

    @Test("Church tax: 8 % in Bavaria, 9 % elsewhere")
    func church() {
        let bavaria = calculator.calculate(
            PayInput(gross: Money(units: 4500), region: "BY", churchMember: true))
        let berlin = calculator.calculate(
            PayInput(gross: Money(units: 4500), region: "BE", churchMember: true))
        let tax = bavaria.amount(of: .incomeTax).cents
        #expect(bavaria.amount(of: .churchTax).cents == tax * 8 / 100)
        #expect(berlin.amount(of: .churchTax).cents == tax * 9 / 100)
    }

    @Test("Second job is taxed in class VI")
    func secondJob() {
        let second = calculator.calculate(PayInput(gross: Money(units: 800), employment: .secondary))
        let classSix = calculator.calculate(PayInput(gross: Money(units: 800), taxClass: 6))
        #expect(second.amount(of: .incomeTax) == classSix.amount(of: .incomeTax))
        #expect(second.amount(of: .incomeTax).cents > 0)
    }

    @Test("Mini job: only 3.6 % pension, or nothing when exempt")
    func miniJob() {
        #expect(
            calculator.calculate(PayInput(gross: Money(units: 240), employment: .mini)).net
                == Money(cents: 23_136))
        #expect(
            calculator.calculate(PayInput(gross: Money(units: 240), employment: .mini, pensionExempt: true))
                .net
                == Money(units: 240))
    }

    @Test("Transition zone reduces the employee contributions")
    func midiJob() {
        let result = calculator.calculate(PayInput(gross: Money(units: 1500)))
        // Base 2,000 / 1,397 × 897 = 1,284.18…
        #expect(result.amount(of: .pensionInsurance) == Money(cents: 11_943))
        let regular = calculator.calculate(PayInput(gross: Money(units: 2100)))
        #expect(regular.amount(of: .pensionInsurance) == Money(cents: 19_530))
    }

    @Test(
        "Transition zone matches the published 2026 formula 1.431639227 × pay − 863.2784538",
        arguments: [700, 900, 1200, 1500, 1999])
    func midiJobPublishedFormula(euros: Int) {
        let gross = Decimal(euros)
        let base = Decimal(string: "1.431639227")! * gross - Decimal(string: "863.2784538")!
        let result = calculator.calculate(PayInput(gross: Money(units: Int64(euros))))
        #expect(result.amount(of: .pensionInsurance) == Money(base * Decimal(string: "0.093")!))
        #expect(result.amount(of: .unemploymentInsurance) == Money(base * Decimal(string: "0.013")!))
    }

    @Test("Desired net: the smallest gross that reaches it")
    func desiredNet() throws {
        let result = try #require(
            calculator.grossNeeded(forNet: Money(cents: 205_442), PayInput(gross: .zero)))
        #expect(result.gross == Money(units: 3000))
        let one = try #require(
            calculator.grossNeeded(forNet: Money(units: 2500), PayInput(gross: .zero, taxClass: 3)))
        #expect(one.net >= Money(units: 2500))
        var less = PayInput(gross: one.gross - Money(cents: 1), taxClass: 3)
        less.gross = one.gross - Money(cents: 1)
        #expect(calculator.calculate(less).net < Money(units: 2500))
    }
}
