import Foundation
import PottCore

/// Income tax, solidarity surcharge, church tax, trade tax and social insurance of a self-employed
/// person in Germany, worked out for the year and shown per month.
///
/// Simplifications (shown in the app): profit is the same every month, only basic health cover and
/// pension contributions are deducted as special expenses, a spouse's tax is split by share of
/// taxable income, and a side business is taxed as the difference it makes on top of the salary.
public struct GermanSelfEmployedCalculator: Sendable {
    public init() {}

    struct Parameters {
        /// Basic allowance and tariff zones of § 32a EStG 2026 (same as the PAP 2026).
        var basicAllowance: Decimal = 12_348
        /// Minimum monthly base for voluntarily insured self-employed (§ 240 (4) SGB V): 3,955 / 90 × 30.
        var healthMinimumBase = Money(Decimal(string: "1318.33")!)
        var healthCeiling = Money(Decimal(string: "5812.50")!)
        var pensionCeiling = Money(units: 8450)
        var pensionMinimumBase = Money(units: 603)
        var healthGeneralRate = Decimal(string: "14.6")!
        var healthReducedRate = Decimal(string: "14.0")!
        var careRate = Decimal(string: "3.6")!
        var careChildlessSurcharge = Decimal(string: "0.6")!
        var careChildDiscount = Decimal(string: "0.25")!
        var pensionRate = Decimal(string: "18.6")!
        /// Cap for pension contributions as special expenses (§ 10 (3) EStG), single.
        var pensionDeductionCap: Decimal = 30_826
        var specialExpensesLumpSum: Decimal = 36
        /// Lump sum for work expenses of employees (§ 9a EStG), for the salary next to a side business.
        var employeeLumpSum: Decimal = 1230
        var solidarityExemption: Decimal = 20_350
        var tradeTaxAllowance: Decimal = 24_500
        var tradeTaxBaseRate = Decimal(string: "0.035")!
        /// Trade tax credited against income tax: 4 × the base amount (§ 35 EStG).
        var tradeTaxCreditFactor: Decimal = 4
        /// Child allowances per child for both parents (§ 32 (6) EStG: 6,828 + 2,928) and the yearly
        /// child benefit they are compared with (259 € a month).
        var childAllowance: Decimal = 9756
        var childBenefit: Decimal = 3108

        /// Standard pension contribution (Regelbeitrag) of compulsorily insured self-employed:
        /// 18.6 % of the reference value of 3,955 € (§ 165 (1) No. 1 SGB VI; § 1 SvBezGrV 2026,
        /// BGBl. 2025 I Nr. 278; DRV "Werte der Rentenversicherung" 2026: 735.63 €).
        var standardPensionContribution = Money(Decimal(string: "735.63")!)
        /// Half of it, until three calendar years after the year of starting (§ 165 (1) SGB VI;
        /// DRV "Werte der Rentenversicherung" 2026: 367.82 €).
        var halfStandardPensionContribution = Money(Decimal(string: "367.82")!)
        /// Artists' insurance: health base at least 1/180 of the monthly reference value per
        /// calendar day (§ 234 (1) SGB V), 3,955 / 180 × 30 = 659.17 € a month; care uses the same
        /// base (§ 16a KSVG with § 57 (1) SGB XI).
        var artistsHealthMinimumBase = Money(Decimal(string: "659.17")!)
        /// Artists' insurance: pension base at least 3,900 € a year (§ 165 (1) No. 3 SGB VI).
        var artistsPensionMinimumBase = Money(units: 325)
        /// Up to 3,900 € a year from artistic work nobody is insured by the artists' fund, except
        /// in the first three years (§ 3 (1), (2) KSVG).
        var artistsMinimumIncome = Money(units: 3900)
        /// Small business rule: total revenue at most 25,000 € last year and 100,000 € this year
        /// (§ 19 (1) UStG).
        var smallBusinessPreviousYearLimit = Money(units: 25_000)
        var smallBusinessCurrentYearLimit = Money(units: 100_000)
        /// Start-up grant: 300 € a month on top of the last unemployment benefit for six months,
        /// then 300 € a month for nine more (§ 94 (1), (2) SGB III). Tax-free (§ 3 No. 2 (a) EStG)
        /// and not listed for the progression clause in § 32b (1) No. 1 EStG.
        var startupGrantLumpSum = Money(units: 300)

        static let year2026 = Parameters()
    }

    /// Income tax of § 32a EStG for a taxable income in whole euros; `joint` uses the splitting table.
    static func incomeTax(_ taxable: Decimal, joint: Bool = false, _ p: Parameters = .year2026) -> Decimal {
        let x = floored((joint ? taxable / 2 : taxable))
        var tax: Decimal
        if x <= p.basicAllowance {
            tax = 0
        } else if x <= 17_799 {
            let y = (x - p.basicAllowance) / 10_000
            tax = (Decimal(string: "914.51")! * y + 1400) * y
        } else if x <= 69_878 {
            let z = (x - 17_799) / 10_000
            tax = (Decimal(string: "173.10")! * z + 2397) * z + Decimal(string: "1034.87")!
        } else if x <= 277_825 {
            tax = Decimal(string: "0.42")! * x - Decimal(string: "11135.63")!
        } else {
            tax = Decimal(string: "0.45")! * x - Decimal(string: "19470.38")!
        }
        return floored(tax) * (joint ? 2 : 1)
    }

    /// Solidarity surcharge on the income tax: nothing up to the exemption, then at most 11.9 % of
    /// the excess, at most 5.5 % of the tax (§§ 3, 4 SolZG).
    static func solidarity(_ incomeTax: Decimal, exemption: Decimal) -> Decimal {
        guard incomeTax > exemption else { return 0 }
        let full = incomeTax * Decimal(string: "0.055")!
        let eased = (incomeTax - exemption) * Decimal(string: "0.119")!
        return truncatedToCents(min(full, eased))
    }

    /// Income tax of a household with the child benefit check (§ 31 EStG): the child allowances
    /// replace the child benefit only if they save more; the surcharge and church tax always use
    /// them (`annexBase`, § 51a EStG).
    struct Assessment: Equatable {
        var tax: Decimal
        var annexBase: Decimal
    }

    static func assessed(
        _ taxable: Decimal, joint: Bool, children: Int, _ p: Parameters = .year2026
    ) -> Assessment {
        let share: Decimal = joint ? 1 : Decimal(string: "0.5")!
        let kids = Decimal(max(0, children))
        let plain = incomeTax(taxable, joint: joint, p)
        let reduced = incomeTax(max(0, taxable - p.childAllowance * kids * share), joint: joint, p)
        let benefit = p.childBenefit * kids * share
        let tax = plain - reduced > benefit ? reduced + benefit : plain
        return Assessment(tax: tax, annexBase: reduced)
    }

    static func floored(_ value: Decimal) -> Decimal {
        var input = value
        var result = Decimal()
        NSDecimalRound(&result, &input, 0, .down)
        return result
    }

    static func truncatedToCents(_ value: Decimal) -> Decimal {
        var input = value
        var result = Decimal()
        NSDecimalRound(&result, &input, 2, .down)
        return result
    }

    /// Monthly health and care contributions (statutory) or premiums (private); none for a side
    /// business, where the job's insurance covers it.
    func healthAndCare(_ input: SelfEmployedInput, _ p: Parameters) -> (health: Money, care: Money) {
        if input.sideline { return (.zero, .zero) }
        switch input.health {
        case .private:
            return (input.privateHealthPremium, input.privateCarePremium)
        case .statutory:
            // With artists' insurance the fund pays half of the general and the additional rate
            // (§ 16 (1) KSVG) and half of the care rate; the surcharge for the childless and the
            // discounts for children stay with the insured (§ 16a (1) KSVG, § 55 (3) SGB XI).
            let share: Decimal = input.artistsInsurance ? Decimal(string: "0.5")! : 1
            let minimum = input.artistsInsurance ? p.artistsHealthMinimumBase : p.healthMinimumBase
            let profit = input.effectiveMonthlyProfit
            let base = min(max(profit, minimum), p.healthCeiling).decimal
            let general = input.withSickPay ? p.healthGeneralRate : p.healthReducedRate
            var care = p.careRate * share + (input.isParent ? 0 : p.careChildlessSurcharge)
            care -= p.careChildDiscount * Decimal(max(0, min(input.childrenUnder25, 5) - 1))
            return (
                Money(base * (general + input.healthAdditionalRate) * share / 100), Money(base * care / 100)
            )
        }
    }

    /// Monthly statutory pension contribution; with artists' insurance half of it on the income,
    /// the fund pays the other half (§ 15 KSVG).
    func pension(_ input: SelfEmployedInput, _ p: Parameters) -> Money {
        if input.artistsInsurance {
            let base = min(max(input.effectiveMonthlyProfit, p.artistsPensionMinimumBase), p.pensionCeiling)
            return Money(base.decimal * p.pensionRate / 200)
        }
        return switch input.pension {
        case .none: .zero
        case .statutory:
            Money(
                min(max(input.effectiveMonthlyProfit, p.pensionMinimumBase), p.pensionCeiling).decimal
                    * p.pensionRate / 100)
        case .standardContribution: p.standardPensionContribution
        case .halfStandardContribution: p.halfStandardPensionContribution
        }
    }

    /// Monthly start-up grant: phase one the last unemployment benefit plus the lump sum, phase two
    /// the lump sum.
    func startupGrant(_ input: SelfEmployedInput, _ p: Parameters) -> Money {
        switch input.startupGrant {
        case .none: .zero
        case .first: max(.zero, input.unemploymentBenefit) + p.startupGrantLumpSum
        case .second: p.startupGrantLumpSum
        }
    }

    /// Checks the small business limits with last year's revenue and this year's (entered, or
    /// estimated as twelve months of revenue).
    func smallBusinessCheck(_ input: SelfEmployedInput, _ p: Parameters) -> SmallBusinessCheck {
        let thisYear = input.expectedRevenue > .zero ? input.expectedRevenue : input.monthlyRevenue * 12
        if input.previousYearRevenue > p.smallBusinessPreviousYearLimit { return .previousYearTooHigh }
        if thisYear > p.smallBusinessCurrentYearLimit { return .currentYearTooHigh }
        return .applies
    }

    /// Taxable income of the salary next to a side business: yearly taxable pay minus the lump sum
    /// for work expenses, the employee's pension and basic health contributions and the lump sum
    /// for special expenses. Mini jobs are taxed flat and count as nothing.
    static func salaryTaxable(_ salary: PayInput, _ p: Parameters = .year2026) -> Decimal {
        guard salary.employment != .mini else { return 0 }
        let pay = GermanPayCalculator()
        let result = pay.calculate(salary)
        let taxable = GermanPayCalculator.bases(salary, .year2026).taxable.decimal * 12
        let provision =
            (result.amount(of: .pensionInsurance).decimal + result.amount(of: .healthInsurance).decimal
                * Decimal(string: "0.96")! + result.amount(of: .careInsurance).decimal
                + result.amount(of: .privateInsurance).decimal) * 12
        return max(0, floored(taxable - p.employeeLumpSum - provision - p.specialExpensesLumpSum))
    }

    /// Yearly figures behind the monthly view, in euros.
    struct Year: Equatable {
        var profit: Decimal
        var specialExpenses: Decimal
        var taxable: Decimal
        /// Income tax caused by the business, before the trade tax credit.
        var incomeTax: Decimal
        var tradeTax: Decimal
        var tradeTaxCredit: Decimal
        var solidarity: Decimal
        var churchTax: Decimal
    }

    func year(_ input: SelfEmployedInput, salary: PayInput? = nil, _ p: Parameters = .year2026) -> Year {
        let (health, care) = healthAndCare(input, p)
        let profit = input.effectiveMonthlyProfit.decimal * 12
        // Special expenses: pension contributions up to the cap, basic health cover (statutory health
        // without the 4 % share for sick pay) and care in full, plus the lump sum (already counted
        // with the salary for a side business).
        let pensionCap = p.pensionDeductionCap * (input.married ? 2 : 1)
        // Statutory pension (own share) and a basic pension contract share one cap (§ 10 (1) No. 2
        // (a), (b), (3) EStG). The fund's half for artists is tax-free (§ 3 No. 57 EStG) and, unlike
        // an employer's share (§ 3 No. 62), not added.
        let pensionDeduction = min(
            (pension(input, p) + max(.zero, input.basicPension)).decimal * 12, pensionCap)
        let healthShare =
            input.health == .statutory && input.withSickPay ? Decimal(string: "0.96")! : Decimal(1)
        let healthDeduction = (health.decimal * healthShare + care.decimal) * 12
        let lumpSum = input.sideline ? 0 : p.specialExpensesLumpSum
        let specialExpenses = pensionDeduction + healthDeduction + lumpSum
        let taxable = max(0, Self.floored(profit - specialExpenses))

        let other = input.sideline ? salary.map { Self.salaryTaxable($0, p) } ?? 0 : 0
        let partner = input.married ? max(0, input.partnerTaxableIncome.decimal) : 0
        let kids = input.childrenUnder25
        let all = Self.assessed(taxable + other + partner, joint: input.married, children: kids, p)
        let without = Self.assessed(other + partner, joint: input.married, children: kids, p)

        // A side business is taxed with the difference it makes; a main business carries its share
        // of the household's tax by taxable income.
        let share: Decimal
        if input.sideline || partner == 0 {
            share = 1
        } else {
            share = taxable + partner > 0 ? taxable / (taxable + partner) : 0
        }
        func own(_ withBusiness: Decimal, _ withoutBusiness: Decimal) -> Decimal {
            input.sideline ? withBusiness - withoutBusiness : Self.floored(withBusiness * share)
        }
        let tax = max(0, own(all.tax, without.tax))
        let annex = max(0, own(all.annexBase, without.annexBase))

        // Trade tax: profit rounded down to hundreds, minus the allowance, base rate, multiplier.
        var tradeTax: Decimal = 0
        var credit: Decimal = 0
        if input.isTrade {
            var hundreds = profit / 100
            var rounded = Decimal()
            NSDecimalRound(&rounded, &hundreds, 0, .down)
            let base = max(0, rounded * 100 - p.tradeTaxAllowance) * p.tradeTaxBaseRate
            tradeTax = base * Decimal(input.tradeTaxRate) / 100
            credit = min(base * p.tradeTaxCreditFactor, tradeTax, tax)
        }

        // The surcharge follows the tax after the credit, for the household; church tax ignores
        // the credit (§ 51a (2) EStG).
        let exemption = p.solidarityExemption * (input.married ? 2 : 1)
        let solidarity: Decimal
        if input.sideline {
            solidarity = max(
                0,
                Self.solidarity(all.annexBase - credit, exemption: exemption)
                    - Self.solidarity(without.annexBase, exemption: exemption))
        } else {
            let householdAnnex = share == 1 ? annex : all.annexBase
            let total = Self.solidarity(householdAnnex - credit, exemption: exemption)
            let ownAfter = annex - credit
            let householdAfter = householdAnnex - credit
            solidarity = householdAfter > 0 ? Self.truncatedToCents(total * ownAfter / householdAfter) : 0
        }
        let rate: Decimal = ["BY", "BW"].contains(input.region) ? 8 : 9
        let church = input.churchMember ? Self.truncatedToCents(annex * rate / 100) : 0
        return Year(
            profit: profit, specialExpenses: specialExpenses, taxable: taxable, incomeTax: tax,
            tradeTax: tradeTax, tradeTaxCredit: credit, solidarity: max(0, solidarity), churchTax: church)
    }

    public func calculate(_ input: SelfEmployedInput, salary: PayInput? = nil) -> SelfEmployedResult {
        let p = Parameters.year2026
        let figures = year(input, salary: salary, p)
        let (health, care) = healthAndCare(input, p)
        let monthly: (Decimal) -> Money = { Money($0 / 12) }
        let incomeTax = figures.incomeTax - figures.tradeTaxCredit
        var deductions = [
            Deduction(.incomeTax, monthly(incomeTax)),
            Deduction(.solidaritySurcharge, monthly(figures.solidarity)),
            Deduction(.churchTax, monthly(figures.churchTax)),
        ]
        if input.isTrade { deductions.append(Deduction(.tradeTax, monthly(figures.tradeTax))) }
        if !input.sideline {
            switch input.health {
            case .statutory:
                deductions += [Deduction(.healthInsurance, health), Deduction(.careInsurance, care)]
            case .private:
                deductions.append(Deduction(.privateInsurance, health + care))
            }
        }
        let pension = pension(input, p)
        if pension > .zero { deductions.append(Deduction(.pensionInsurance, pension)) }
        if input.basicPension > .zero { deductions.append(Deduction(.basicPension, input.basicPension)) }
        let check = input.smallBusiness ? smallBusinessCheck(input, p) : nil
        let chargesVAT = check != .applies
        return SelfEmployedResult(
            monthly: PayResult(
                gross: input.effectiveMonthlyProfit, deductions: deductions,
                startupGrant: startupGrant(input, p)),
            quarterlyTaxReserve: Money((incomeTax + figures.solidarity + figures.churchTax) / 4),
            quarterlyTradeTax: Money(figures.tradeTax / 4),
            taxableIncome: Money(figures.taxable),
            monthlyVAT: chargesVAT ? max(.zero, input.monthlyRevenue) * (input.vatRate / 100) : .zero,
            smallBusinessCheck: check,
            belowArtistsMinimum: input.artistsInsurance
                && input.effectiveMonthlyProfit * 12 <= p.artistsMinimumIncome)
    }

    /// The monthly profit needed to take out `targetNet` each month, by bisection on cents.
    public func profitNeeded(
        forNet targetNet: Money, _ input: SelfEmployedInput, salary: PayInput? = nil
    ) -> SelfEmployedResult? {
        guard targetNet.cents > 0 else { return nil }
        func result(_ cents: Int64) -> SelfEmployedResult {
            var copy = input
            copy.usesDayRate = false
            copy.monthlyProfit = Money(cents: cents)
            return calculate(copy, salary: salary)
        }
        var low: Int64 = 0
        var high = max(targetNet.cents * 10, 1_000_000)
        guard result(high).monthly.net >= targetNet else { return nil }
        while high - low > 1 {
            let middle = (low + high) / 2
            if result(middle).monthly.net >= targetNet { high = middle } else { low = middle }
        }
        return result(high)
    }
}
