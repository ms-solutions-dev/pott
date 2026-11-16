import Foundation
import PottCore
import Testing

@testable import TaxDE

/// The official short-time work table of the Federal Employment Agency, valid from January 2026
/// (kug050-2026), read from its PDF: per rounded gross the rate with child (67 %, "Leistungssatz 1")
/// and without (60 %), columns: no tax, I/IV, II, III, V, VI.
enum KugTable {
    struct Row: Decodable {
        var gross: Int
        var rate1: [Double]
        var rate2: [Double]
    }

    struct File: Decodable { var rows: [Row] }

    static let rows: [Row] = {
        guard
            let url = Bundle.module.url(
                forResource: "kug2026", withExtension: "json", subdirectory: "Fixtures"),
            let data = try? Data(contentsOf: url),
            let file = try? JSONDecoder().decode(File.self, from: data)
        else { return [] }
        return file.rows
    }()

    static func cents(_ value: Double) -> Int64 { Int64((value * 100).rounded()) }
}

@Suite("Short-time work against the official 2026 table")
struct ShortTimeWorkTests {
    @Test("Table is present up to the ceiling")
    func present() {
        #expect(KugTable.rows.count == 423)
        #expect(KugTable.rows.last?.gross == 8460)
    }

    @Test("Every rate of every tax class matches the table", arguments: [1, 2, 3, 4, 5, 6])
    func everyRate(taxClass: Int) {
        let column = [1: 1, 2: 2, 3: 3, 4: 1, 5: 4, 6: 5][taxClass]!
        var misses = 0
        for row in KugTable.rows {
            let gross = Money(units: Int64(row.gross))
            let withChild = GermanPayCalculator.shortTimeRate(
                gross: gross, taxClass: taxClass, withChild: true)
            let without = GermanPayCalculator.shortTimeRate(
                gross: gross, taxClass: taxClass, withChild: false)
            if withChild.cents != KugTable.cents(row.rate1[column])
                || without.cents != KugTable.cents(row.rate2[column])
            {
                misses += 1
                if misses <= 3 {
                    Issue.record("class \(taxClass) gross \(row.gross): \(withChild) / \(without)")
                }
            }
        }
        #expect(misses == 0)
    }

    @Test("The table's own example: class III with child, 2,500 → 1,250 gives 664.64")
    func example() {
        let input = PayInput(
            gross: Money(units: 2500), taxClass: 3, childAllowances: 1, shortTimeGross: Money(units: 1250))
        let allowance = GermanPayCalculator().shortTimeAllowance(
            planned: input.gross, actual: Money(units: 1250), input)
        #expect(allowance == Money(cents: 66_464))
    }

    @Test("Gross is rounded to 20 and capped at the pension ceiling")
    func rounding() {
        let rate = { GermanPayCalculator.shortTimeRate(gross: $0, taxClass: 1, withChild: false) }
        #expect(rate(Money(cents: 249_000)) == rate(Money(cents: 250_999)))  // both → 2,500
        #expect(rate(Money(cents: 251_000)) != rate(Money(units: 2500)))  // → 2,520
        #expect(rate(Money(units: 12_000)) == rate(Money(units: 8450)))
        #expect(rate(.zero) == .zero)
    }

    @Test("A month of short-time work: pay on the actual gross plus the tax-free allowance")
    func month() {
        let calculator = GermanPayCalculator()
        let input = PayInput(gross: Money(units: 3000), shortTimeGross: Money(units: 1500))
        let result = calculator.calculate(input)
        let actual = calculator.calculate(PayInput(gross: Money(units: 1500)))
        #expect(result.gross == Money(units: 1500))
        #expect(result.deductions == actual.deductions)
        let expected =
            GermanPayCalculator.shortTimeRate(gross: Money(units: 3000), taxClass: 1, withChild: false)
            - GermanPayCalculator.shortTimeRate(gross: Money(units: 1500), taxClass: 1, withChild: false)
        #expect(result.shortTimeAllowance == expected)
        #expect(result.net == actual.net + expected)
        // Without work at all, the allowance is the whole rate of the usual gross.
        let zero = calculator.calculate(PayInput(gross: Money(units: 3000), shortTimeGross: .zero))
        #expect(
            zero.shortTimeAllowance
                == GermanPayCalculator.shortTimeRate(gross: Money(units: 3000), taxClass: 1, withChild: false)
        )
    }
}

@Suite("Pensions from a former employer")
struct PensionBenefitTests {
    let calculator = GermanPayCalculator()

    @Test("Company pension: full health rate above 197.75, full care rate, nothing else")
    func companyPension() throws {
        let result = calculator.calculate(try #require(Scenario.inputs["pensionBenefit"]))
        #expect(result.amount(of: .healthInsurance) == Money(cents: 31_539))  // (2,000 − 197.75) × 17.5 %
        #expect(result.amount(of: .careInsurance) == Money(units: 84))  // 2,000 × 4.2 %
        #expect(result.amount(of: .pensionInsurance) == .zero)
        #expect(result.amount(of: .unemploymentInsurance) == .zero)
    }

    @Test("Below the limit no health or care contribution")
    func small() {
        let result = calculator.calculate(
            PayInput(gross: Money(units: 190), status: .pensioner, pensionBenefit: Money(units: 190)))
        #expect(result.amount(of: .healthInsurance) == .zero)
        #expect(result.amount(of: .careInsurance) == .zero)
    }

    @Test("Civil-servant pension: only the private premium")
    func civilServant() throws {
        let result = calculator.calculate(try #require(Scenario.inputs["civilServantPension"]))
        let contributions = result.deductions.filter {
            ![.incomeTax, .solidaritySurcharge, .churchTax].contains($0.kind)
        }
        #expect(contributions == [Deduction(.privateInsurance, Money(units: 340))])
    }

    @Test("Pension and wage together: each part with its own rules")
    func mixed() {
        let result = calculator.calculate(
            PayInput(
                gross: Money(units: 3000), pensionBenefit: Money(units: 1000), pensionBenefitStartYear: 2022))
        // Wage 2,000: 8.75 % health, 2.4 % care, 9.3 % pension, 1.3 % unemployment.
        // Pension 1,000: (1,000 − 197.75) × 17.5 % health, 1,000 × 4.2 % care.
        #expect(result.amount(of: .healthInsurance) == Money(units: 175) + Money(cents: 14_039))
        #expect(result.amount(of: .careInsurance) == Money(units: 48) + Money(units: 42))
        #expect(result.amount(of: .pensionInsurance) == Money(units: 186))
        #expect(result.amount(of: .unemploymentInsurance) == Money(units: 26))
    }
}

@Suite("One-off payment in a midijob")
struct MidiJobBonusTests {
    let calculator = GermanPayCalculator()

    @Test("Contributions are the difference of the month with and without the payment")
    func difference() throws {
        let bonus = try #require(
            calculator.calculate(PayInput(gross: Money(units: 1500), oneOffPayment: Money(units: 400))).oneOff
        )
        let with = calculator.calculate(PayInput(gross: Money(units: 1900)))
        let without = calculator.calculate(PayInput(gross: Money(units: 1500)))
        for kind in [
            Deduction.Kind.healthInsurance, .careInsurance, .pensionInsurance, .unemploymentInsurance,
        ] {
            #expect(bonus.amount(of: kind) == with.amount(of: kind) - without.amount(of: kind), "\(kind)")
        }
        // 2,000 / 1,397 × (1,900 − 603) × 8.75 % − 2,000 / 1,397 × (1,500 − 603) × 8.75 %
        #expect(bonus.amount(of: .healthInsurance) == Money(cents: 16_247 - 11_237))
    }

    @Test("A payment that lifts the month above 2,000 pays the full rate on the whole month")
    func aboveZone() throws {
        let bonus = try #require(
            calculator.calculate(PayInput(gross: Money(units: 1800), oneOffPayment: Money(units: 1000)))
                .oneOff)
        let without = calculator.calculate(PayInput(gross: Money(units: 1800)))
        #expect(
            bonus.amount(of: .pensionInsurance) == Money(cents: 26_040)
                - without.amount(of: .pensionInsurance))  // 2,800 × 9.3 %
    }
}

@Suite("Self-employed: day rate, side business, child allowances")
struct SelfEmployedExtrasTests {
    typealias Calc = GermanSelfEmployedCalculator
    let calculator = GermanSelfEmployedCalculator()

    @Test("Day rate: 52 weeks × days minus days off, minus costs")
    func dayRate() throws {
        let input = SelfEmployedInput(
            monthlyProfit: .zero, usesDayRate: true, dayRate: Money(units: 800), daysPerWeek: 5, daysOff: 40,
            businessCosts: Money(units: 500))
        #expect(input.billableDays == 220)
        #expect(input.effectiveMonthlyProfit == Money(cents: 1_416_667))  // 800 × 220 / 12 − 500
        #expect(
            try #require(input.dayRate(forMonthlyProfit: input.effectiveMonthlyProfit)) == Money(units: 800))
        var four = input
        four.daysPerWeek = 4
        #expect(four.billableDays == 168)
        let result = calculator.calculate(input)
        #expect(result.monthly.gross == input.effectiveMonthlyProfit)
        // The same as entering that profit directly.
        let direct = calculator.calculate(
            SelfEmployedInput(monthlyProfit: input.effectiveMonthlyProfit, businessCosts: Money(units: 500)))
        #expect(result.monthly.deductions == direct.monthly.deductions)
    }

    @Test("Taxable salary next to a side business")
    func salaryTaxable() {
        let salary = PayInput(gross: Money(units: 4000))
        // 48,000 − 1,230 − 12 × (372 + 350 × 0.96 + 96) − 36 = 37,086
        #expect(Calc.salaryTaxable(salary) == 37_086)
        #expect(Calc.salaryTaxable(PayInput(gross: Money(units: 500), employment: .mini)) == 0)
    }

    @Test("Side business: taxed on top of the salary, no own health insurance")
    func sideline() {
        let input = SelfEmployedInput(monthlyProfit: Money(units: 1000), sideline: true)
        let salary = PayInput(gross: Money(units: 4000))
        let year = calculator.year(input, salary: salary)
        #expect(year.taxable == 12_000)
        #expect(year.incomeTax == Calc.incomeTax(49_086) - Calc.incomeTax(37_086))
        let result = calculator.calculate(input, salary: salary)
        #expect(result.monthly.amount(of: .healthInsurance) == .zero)
        #expect(!result.monthly.deductions.contains { $0.kind == .careInsurance })
        // Higher than the same profit alone, because it sits on top of the salary.
        let alone = calculator.year(SelfEmployedInput(monthlyProfit: Money(units: 1000), health: .private))
        #expect(year.incomeTax > alone.incomeTax)
    }

    @Test("Child benefit check: allowances only when they save more than the benefit")
    func childBenefitCheck() {
        // Single, one child: allowance 4,878 against half the benefit, 1,554.
        let low = Calc.assessed(30_000, joint: false, children: 1)
        #expect(low.tax == Calc.incomeTax(30_000))  // saving below 1,554 → benefit
        #expect(low.annexBase == Calc.incomeTax(30_000 - 4878))
        let high = Calc.assessed(150_000, joint: false, children: 1)
        #expect(high.tax == Calc.incomeTax(150_000 - 4878) + 1554)  // 42 % × 4,878 > 1,554
        // Married, two children: 19,512 against 6,216.
        let joint = Calc.assessed(200_000, joint: true, children: 2)
        #expect(joint.tax == Calc.incomeTax(200_000 - 19_512, joint: true) + 6216)
    }

    @Test("Children lower the church tax even when the benefit is kept")
    func churchWithChildren() {
        let without = calculator.year(
            SelfEmployedInput(monthlyProfit: Money(units: 4000), churchMember: true))
        let with = calculator.year(
            SelfEmployedInput(
                monthlyProfit: Money(units: 4000), churchMember: true, childrenUnder25: 1, isParent: true))
        #expect(with.churchTax < without.churchTax)
    }

    @Test("Saved inputs from before the day rate still load")
    func oldSavedInput() throws {
        let old =
            #"{"monthlyProfit":{"cents":500000},"isTrade":true,"tradeTaxRate":450,"region":"BY","churchMember":false,"married":false,"partnerTaxableIncome":{"cents":0},"childrenUnder25":0,"isParent":false,"health":"statutory","withSickPay":true,"healthAdditionalRate":2.9,"privateHealthPremium":{"cents":0},"privateCarePremium":{"cents":0},"pension":"none","ownPensionAmount":{"cents":0},"year":2026}"#
        let input = try JSONDecoder().decode(SelfEmployedInput.self, from: Data(old.utf8))
        #expect(input.tradeTaxRate == 450)
        #expect(!input.usesDayRate)
        #expect(input.daysPerWeek == 5)
    }
}
