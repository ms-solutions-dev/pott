import Foundation
import PottCore
import Testing

@testable import TaxDE

/// The income tax tariff is checked against the PAP's own tariff routine (an independent source:
/// the BMF program flow chart rather than the law text this calculator follows), the rest against
/// values worked out by hand from the 2026 rules.
@Suite("Self-employed 2026")
struct SelfEmployedTests {
    typealias Calc = GermanSelfEmployedCalculator
    let calculator = GermanSelfEmployedCalculator()

    /// The PAP 2026 tariff (UPTAB26) for a taxable income in euros.
    static func papTariff(_ x: Int, joint: Bool) -> Decimal {
        var tax = Lohnsteuer2026()
        tax.MPARA()
        tax.KZTAB = joint ? 2 : 1
        tax.X = BigDecimal.valueOf(joint ? x / 2 : x)
        tax.UPTAB26()
        return Decimal(tax.ST.longValue())
    }

    @Test("Tariff equals the PAP tariff from 0 to 400,000 €, single and joint")
    func tariffMatchesPAP() {
        for x in stride(from: 0, through: 400_000, by: 97) {
            #expect(Calc.incomeTax(Decimal(x)) == Self.papTariff(x, joint: false), "single \(x)")
            #expect(Calc.incomeTax(Decimal(x), joint: true) == Self.papTariff(x, joint: true), "joint \(x)")
        }
        for x in [12_348, 12_349, 17_799, 17_800, 69_878, 69_879, 277_825, 277_826] {
            #expect(Calc.incomeTax(Decimal(x)) == Self.papTariff(x, joint: false), "edge \(x)")
        }
    }

    @Test("Tariff at known points")
    func tariffPoints() {
        #expect(Calc.incomeTax(12_348) == 0)
        #expect(Calc.incomeTax(100_000) == 30_864)  // 0.42 × 100,000 − 11,135.63
        #expect(Calc.incomeTax(300_000) == 115_529)  // 0.45 × 300,000 − 19,470.38
        #expect(Calc.incomeTax(100_000, joint: true) == 2 * Calc.incomeTax(50_000))
    }

    @Test("Solidarity surcharge: exemption, easing zone, full rate")
    func solidarity() {
        #expect(Calc.solidarity(20_350, exemption: 20_350) == 0)
        #expect(Calc.solidarity(21_000, exemption: 20_350) == Decimal(string: "77.35")!)  // 650 × 11.9 %
        #expect(Calc.solidarity(60_000, exemption: 20_350) == 3300)  // 5.5 %
    }

    @Test("Freelancer, €5,000 profit, statutory with sick pay")
    func freelancer() {
        let input = SelfEmployedInput(monthlyProfit: Money(units: 5000))
        let result = calculator.calculate(input)
        #expect(result.monthly.amount(of: .healthInsurance) == Money(units: 875))  // 5,000 × 17.5 %
        #expect(result.monthly.amount(of: .careInsurance) == Money(units: 210))  // 5,000 × 4.2 %
        let year = calculator.year(input)
        // 12 × (875 × 0.96 + 210) + 36 = 12,636 → 60,000 − 12,636 = 47,364
        #expect(year.taxable == 47_364)
        #expect(year.incomeTax == 9634)  // (173.10 × 2.9565 + 2,397) × 2.9565 + 1,034.87
        #expect(result.monthly.amount(of: .incomeTax) == Money(cents: 80_283))
        #expect(result.monthly.amount(of: .solidaritySurcharge) == .zero)
        #expect(result.monthly.net == Money(cents: 311_217))  // 5,000 − 802.83 − 875 − 210
        #expect(result.quarterlyTaxReserve == Money(cents: 240_850))
        #expect(!result.monthly.deductions.contains { $0.kind == .tradeTax })
    }

    @Test("Minimum base and ceiling of voluntary statutory insurance")
    func healthBases() {
        let low = calculator.calculate(SelfEmployedInput(monthlyProfit: Money(units: 800)))
        #expect(low.monthly.amount(of: .healthInsurance) == Money(cents: 23_071))  // 1,318.33 × 17.5 %
        let high = calculator.calculate(SelfEmployedInput(monthlyProfit: Money(units: 9000), isParent: true))
        #expect(high.monthly.amount(of: .healthInsurance) == Money(cents: 101_719))  // 5,812.50 × 17.5 %
        #expect(high.monthly.amount(of: .careInsurance) == Money(cents: 20_925))  // 5,812.50 × 3.6 %
        let noSickPay = calculator.calculate(
            SelfEmployedInput(monthlyProfit: Money(units: 5000), withSickPay: false))
        #expect(noSickPay.monthly.amount(of: .healthInsurance) == Money(units: 845))  // 5,000 × 16.9 %
    }

    @Test("Trade: trade tax and the credit against income tax")
    func trade() {
        let input = SelfEmployedInput(monthlyProfit: Money(units: 6000), isTrade: true, tradeTaxRate: 400)
        let year = calculator.year(input)
        // (72,000 − 24,500) × 3.5 % = 1,662.50 base; × 400 % = 6,650; credit min(4 × 1,662.50, 6,650, tax)
        #expect(year.tradeTax == 6650)
        #expect(year.tradeTaxCredit == 6650)
        // Health 1,017.19 + care 244.13 a month: 12 × (1,017.19 × 0.96 + 244.13) + 36 = 14,683.59
        #expect(year.taxable == 57_316)
        #expect(year.incomeTax == 13_210)
        let result = calculator.calculate(input)
        #expect(result.monthly.amount(of: .incomeTax) == Money(cents: 54_667))  // (13,210 − 6,650) / 12
        #expect(result.monthly.amount(of: .tradeTax) == Money(cents: 55_417))
        #expect(result.quarterlyTradeTax == Money(cents: 166_250))
        // A higher multiplier costs more, the credit stays at four times the base.
        let expensive = calculator.year(
            SelfEmployedInput(monthlyProfit: Money(units: 6000), isTrade: true, tradeTaxRate: 500))
        #expect(expensive.tradeTax == Decimal(string: "8312.5")!)
        #expect(expensive.tradeTaxCredit == 6650)
        // Below the allowance there is none.
        #expect(
            calculator.year(SelfEmployedInput(monthlyProfit: Money(units: 2000), isTrade: true)).tradeTax == 0
        )
    }

    @Test("Church tax ignores the trade tax credit, the surcharge does not")
    func churchAndCredit() {
        let input = SelfEmployedInput(
            monthlyProfit: Money(units: 20_000), isTrade: true, tradeTaxRate: 400, churchMember: true)
        let year = calculator.year(input)
        #expect(year.churchTax == year.incomeTax * 8 / 100)
        #expect(year.solidarity == Calc.solidarity(year.incomeTax - year.tradeTaxCredit, exemption: 20_350))
    }

    @Test("Statutory pension: 18.6 % within minimum and ceiling, deductible in full")
    func pension() {
        let input = SelfEmployedInput(monthlyProfit: Money(units: 5000), pension: .statutory)
        let result = calculator.calculate(input)
        #expect(result.monthly.amount(of: .pensionInsurance) == Money(units: 930))
        #expect(calculator.year(input).taxable == Decimal(36_204))  // 47,364 − 11,160
        let low = calculator.calculate(
            SelfEmployedInput(monthlyProfit: Money(units: 400), pension: .statutory))
        #expect(low.monthly.amount(of: .pensionInsurance) == Money(cents: 11_216))  // 603 × 18.6 %
        // An own contract counts only up to the cap of 30,826 € a year.
        let big = SelfEmployedInput(
            monthlyProfit: Money(units: 20_000), basicPension: Money(units: 3000))
        let plain = SelfEmployedInput(monthlyProfit: Money(units: 20_000))
        #expect(calculator.year(plain).taxable - calculator.year(big).taxable == 30_826)
    }

    @Test("Private insurance: premiums as one line, deductible in full")
    func privateInsurance() {
        let input = SelfEmployedInput(
            monthlyProfit: Money(units: 5000), health: .private, privateHealthPremium: Money(units: 500),
            privateCarePremium: Money(units: 50))
        let result = calculator.calculate(input)
        #expect(result.monthly.amount(of: .privateInsurance) == Money(units: 550))
        #expect(result.monthly.amount(of: .healthInsurance) == .zero)
        #expect(calculator.year(input).taxable == Decimal(53_364))  // 60,000 − 6,600 − 36
    }

    @Test("Married: splitting on both incomes, own share by taxable income")
    func married() {
        let input = SelfEmployedInput(
            monthlyProfit: Money(units: 5000), married: true, partnerTaxableIncome: Money(units: 30_000))
        let year = calculator.year(input)
        let total = Calc.incomeTax(47_364 + 30_000, joint: true)
        #expect(total == 13_590)  // 2 × T(38,682)
        #expect(year.incomeTax == Calc.floored(total * 47_364 / 77_364))
        #expect(year.incomeTax < 9634)  // cheaper than alone
    }

    @Test("Desired withdrawal finds the smallest profit")
    func profitNeeded() throws {
        let input = SelfEmployedInput(
            monthlyProfit: .zero, isTrade: true, churchMember: true, pension: .statutory)
        let found = try #require(calculator.profitNeeded(forNet: Money(units: 3000), input))
        #expect(found.monthly.net >= Money(units: 3000))
        var less = input
        less.monthlyProfit = found.monthly.gross - Money(cents: 1)
        #expect(calculator.calculate(less).monthly.net < Money(units: 3000))
    }

    @Test("Net rises with profit (needed for the desired withdrawal)")
    func monotonic() {
        var previous = Money(cents: Int64.min)
        for euros in stride(from: 0, through: 30_000, by: 250) {
            let input = SelfEmployedInput(
                monthlyProfit: Money(units: Int64(euros)), isTrade: true, tradeTaxRate: 900,
                churchMember: true,
                pension: .statutory)
            let net = calculator.calculate(input).monthly.net
            #expect(net >= previous, "\(euros)")
            previous = net
        }
    }
}
