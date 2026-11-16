import Foundation
/// German gross-to-net pay: wage tax, solidarity surcharge and church tax from the BMF program
/// flow chart, social insurance from the yearly contribution parameters.
import PottCore

public struct GermanPayCalculator: NetPayCalculator {
    public init() {}

    public var supportedYears: [Int] { [2026] }

    /// Contribution parameters of one year (monthly values, rates in percent).
    struct Parameters {
        var healthCeiling: Money
        var pensionCeiling: Money
        /// Ceilings of the year before, for one-off payments in January to March (§ 23a (4) SGB IV).
        var previousHealthCeiling: Money
        var previousPensionCeiling: Money
        var miniJobLimit: Money
        var midiJobLimit: Money
        var healthGeneralRate: Decimal
        /// General rate without sick pay, for people drawing a full old-age pension.
        var healthReducedRate: Decimal
        /// Average additional contribution, which caps the employer subsidy for private cover.
        var averageAdditionalRate: Decimal
        var careRate: Decimal
        var careEmployeeSaxony: Decimal
        var careChildlessSurcharge: Decimal
        var careChildDiscount: Decimal
        var pensionRate: Decimal
        var unemploymentRate: Decimal
        var miniJobPensionEmployee: Decimal
        /// Company pension by salary conversion: tax-free up to 8 %, contribution-free up to 4 %
        /// of the pension ceiling (§ 3 No. 63 EStG, § 1 (1) No. 9 SvEV).
        var pensionConversionTaxFree: Money
        var pensionConversionContributionFree: Money
        /// Battery electric company cars up to this list price count with a quarter.
        var electricCarPriceLimit: Money

        /// Allowance for health insurance on pensions from a former employer, and exemption limit
        /// for care insurance: 1/20 of the reference value (3,955 / 20).
        var pensionBenefitAllowance: Money = Money(Decimal(string: "197.75")!)

        /// 2026: Sozialversicherungs-Rechengrößenverordnung 2026, PAP 2026, § 6 (1) No. 4 EStG.
        static let year2026 = Parameters(
            healthCeiling: Money(Decimal(string: "5812.50")!), pensionCeiling: Money(units: 8450),
            previousHealthCeiling: Money(Decimal(string: "5512.50")!),
            previousPensionCeiling: Money(units: 8050),
            miniJobLimit: Money(units: 603), midiJobLimit: Money(units: 2000),
            healthGeneralRate: Decimal(string: "14.6")!, healthReducedRate: Decimal(string: "14.0")!,
            averageAdditionalRate: Decimal(string: "2.9")!, careRate: Decimal(string: "3.6")!,
            careEmployeeSaxony: Decimal(string: "2.3")!, careChildlessSurcharge: Decimal(string: "0.6")!,
            careChildDiscount: Decimal(string: "0.25")!, pensionRate: Decimal(string: "18.6")!,
            unemploymentRate: Decimal(string: "2.6")!, miniJobPensionEmployee: Decimal(string: "3.6")!,
            pensionConversionTaxFree: Money(units: 676), pensionConversionContributionFree: Money(units: 338),
            electricCarPriceLimit: Money(units: 100_000))
    }

    /// Church tax rate in percent by state.
    static func churchRate(_ region: String) -> Int64 {
        ["BY", "BW"].contains(region) ? 8 : 9
    }

    /// The month's bases: what is taxed, what social insurance is charged on, and what the
    /// employee pays out of the gross besides taxes and contributions.
    struct Bases: Equatable {
        var taxable: Money
        var contributable: Money
        var benefit: Money
        var ownPayments: [Deduction]
    }

    static func bases(_ input: PayInput, _ p: Parameters) -> Bases {
        let carBenefit = input.companyCar.map { carBenefit($0, p) } ?? .zero
        let bikeRate = input.companyBike?.leasingRate ?? .zero
        // A bike given on top of the salary is tax-free (§ 3 No. 37 EStG); only salary conversion is taxed.
        let bikeBenefit =
            input.companyBike.map {
                bikeRate > .zero ? roundedList($0.listPrice) * Decimal(string: "0.0025")! : .zero
            } ?? .zero
        let conversion = max(input.pensionConversion, .zero)
        let benefit = carBenefit + bikeBenefit
        var own: [Deduction] = []
        if conversion > .zero { own.append(Deduction(.companyPension, conversion)) }
        if bikeRate > .zero { own.append(Deduction(.bikeLeasing, bikeRate)) }
        if let car = input.companyCar, car.coPayment > .zero {
            own.append(Deduction(.carCoPayment, car.coPayment))
        }
        return Bases(
            taxable: max(
                .zero, input.gross - min(conversion, p.pensionConversionTaxFree) - bikeRate + benefit),
            contributable: max(
                .zero, input.gross - min(conversion, p.pensionConversionContributionFree) - bikeRate + benefit
            ),
            benefit: benefit, ownPayments: own)
    }

    /// List prices are rounded down to full hundreds.
    static func roundedList(_ price: Money) -> Money {
        Money(cents: max(0, price.cents) / 10_000 * 10_000)
    }

    /// Monthly value of the private use: 1 % of the (reduced) list price plus 0.03 % per
    /// kilometre to work, minus the employee's own payment, never below zero.
    static func carBenefit(_ car: CompanyCar, _ p: Parameters) -> Money {
        let price = roundedList(car.listPrice).decimal
        let share: Decimal =
            switch car.kind {
            case .combustion: 1
            case .hybrid: Decimal(string: "0.5")!
            case .electric:
                car.listPrice <= p.electricCarPriceLimit ? Decimal(string: "0.25")! : Decimal(string: "0.5")!
            }
        let base = price * share
        let value = base / 100 + base * Decimal(string: "0.0003")! * Decimal(max(0, car.commuteKilometres))
        return max(.zero, Money(value) - car.coPayment)
    }

    public func calculate(_ input: PayInput) -> PayResult {
        if let actual = input.shortTimeGross, input.employment == .main, actual < input.gross {
            var month = input
            month.gross = actual
            month.shortTimeGross = nil
            var result = calculate(month)
            result.shortTimeAllowance = shortTimeAllowance(planned: input.gross, actual: actual, input)
            return result
        }
        let p = Parameters.year2026
        if input.employment == .mini && input.gross <= p.miniJobLimit {
            // The employer pays a flat tax; the employee only tops up the pension contribution.
            let pension = input.pensionExempt ? Money.zero : input.gross * (p.miniJobPensionEmployee / 100)
            return PayResult(gross: input.gross, deductions: [Deduction(.pensionInsurance, pension)])
        }
        let bases = Self.bases(input, p)
        let tax = wageTax(input, bases)
        let oneOff = input.oneOffPayment > .zero ? oneOffPay(input, bases, tax, p) : nil
        return PayResult(
            gross: input.gross,
            deductions: taxes(tax.regular, input) + socialInsurance(input, bases.contributable, p)
                + bases.ownPayments,
            taxableBenefit: bases.benefit, oneOff: oneOff)
    }

    /// Wage tax, solidarity surcharge and church tax base, for the month and for a one-off payment.
    struct TaxAmounts {
        var tax: Money
        var solidarity: Money
        var churchBase: Money
    }

    func wageTax(_ input: PayInput, _ bases: Bases) -> (regular: TaxAmounts, oneOff: TaxAmounts) {
        let p = Parameters.year2026
        var tax = Lohnsteuer2026()
        tax.LZZ = 2
        tax.RE4 = BigDecimal.valueOf(Int(bases.taxable.cents))
        tax.STKL = input.employment == .secondary ? 6 : min(max(input.taxClass, 1), 6)
        if tax.STKL == 4, let factor = input.taxFactor, factor > 0, factor < 1 {
            tax.af = 1
            tax.f = NSDecimalNumber(decimal: factor).doubleValue
        }
        tax.KVZ = BigDecimal(input.healthAdditionalRate)
        tax.PVS = input.region == "SN" ? 1 : 0
        tax.PVZ = input.isParent ? 0 : 1
        tax.PVA = BigDecimal.valueOf(max(0, min(input.childrenUnder25, 5) - 1))
        tax.ZKF = BigDecimal(input.childAllowances)
        tax.R = input.churchMember ? 1 : 0
        if input.status != .employee {
            // Neither civil servants nor full pensioners pay into pension or unemployment insurance.
            tax.KRV = 1
            tax.ALV = 1
        }
        if input.isPrivatelyInsured {
            tax.PKV = 1
            tax.PKPV = BigDecimal.valueOf(Int((input.privateHealthPremium + input.privateCarePremium).cents))
            tax.PKPVAGZ = BigDecimal.valueOf(Int(employerSubsidy(input, p).cents))
        }
        if let born = input.birthYear, born <= input.year - 65 {
            tax.ALTER1 = 1
            tax.AJAHR = born + 65
        }
        tax.LZZFREIB = BigDecimal.valueOf(Int(input.monthlyAllowance.cents))
        let benefit = min(max(input.pensionBenefit, .zero), bases.taxable)
        if benefit > .zero {
            tax.VBEZ = BigDecimal.valueOf(Int(benefit.cents))
            tax.VBEZM = BigDecimal.valueOf(Int(benefit.cents))
            tax.VJAHR = input.pensionBenefitStartYear
        }
        if input.oneOffPayment > .zero {
            tax.SONSTB = BigDecimal.valueOf(Int(input.oneOffPayment.cents))
            tax.JRE4 = BigDecimal.valueOf(Int(bases.taxable.cents * 12))
            tax.JFREIB = BigDecimal.valueOf(Int(input.monthlyAllowance.cents * 12))
            tax.JVBEZ = BigDecimal.valueOf(Int(benefit.cents * 12))
        }
        tax.main()
        func money(_ value: BigDecimal) -> Money { Money(cents: Int64(value.longValue())) }
        return (
            TaxAmounts(tax: money(tax.LSTLZZ), solidarity: money(tax.SOLZLZZ), churchBase: money(tax.BK)),
            TaxAmounts(tax: money(tax.STS), solidarity: money(tax.SOLZS), churchBase: money(tax.BKS))
        )
    }

    private func taxes(_ amounts: TaxAmounts, _ input: PayInput) -> [Deduction] {
        // Church tax is cut off at the cent, like wage tax.
        let church =
            input.churchMember
            ? Money(cents: amounts.churchBase.cents * Self.churchRate(input.region) / 100) : .zero
        return [
            Deduction(.incomeTax, amounts.tax), Deduction(.solidaritySurcharge, amounts.solidarity),
            Deduction(.churchTax, church),
        ]
    }

    /// Half the private premiums, capped at what the employer would pay for statutory cover
    /// (§ 257 SGB V, § 61 SGB XI). Civil servants get none; the state's aid is in the lower premium.
    func employerSubsidy(_ input: PayInput, _ p: Parameters) -> Money {
        guard input.status != .civilServant else { return .zero }
        let healthCap = p.healthCeiling * ((p.healthGeneralRate + p.averageAdditionalRate) / 2 / 100)
        let careEmployer = input.region == "SN" ? p.careRate - p.careEmployeeSaxony : p.careRate / 2
        let careCap = p.healthCeiling * (careEmployer / 100)
        return min(input.privateHealthPremium / 2, healthCap) + min(input.privateCarePremium / 2, careCap)
    }

    /// Employee contribution rates in percent; zero where a branch does not apply.
    struct Rates {
        var health: Decimal = 0
        var care: Decimal = 0
        var pension: Decimal = 0
        var unemployment: Decimal = 0
    }

    func rates(_ input: PayInput, _ p: Parameters) -> Rates {
        guard input.status != .civilServant else { return Rates() }
        var rates = Rates()
        if !input.isPrivatelyInsured {
            let general = input.status == .pensioner ? p.healthReducedRate : p.healthGeneralRate
            rates.health = general / 2 + input.healthAdditionalRate / 2
            var care = input.region == "SN" ? p.careEmployeeSaxony : p.careRate / 2
            if !input.isParent { care += p.careChildlessSurcharge }
            care -= p.careChildDiscount * Decimal(max(0, min(input.childrenUnder25, 5) - 1))
            rates.care = care
        }
        if input.status == .employee {
            rates.pension = p.pensionRate / 2
            rates.unemployment = p.unemploymentRate / 2
        }
        return rates
    }

    private func privateShare(_ input: PayInput, _ p: Parameters) -> [Deduction] {
        guard input.isPrivatelyInsured else { return [] }
        let premiums = input.privateHealthPremium + input.privateCarePremium
        return [Deduction(.privateInsurance, max(.zero, premiums - employerSubsidy(input, p)))]
    }

    private func socialInsurance(_ input: PayInput, _ gross: Money, _ p: Parameters) -> [Deduction] {
        let benefit = min(max(input.pensionBenefit, .zero), gross)
        guard benefit > .zero else { return wageContributions(input, gross, p) }
        return Self.merged(
            wageContributions(input, gross - benefit, p) + benefitContributions(input, benefit, p))
    }

    /// A pension from a former employer: health insurance at the full general rate plus the full
    /// additional rate above an allowance, care insurance at the full rate above an exemption limit
    /// (§§ 226, 248, 249 SGB V, § 57 SGB XI); no pension or unemployment insurance. Civil servants
    /// and the privately insured pay none.
    func benefitContributions(_ input: PayInput, _ benefit: Money, _ p: Parameters) -> [Deduction] {
        guard !input.isPrivatelyInsured else { return [] }
        let capped = min(benefit, p.healthCeiling)
        let healthBase = max(.zero, capped - p.pensionBenefitAllowance)
        let healthRate = p.healthGeneralRate + input.healthAdditionalRate
        var care = p.careRate + (input.isParent ? 0 : p.careChildlessSurcharge)
        care -= p.careChildDiscount * Decimal(max(0, min(input.childrenUnder25, 5) - 1))
        let careBase = benefit > p.pensionBenefitAllowance ? capped : .zero
        return [
            Deduction(.healthInsurance, healthBase * (healthRate / 100)),
            Deduction(.careInsurance, careBase * (care / 100)),
        ]
    }

    /// Adds up lines of the same kind, keeping the order of first appearance.
    static func merged(_ lines: [Deduction]) -> [Deduction] {
        var result: [Deduction] = []
        for line in lines {
            if let index = result.firstIndex(where: { $0.kind == line.kind }) {
                result[index].amount += line.amount
            } else {
                result.append(line)
            }
        }
        return result.filter { $0.amount > .zero || $0.kind == .privateInsurance }
    }

    private func wageContributions(_ input: PayInput, _ gross: Money, _ p: Parameters) -> [Deduction] {
        // Transition zone ("Midijob"): the employee pays on a reduced base, § 20 (2a) SGB IV.
        let midi = gross > p.miniJobLimit && gross <= p.midiJobLimit
        func base(_ ceiling: Money) -> Decimal {
            if midi {
                let limit = p.midiJobLimit.decimal
                let mini = p.miniJobLimit.decimal
                return limit / (limit - mini) * (gross.decimal - mini)
            }
            return min(gross, ceiling).decimal
        }
        let r = rates(input, p)
        return contributions(r, health: base(p.healthCeiling), pension: base(p.pensionCeiling))
            + privateShare(input, p)
    }

    /// Contribution lines for the given bases, leaving out branches that do not apply.
    private func contributions(_ r: Rates, health: Decimal, pension: Decimal) -> [Deduction] {
        var lines: [Deduction] = []
        if r.health > 0 { lines.append(Deduction(.healthInsurance, Money(health * r.health / 100))) }
        if r.care > 0 { lines.append(Deduction(.careInsurance, Money(health * r.care / 100))) }
        if r.pension > 0 { lines.append(Deduction(.pensionInsurance, Money(pension * r.pension / 100))) }
        if r.unemployment > 0 {
            lines.append(Deduction(.unemploymentInsurance, Money(pension * r.unemployment / 100)))
        }
        return lines
    }

    /// A one-off payment is taxed with the annual table (§ 39b (3) EStG) and charged with
    /// contributions only up to the part of the yearly ceiling not used by the salary so far
    /// (§ 23a SGB IV), assuming the same salary every month of the year.
    func oneOffPay(
        _ input: PayInput, _ bases: Bases, _ tax: (regular: TaxAmounts, oneOff: TaxAmounts), _ p: Parameters
    ) -> OneOffPay {
        let month = Int64(min(max(input.oneOffMonth, 1), 12))
        let payment = input.oneOffPayment
        if bases.contributable > p.miniJobLimit && bases.contributable <= p.midiJobLimit {
            // In the transition zone the month's whole pay decides (§ 20 (2a) SGB IV): charge the
            // difference between the month with and without the payment.
            let with = wageContributions(input, bases.contributable + payment, p)
            let without = wageContributions(input, bases.contributable, p)
            let lines = with.map { line in
                Deduction(line.kind, line.amount - (without.first { $0.kind == line.kind }?.amount ?? .zero))
            }
            return OneOffPay(
                gross: payment,
                deductions: taxes(tax.oneOff, input) + lines.filter { $0.kind != .privateInsurance })
        }
        func room(_ ceiling: Money, months: Int64) -> Money {
            Money(cents: months * max(0, (ceiling - bases.contributable).cents))
        }
        var healthRoom = room(p.healthCeiling, months: month)
        var pensionRoom = room(p.pensionCeiling, months: month)
        // March clause: from January to March, a payment beyond this year's room belongs to last
        // December. The health ceiling decides for the statutorily insured, else the pension ceiling.
        let decisive = input.isPrivatelyInsured ? pensionRoom : healthRoom
        if month <= 3 && payment > decisive {
            healthRoom = room(p.previousHealthCeiling, months: 12)
            pensionRoom = room(p.previousPensionCeiling, months: 12)
        }
        let lines = contributions(
            rates(input, p), health: min(payment, healthRoom).decimal,
            pension: min(payment, pensionRoom).decimal)
        return OneOffPay(gross: payment, deductions: taxes(tax.oneOff, input) + lines)
    }
}
