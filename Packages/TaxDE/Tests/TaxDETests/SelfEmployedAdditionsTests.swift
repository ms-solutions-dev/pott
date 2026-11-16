import Foundation
import PottCore
import Testing

@testable import TaxDE

/// VAT and the small business rule, artists' insurance, compulsory pension insurance, the basic
/// pension contract and the start-up grant, each against values worked out by hand from the 2026
/// rules (sources at the parameters in `GermanSelfEmployedCalculator`).
@Suite("Self-employed 2026: VAT, artists, pension, start-up grant")
struct SelfEmployedAdditionsTests {
    typealias Calc = GermanSelfEmployedCalculator
    let calculator = GermanSelfEmployedCalculator()

    @Test("Standard and half standard pension contribution are fixed amounts")
    func standardContribution() {
        let full = SelfEmployedInput(monthlyProfit: Money(units: 5000), pension: .standardContribution)
        #expect(calculator.calculate(full).monthly.amount(of: .pensionInsurance) == Money(cents: 73_563))
        // 3,955 × 18.6 % = 735.63, whatever the profit.
        let low = SelfEmployedInput(monthlyProfit: Money(units: 800), pension: .standardContribution)
        #expect(calculator.calculate(low).monthly.amount(of: .pensionInsurance) == Money(cents: 73_563))
        let half = SelfEmployedInput(monthlyProfit: Money(units: 5000), pension: .halfStandardContribution)
        // 1,977.50 × 18.6 % = 367.815 → 367.82.
        #expect(calculator.calculate(half).monthly.amount(of: .pensionInsurance) == Money(cents: 36_782))
        // Special expenses: 12 × (875 × 0.96 + 210) + 12 × 735.63 + 36 = 21,463.56;
        // 60,000 − 21,463.56 = 38,536.44 → 38,536.
        #expect(calculator.year(full).taxable == 38_536)
    }

    @Test("Artists' insurance: half of health, care and pension")
    func artists() {
        let input = SelfEmployedInput(monthlyProfit: Money(units: 3000), artistsInsurance: true)
        let result = calculator.calculate(input)
        // 3,000 × (14.6 + 2.9) % / 2 = 262.50
        #expect(result.monthly.amount(of: .healthInsurance) == Money(cents: 26_250))
        // 3,000 × (3.6 / 2 + 0.6 childless) % = 72.00
        #expect(result.monthly.amount(of: .careInsurance) == Money(units: 72))
        // 3,000 × 18.6 % / 2 = 279.00, even without choosing a pension
        #expect(result.monthly.amount(of: .pensionInsurance) == Money(units: 279))
        #expect(!result.belowArtistsMinimum)
        // 36,000 − (12 × 279 + 12 × (262.50 × 0.96 + 72) + 36) = 36,000 − 7,272 = 28,728
        let year = calculator.year(input)
        #expect(year.taxable == 28_728)
        // (173.10 × 1.0929 + 2,397) × 1.0929 + 1,034.87 = 3,861.31 → 3,861
        #expect(year.incomeTax == 3861)
    }

    @Test("Artists' insurance: minimum bases and the 3,900 € threshold")
    func artistsMinimum() {
        let low = calculator.calculate(
            SelfEmployedInput(monthlyProfit: Money(units: 400), artistsInsurance: true))
        // Health and care at least on 659.17: × 8.75 % = 57.677 → 57.68; × 2.4 % = 15.82
        #expect(low.monthly.amount(of: .healthInsurance) == Money(cents: 5768))
        #expect(low.monthly.amount(of: .careInsurance) == Money(cents: 1582))
        // Pension on the income, 400 is above the minimum of 325: × 9.3 % = 37.20
        #expect(low.monthly.amount(of: .pensionInsurance) == Money(cents: 3720))
        #expect(!low.belowArtistsMinimum)  // 4,800 a year
        let tiny = calculator.calculate(
            SelfEmployedInput(monthlyProfit: Money(units: 200), artistsInsurance: true))
        // 325 × 9.3 % = 30.225 → 30.23
        #expect(tiny.monthly.amount(of: .pensionInsurance) == Money(cents: 3023))
        #expect(tiny.belowArtistsMinimum)  // 2,400 a year
        let edge = calculator.calculate(
            SelfEmployedInput(monthlyProfit: Money(units: 325), artistsInsurance: true))
        #expect(edge.belowArtistsMinimum)  // exactly 3,900 does not exceed it
    }

    @Test("Artists with children: discount from the second child, no childless surcharge")
    func artistsChildren() {
        let input = SelfEmployedInput(
            monthlyProfit: Money(units: 3000), childrenUnder25: 3, isParent: true, artistsInsurance: true)
        // 3,000 × (1.8 − 2 × 0.25) % = 39.00
        #expect(calculator.calculate(input).monthly.amount(of: .careInsurance) == Money(units: 39))
    }

    @Test("Basic pension contract: own line, deductible up to the cap")
    func basicPension() {
        let input = SelfEmployedInput(monthlyProfit: Money(units: 5000), basicPension: Money(units: 500))
        let result = calculator.calculate(input)
        #expect(result.monthly.amount(of: .basicPension) == Money(units: 500))
        #expect(result.monthly.amount(of: .pensionInsurance) == .zero)
        // 47,364 (see SelfEmployedTests.freelancer) − 6,000
        #expect(calculator.year(input).taxable == 41_364)
        // Together with the standard contribution: 12 × (735.63 + 500) = 14,827.56 → 38,536 − 6,000
        var both = input
        both.pension = .standardContribution
        #expect(calculator.year(both).taxable == 32_536)
    }

    @Test("VAT on the revenue, passed on and not part of the profit")
    func vat() {
        var input = SelfEmployedInput(
            monthlyProfit: .zero, usesDayRate: true, dayRate: Money(units: 800), daysPerWeek: 5, daysOff: 40)
        // 800 × 220 / 12 = 14,666.67 a month; × 19 % = 2,786.67
        let result = calculator.calculate(input)
        #expect(result.monthlyVAT == Money(cents: 278_667))
        #expect(result.smallBusinessCheck == nil)
        #expect(result.monthly.gross == Money(cents: 1_466_667))
        input.vatRate = 7
        // 14,666.67 × 7 % = 1,026.6669 → 1,026.67
        #expect(calculator.calculate(input).monthlyVAT == Money(cents: 102_667))
    }

    @Test("Small business limits of § 19 UStG")
    func smallBusiness() {
        var input = SelfEmployedInput(
            monthlyProfit: Money(units: 1500), smallBusiness: true, previousYearRevenue: Money(units: 25_000))
        var result = calculator.calculate(input)
        #expect(result.smallBusinessCheck == .applies)  // 25,000 does not exceed the limit
        #expect(result.monthlyVAT == .zero)
        input.previousYearRevenue = Money(cents: 2_500_001)
        result = calculator.calculate(input)
        #expect(result.smallBusinessCheck == .previousYearTooHigh)
        #expect(result.monthlyVAT == Money(units: 285))  // 1,500 × 19 %
        input.previousYearRevenue = Money(units: 20_000)
        input.expectedRevenue = Money(units: 100_000)
        #expect(calculator.calculate(input).smallBusinessCheck == .applies)
        input.expectedRevenue = Money(cents: 10_000_001)
        #expect(calculator.calculate(input).smallBusinessCheck == .currentYearTooHigh)
        // Without an expected revenue it is estimated: (9,000 + 0) × 12 = 108,000 > 100,000
        input.expectedRevenue = .zero
        input.monthlyProfit = Money(units: 9000)
        #expect(calculator.calculate(input).smallBusinessCheck == .currentYearTooHigh)
    }

    @Test("Start-up grant: tax-free on top, phase one with the unemployment benefit")
    func startupGrant() {
        let plain = SelfEmployedInput(monthlyProfit: Money(units: 2000))
        var first = plain
        first.startupGrant = .first
        first.unemploymentBenefit = Money(units: 1500)
        let base = calculator.calculate(plain)
        let withGrant = calculator.calculate(first)
        #expect(withGrant.monthly.startupGrant == Money(units: 1800))  // 1,500 + 300
        #expect(withGrant.monthly.deductions == base.monthly.deductions)  // no tax, no contributions
        #expect(withGrant.monthly.net == base.monthly.net + Money(units: 1800))
        var second = first
        second.startupGrant = .second
        #expect(calculator.calculate(second).monthly.startupGrant == Money(units: 300))
    }

    @Test("Older saved inputs: an own pension amount becomes the basic pension contract")
    func legacyOwnAmount() throws {
        let json =
            #"{"monthlyProfit":{"cents":500000},"pension":"ownAmount","ownPensionAmount":{"cents":30000}}"#
        let input = try JSONDecoder().decode(SelfEmployedInput.self, from: Data(json.utf8))
        #expect(input.pension == SelfEmployedPension.none)
        #expect(input.basicPension == Money(units: 300))
        var full = SelfEmployedInput(
            monthlyProfit: Money(units: 4000), pension: .halfStandardContribution,
            basicPension: Money(units: 99),
            artistsInsurance: true, smallBusiness: true, vatRate: 7, previousYearRevenue: Money(units: 1),
            expectedRevenue: Money(units: 2), startupGrant: .second, unemploymentBenefit: Money(units: 3),
            healthInsurer: "BARMER")
        full.healthAdditionalRate = Decimal(string: "3.29")!
        let decoded = try JSONDecoder().decode(SelfEmployedInput.self, from: JSONEncoder().encode(full))
        #expect(decoded == full)
    }
}
