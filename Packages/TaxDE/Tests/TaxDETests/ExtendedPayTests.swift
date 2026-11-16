import Foundation
import PottCore
import Testing

/// The app inputs behind the BMF scenarios in `bmf2026.json`. The PAP inputs there were derived by
/// hand from these, so a match checks the calculator's conversion as well as the tax code.
@testable import TaxDE

/// Social insurance has no official test interface; these values are worked out by hand from the
/// 2026 rates and ceilings (comments show the arithmetic).
enum Scenario {
    static let car45 = CompanyCar(listPrice: Money(units: 45_678), kind: .combustion, commuteKilometres: 15)
    static let ev60 = CompanyCar(
        listPrice: Money(units: 60_000), kind: .electric, commuteKilometres: 20, coPayment: Money(units: 50))

    static let inputs: [String: PayInput] = [
        "private": PayInput(
            gross: Money(units: 7000), privateInsurance: true, privateHealthPremium: Money(units: 600),
            privateCarePremium: Money(units: 60)),
        "civilServant": PayInput(
            gross: Money(units: 4200), status: .civilServant, privateHealthPremium: Money(units: 250),
            privateCarePremium: Money(units: 30)),
        "factor": PayInput(gross: Money(units: 4500), taxClass: 4, taxFactor: Decimal(string: "0.912")!),
        "pensioner": PayInput(gross: Money(units: 2500), status: .pensioner, birthYear: 1958),
        "notYetOld": PayInput(gross: Money(units: 2500), birthYear: 1962),
        "bonus": PayInput(
            gross: Money(units: 4500), churchMember: true, oneOffPayment: Money(units: 3000), oneOffMonth: 12),
        "pensionConversion": PayInput(gross: Money(units: 5000), pensionConversion: Money(units: 400)),
        "pensionConversionAboveLimit": PayInput(
            gross: Money(units: 5000), pensionConversion: Money(units: 800)),
        "combustionCar": PayInput(gross: Money(units: 4500), companyCar: car45),
        "electricCar": PayInput(gross: Money(units: 4500), companyCar: ev60),
        "expensiveElectricCar": PayInput(
            gross: Money(units: 4500),
            companyCar: CompanyCar(listPrice: Money(units: 120_000), kind: .electric, commuteKilometres: 10)),
        "hybridCar": PayInput(
            gross: Money(units: 4500), companyCar: CompanyCar(listPrice: Money(units: 55_555), kind: .hybrid)),
        "bike": PayInput(
            gross: Money(units: 3500),
            companyBike: CompanyBike(listPrice: Money(units: 3999), leasingRate: Money(units: 90))),
        "pensionBenefit": PayInput(
            gross: Money(units: 2000), status: .pensioner, birthYear: 1955,
            pensionBenefit: Money(units: 2000),
            pensionBenefitStartYear: 2020),
        "civilServantPension": PayInput(
            gross: Money(units: 3500), status: .civilServant, privateHealthPremium: Money(units: 300),
            privateCarePremium: Money(units: 40), pensionBenefit: Money(units: 3500),
            pensionBenefitStartYear: 2015),
        "allowance": PayInput(gross: Money(units: 4500), monthlyAllowance: Money(units: 300)),
    ]
}
@Suite("Pay calculator scenarios against BMF")
struct ScenarioTests {
    let calculator = GermanPayCalculator()

    @Test("Every scenario has an app input")
    func complete() {
        #expect(Set(BMFFixture.file.scenarios.keys) == Set(Scenario.inputs.keys))
    }

    @Test("Wage tax of the app matches the BMF", arguments: Array(Scenario.inputs.keys).sorted())
    func matches(name: String) throws {
        let fixture = try #require(BMFFixture.file.scenarios[name])
        let input = try #require(Scenario.inputs[name])
        let result = calculator.calculate(input)
        let out = fixture.output
        #expect(result.amount(of: .incomeTax).cents == Int64(out["LSTLZZ"] ?? -1), "\(name) wage tax")
        #expect(result.amount(of: .solidaritySurcharge).cents == Int64(out["SOLZLZZ"] ?? -1), "\(name) soli")
        let church = input.churchMember ? Int64(out["BK"] ?? 0) * 8 / 100 : 0
        #expect(result.amount(of: .churchTax).cents == church, "\(name) church")
        if input.oneOffPayment > .zero {
            let oneOff = try #require(result.oneOff)
            #expect(oneOff.amount(of: .incomeTax).cents == Int64(out["STS"] ?? -1), "\(name) one-off tax")
            #expect(oneOff.amount(of: .solidaritySurcharge).cents == Int64(out["SOLZS"] ?? -1))
            #expect(oneOff.amount(of: .churchTax).cents == Int64(out["BKS"] ?? 0) * 8 / 100)
        }
    }

    @Test("The taxable gross is the one derived by hand", arguments: Array(Scenario.inputs.keys).sorted())
    func taxableGross(name: String) throws {
        let fixture = try #require(BMFFixture.file.scenarios[name])
        let input = try #require(Scenario.inputs[name])
        let bases = GermanPayCalculator.bases(input, .year2026)
        #expect(String(bases.taxable.cents) == fixture.input["RE4"], "\(name)")
    }
}
@Suite("Social insurance for the extended cases")
struct ExtendedContributionTests {
    let calculator = GermanPayCalculator()

    @Test("Private insurance: half the premiums as subsidy, no statutory health or care lines")
    func privateInsurance() throws {
        let result = calculator.calculate(try #require(Scenario.inputs["private"]))
        #expect(result.amount(of: .privateInsurance) == Money(units: 330))  // 660 − (300 + 30)
        #expect(result.amount(of: .healthInsurance) == .zero)
        #expect(result.amount(of: .careInsurance) == .zero)
        #expect(result.amount(of: .pensionInsurance) == Money(units: 651))  // 7,000 × 9.3 %
        #expect(result.amount(of: .unemploymentInsurance) == Money(units: 91))  // 7,000 × 1.3 %
        #expect(!result.deductions.contains { $0.kind == .healthInsurance })
    }

    @Test("Private insurance: the subsidy is capped, lower for care in Saxony")
    func subsidyCap() {
        var input = PayInput(
            gross: Money(units: 8000), privateInsurance: true, privateHealthPremium: Money(units: 1200),
            privateCarePremium: Money(units: 250))
        // 508.59 (5,812.50 × 8.75 %) + 104.63 (5,812.50 × 1.8 %) = 613.22
        #expect(calculator.calculate(input).amount(of: .privateInsurance) == Money(cents: 145_000 - 61_322))
        input.region = "SN"
        // 508.59 + 75.56 (5,812.50 × 1.3 %) = 584.15
        #expect(calculator.calculate(input).amount(of: .privateInsurance) == Money(cents: 145_000 - 58_415))
    }

    @Test("Civil servants: only their own private premium, no social insurance")
    func civilServant() throws {
        let result = calculator.calculate(try #require(Scenario.inputs["civilServant"]))
        let contributions = result.deductions.filter {
            ![.incomeTax, .solidaritySurcharge, .churchTax].contains($0.kind)
        }
        #expect(contributions == [Deduction(.privateInsurance, Money(units: 280))])
    }

    @Test("Full pensioners: reduced health rate, no pension or unemployment contribution")
    func pensioner() throws {
        let result = calculator.calculate(try #require(Scenario.inputs["pensioner"]))
        #expect(result.amount(of: .healthInsurance) == Money(cents: 21_125))  // 2,500 × (7.0 + 1.45) %
        #expect(result.amount(of: .careInsurance) == Money(units: 60))  // 2,500 × 2.4 %
        #expect(!result.deductions.contains { $0.kind == .pensionInsurance })
        #expect(!result.deductions.contains { $0.kind == .unemploymentInsurance })
    }

    @Test("Factor method only applies in class IV")
    func factorOnlyClassFour() {
        let factor = Decimal(string: "0.912")!
        let one = calculator.calculate(PayInput(gross: Money(units: 4500), taxFactor: factor))
        let plain = calculator.calculate(PayInput(gross: Money(units: 4500)))
        #expect(one.amount(of: .incomeTax) == plain.amount(of: .incomeTax))
        let four = calculator.calculate(PayInput(gross: Money(units: 4500), taxClass: 4, taxFactor: factor))
        let fourPlain = calculator.calculate(PayInput(gross: Money(units: 4500), taxClass: 4))
        #expect(four.amount(of: .incomeTax) < fourPlain.amount(of: .incomeTax))
    }

    @Test("Company pension: contribution-free up to 338, tax-free up to 676, paid out of the gross")
    func pensionConversion() throws {
        let p = GermanPayCalculator.Parameters.year2026
        let small = GermanPayCalculator.bases(try #require(Scenario.inputs["pensionConversion"]), p)
        #expect(small.contributable == Money(units: 4662))
        #expect(small.taxable == Money(units: 4600))
        let large = GermanPayCalculator.bases(try #require(Scenario.inputs["pensionConversionAboveLimit"]), p)
        #expect(large.contributable == Money(units: 4662))
        #expect(large.taxable == Money(units: 4324))
        let result = calculator.calculate(try #require(Scenario.inputs["pensionConversionAboveLimit"]))
        #expect(result.amount(of: .companyPension) == Money(units: 800))
        #expect(result.net == result.gross - result.deductions.map(\.amount).sum())
    }

    @Test("Company car: benefit raises taxes and contributions but is not paid out")
    func companyCar() throws {
        let input = try #require(Scenario.inputs["electricCar"])
        let bases = GermanPayCalculator.bases(input, .year2026)
        #expect(bases.benefit == Money(units: 190))  // 150 + 90 − 50
        #expect(bases.contributable == Money(units: 4690))
        let result = calculator.calculate(input)
        #expect(result.gross == Money(units: 4500))
        #expect(result.taxableBenefit == Money(units: 190))
        #expect(result.amount(of: .carCoPayment) == Money(units: 50))
        #expect(result.amount(of: .pensionInsurance) == Money(cents: 43_617))  // 4,690 × 9.3 %
        let without = calculator.calculate(PayInput(gross: Money(units: 4500)))
        #expect(result.net < without.net)
    }

    @Test("Electric cars: a quarter up to 100,000, half above; co-payment never below zero")
    func electricLimit() {
        let p = GermanPayCalculator.Parameters.year2026
        let atLimit = CompanyCar(listPrice: Money(units: 100_000), kind: .electric)
        #expect(GermanPayCalculator.carBenefit(atLimit, p) == Money(units: 250))
        let above = CompanyCar(listPrice: Money(units: 100_100), kind: .electric)
        #expect(GermanPayCalculator.carBenefit(above, p) == Money(cents: 50_050))
        let paidOff = CompanyCar(listPrice: Money(units: 30_000), coPayment: Money(units: 500))
        #expect(GermanPayCalculator.carBenefit(paidOff, p) == .zero)
    }

    @Test("Company bike: only salary conversion is taxed")
    func bike() throws {
        let bases = GermanPayCalculator.bases(try #require(Scenario.inputs["bike"]), .year2026)
        #expect(bases.benefit == Money(cents: 975))
        #expect(bases.contributable == Money(cents: 341_975))
        #expect(bases.ownPayments == [Deduction(.bikeLeasing, Money(units: 90))])
        let gift = PayInput(
            gross: Money(units: 3500),
            companyBike: CompanyBike(listPrice: Money(units: 3999), leasingRate: .zero))
        #expect(GermanPayCalculator.bases(gift, .year2026).benefit == .zero)
    }

    @Test("One-off payment below the ceiling: full contributions")
    func bonusContributions() throws {
        let result = calculator.calculate(try #require(Scenario.inputs["bonus"]))
        let oneOff = try #require(result.oneOff)
        #expect(oneOff.amount(of: .healthInsurance) == Money(cents: 26_250))  // 3,000 × 8.75 %
        #expect(oneOff.amount(of: .careInsurance) == Money(units: 72))  // 3,000 × 2.4 %
        #expect(oneOff.amount(of: .pensionInsurance) == Money(units: 279))
        #expect(oneOff.amount(of: .unemploymentInsurance) == Money(units: 39))
        // The month itself is unchanged by the bonus.
        var plain = try #require(Scenario.inputs["bonus"])
        plain.oneOffPayment = .zero
        #expect(calculator.calculate(plain).deductions == result.deductions)
    }

    @Test("One-off payment in December: health only up to the unused yearly ceiling")
    func bonusAboveCeiling() throws {
        let input = PayInput(
            gross: Money(cents: 549_250), oneOffPayment: Money(units: 10_000), oneOffMonth: 12)
        let oneOff = try #require(calculator.calculate(input).oneOff)
        // Room 12 × (5,812.50 − 5,492.50) = 3,840.
        #expect(oneOff.amount(of: .healthInsurance) == Money(units: 336))  // 3,840 × 8.75 %
        #expect(oneOff.amount(of: .careInsurance) == Money(cents: 9216))  // 3,840 × 2.4 %
        #expect(oneOff.amount(of: .pensionInsurance) == Money(units: 930))  // room 35,490 > 10,000
        #expect(oneOff.amount(of: .unemploymentInsurance) == Money(units: 130))
    }

    @Test("March clause: early payments beyond the room count for last December")
    func marchClause() throws {
        let input = PayInput(gross: Money(cents: 546_250), oneOffPayment: Money(units: 2000), oneOffMonth: 2)
        let oneOff = try #require(calculator.calculate(input).oneOff)
        // February room 2 × 350 = 700 < 2,000 → 2025: 12 × (5,512.50 − 5,462.50) = 600.
        #expect(oneOff.amount(of: .healthInsurance) == Money(cents: 5250))  // 600 × 8.75 %
        #expect(oneOff.amount(of: .careInsurance) == Money(cents: 1440))  // 600 × 2.4 %
        #expect(oneOff.amount(of: .pensionInsurance) == Money(units: 186))  // 2025 room 31,050
        #expect(oneOff.amount(of: .unemploymentInsurance) == Money(units: 26))
        // Inside the room, the clause does not apply.
        let small = PayInput(gross: Money(cents: 546_250), oneOffPayment: Money(units: 500), oneOffMonth: 2)
        let smallOneOff = try #require(calculator.calculate(small).oneOff)
        #expect(smallOneOff.amount(of: .healthInsurance) == Money(cents: 4375))  // 500 × 8.75 %
    }

    @Test("Civil servants pay no contributions on a one-off payment")
    func civilServantBonus() throws {
        var input = try #require(Scenario.inputs["civilServant"])
        input.oneOffPayment = Money(units: 2000)
        let oneOff = try #require(calculator.calculate(input).oneOff)
        #expect(
            oneOff.deductions.allSatisfy { [.incomeTax, .solidaritySurcharge, .churchTax].contains($0.kind) })
    }

    @Test("Desired net still works with the new deductions")
    func desiredNet() throws {
        let input = try #require(Scenario.inputs["private"])
        let found = try #require(calculator.grossNeeded(forNet: Money(units: 4000), input))
        #expect(found.net >= Money(units: 4000))
        var less = input
        less.gross = found.gross - Money(cents: 1)
        #expect(calculator.calculate(less).net < Money(units: 4000))
    }

    @Test("Inputs saved before these fields existed still load")
    func oldSavedInput() throws {
        let old =
            #"{"gross":{"cents":300000},"employment":"main","taxClass":3,"region":"SN","churchMember":true,"#
            + #""childAllowances":1,"childrenUnder25":1,"isParent":true,"healthAdditionalRate":2.5,"#
            + #""pensionExempt":false,"year":2026}"#
        let input = try JSONDecoder().decode(PayInput.self, from: Data(old.utf8))
        #expect(input.taxClass == 3)
        #expect(input.region == "SN")
        #expect(input.status == .employee)
        #expect(input.companyCar == nil)
        #expect(input.oneOffMonth == 12)
        let roundTrip = try JSONDecoder().decode(
            PayInput.self, from: JSONEncoder().encode(Scenario.inputs["bonus"]))
        #expect(roundTrip == Scenario.inputs["bonus"])
    }
}
