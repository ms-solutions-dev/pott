import Foundation

/// How a self-employed person is health insured.
public enum SelfEmployedHealth: String, Sendable, Codable, CaseIterable {
    /// Voluntarily in statutory insurance, paying the full rate on the profit.
    case statutory
    /// Private health and care insurance with a fixed premium.
    case `private`
}

/// How a self-employed person pays into the statutory pension insurance. A basic pension contract
/// (Rürup) is a separate amount, `SelfEmployedInput.basicPension`.
public enum SelfEmployedPension: String, Sendable, Codable, CaseIterable {
    /// Nothing.
    case none
    /// Statutory pension insurance on the profit, full rate (voluntary, or compulsory with proof
    /// of income).
    case statutory
    /// Compulsorily insured (§ 2 SGB VI: craftspeople, teachers, midwives …) paying the standard
    /// contribution (Regelbeitrag) on the reference value.
    case standardContribution
    /// The same in the first three calendar years after starting: half the standard contribution.
    case halfStandardContribution
}

/// The start-up grant of the employment agency (Gründungszuschuss, § 93 SGB III).
public enum StartupGrantPhase: String, Sendable, Codable, CaseIterable {
    case none
    /// First six months: the last unemployment benefit plus a lump sum.
    case first
    /// Nine more months: the lump sum only.
    case second
}

/// Everything the self-employed view needs. Amounts are monthly; the tax is worked out for the year.
public struct SelfEmployedInput: Sendable, Equatable, Codable {
    /// Average profit per month (revenue minus business costs, without VAT).
    public var monthlyProfit: Money
    /// Work out the profit from a day rate instead of entering it.
    public var usesDayRate: Bool
    /// Net day rate (Personentag), without VAT.
    public var dayRate: Money
    /// Billed days per week.
    public var daysPerWeek: Int
    /// Working days a year without billing: holidays, sick days, public holidays, gaps.
    public var daysOff: Int
    /// Business costs per month (office, software, insurance, car …).
    public var businessCosts: Money
    /// A side business next to a job: health insurance runs through the job, and the profit is taxed
    /// on top of the salary.
    public var sideline: Bool
    /// A trade business pays trade tax; freelancers (Freiberufler) do not.
    public var isTrade: Bool
    /// Municipal trade tax multiplier in percent, e.g. 400.
    public var tradeTaxRate: Int
    public var region: String
    public var churchMember: Bool
    /// Jointly assessed with a spouse.
    public var married: Bool
    /// The spouse's taxable income per year, for the splitting table.
    public var partnerTaxableIncome: Money
    /// Children with child benefit; also lower the care insurance from the second one.
    public var childrenUnder25: Int
    public var isParent: Bool
    public var health: SelfEmployedHealth
    /// Statutory insurance with sick pay from the seventh week (general rate) or without (reduced).
    public var withSickPay: Bool
    public var healthAdditionalRate: Decimal
    public var privateHealthPremium: Money
    public var privateCarePremium: Money
    public var pension: SelfEmployedPension
    /// Monthly contribution to a basic pension contract (Rürup), deducted as special expense.
    public var basicPension: Money
    /// Insured through the artists' social insurance fund (Künstlersozialkasse): the fund pays the
    /// other half of health, care and pension contributions.
    public var artistsInsurance: Bool
    /// Uses the small business rule (§ 19 UStG) and charges no VAT.
    public var smallBusiness: Bool
    /// VAT rate in percent charged on the revenue (19 or 7).
    public var vatRate: Decimal
    /// Total revenue of the previous calendar year, for the small business limits.
    public var previousYearRevenue: Money
    /// Expected revenue of this year; zero means "estimate from the profit and costs".
    public var expectedRevenue: Money
    public var startupGrant: StartupGrantPhase
    /// The unemployment benefit drawn last, per month (phase one of the start-up grant).
    public var unemploymentBenefit: Money
    /// Name of the chosen health insurer from the bundled list; nil when the rate was typed in.
    public var healthInsurer: String?
    public var year: Int

    public init(
        monthlyProfit: Money, usesDayRate: Bool = false, dayRate: Money = .zero, daysPerWeek: Int = 5,
        daysOff: Int = 40, businessCosts: Money = .zero, sideline: Bool = false, isTrade: Bool = false,
        tradeTaxRate: Int = 400, region: String = "BY", churchMember: Bool = false, married: Bool = false,
        partnerTaxableIncome: Money = .zero, childrenUnder25: Int = 0, isParent: Bool = false,
        health: SelfEmployedHealth = .statutory, withSickPay: Bool = true,
        healthAdditionalRate: Decimal = Decimal(string: "2.9")!, privateHealthPremium: Money = .zero,
        privateCarePremium: Money = .zero, pension: SelfEmployedPension = .none,
        basicPension: Money = .zero, artistsInsurance: Bool = false, smallBusiness: Bool = false,
        vatRate: Decimal = 19, previousYearRevenue: Money = .zero, expectedRevenue: Money = .zero,
        startupGrant: StartupGrantPhase = .none, unemploymentBenefit: Money = .zero,
        healthInsurer: String? = nil, year: Int = 2026
    ) {
        self.monthlyProfit = monthlyProfit
        self.usesDayRate = usesDayRate
        self.dayRate = dayRate
        self.daysPerWeek = daysPerWeek
        self.daysOff = daysOff
        self.businessCosts = businessCosts
        self.sideline = sideline
        self.isTrade = isTrade
        self.tradeTaxRate = tradeTaxRate
        self.region = region
        self.churchMember = churchMember
        self.married = married
        self.partnerTaxableIncome = partnerTaxableIncome
        self.childrenUnder25 = childrenUnder25
        self.isParent = isParent
        self.health = health
        self.withSickPay = withSickPay
        self.healthAdditionalRate = healthAdditionalRate
        self.privateHealthPremium = privateHealthPremium
        self.privateCarePremium = privateCarePremium
        self.pension = pension
        self.basicPension = basicPension
        self.artistsInsurance = artistsInsurance
        self.smallBusiness = smallBusiness
        self.vatRate = vatRate
        self.previousYearRevenue = previousYearRevenue
        self.expectedRevenue = expectedRevenue
        self.startupGrant = startupGrant
        self.unemploymentBenefit = unemploymentBenefit
        self.healthInsurer = healthInsurer
        self.year = year
    }

    /// Reads older saved inputs too: every field added later falls back to its default.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = SelfEmployedInput(monthlyProfit: .zero)
        func value<T: Decodable>(_ key: CodingKeys, _ fallback: T) throws -> T {
            try c.decodeIfPresent(T.self, forKey: key) ?? fallback
        }
        monthlyProfit = try value(.monthlyProfit, d.monthlyProfit)
        usesDayRate = try value(.usesDayRate, d.usesDayRate)
        dayRate = try value(.dayRate, d.dayRate)
        daysPerWeek = try value(.daysPerWeek, d.daysPerWeek)
        daysOff = try value(.daysOff, d.daysOff)
        businessCosts = try value(.businessCosts, d.businessCosts)
        sideline = try value(.sideline, d.sideline)
        isTrade = try value(.isTrade, d.isTrade)
        tradeTaxRate = try value(.tradeTaxRate, d.tradeTaxRate)
        region = try value(.region, d.region)
        churchMember = try value(.churchMember, d.churchMember)
        married = try value(.married, d.married)
        partnerTaxableIncome = try value(.partnerTaxableIncome, d.partnerTaxableIncome)
        childrenUnder25 = try value(.childrenUnder25, d.childrenUnder25)
        isParent = try value(.isParent, d.isParent)
        health = try value(.health, d.health)
        withSickPay = try value(.withSickPay, d.withSickPay)
        healthAdditionalRate = try value(.healthAdditionalRate, d.healthAdditionalRate)
        privateHealthPremium = try value(.privateHealthPremium, d.privateHealthPremium)
        privateCarePremium = try value(.privateCarePremium, d.privateCarePremium)
        // Before the basic pension had its own field, "ownAmount" held such a contract.
        let storedPension = try value(.pension, "none")
        pension = SelfEmployedPension(rawValue: storedPension) ?? .none
        var legacyBasicPension = d.basicPension
        if storedPension == "ownAmount" { legacyBasicPension = try value(.ownPensionAmount, d.basicPension) }
        basicPension = try value(.basicPension, legacyBasicPension)
        artistsInsurance = try value(.artistsInsurance, d.artistsInsurance)
        smallBusiness = try value(.smallBusiness, d.smallBusiness)
        vatRate = try value(.vatRate, d.vatRate)
        previousYearRevenue = try value(.previousYearRevenue, d.previousYearRevenue)
        expectedRevenue = try value(.expectedRevenue, d.expectedRevenue)
        startupGrant = try value(.startupGrant, d.startupGrant)
        unemploymentBenefit = try value(.unemploymentBenefit, d.unemploymentBenefit)
        healthInsurer = try c.decodeIfPresent(String.self, forKey: .healthInsurer)
        year = try value(.year, d.year)
    }

    enum CodingKeys: String, CodingKey {
        case monthlyProfit, usesDayRate, dayRate, daysPerWeek, daysOff, businessCosts, sideline, isTrade
        case tradeTaxRate, region, churchMember, married, partnerTaxableIncome, childrenUnder25, isParent
        case health, withSickPay, healthAdditionalRate, privateHealthPremium, privateCarePremium, pension
        case basicPension, artistsInsurance, smallBusiness, vatRate, previousYearRevenue, expectedRevenue
        case startupGrant, unemploymentBenefit, healthInsurer, year
        /// Only read, from inputs saved before `basicPension` existed.
        case ownPensionAmount
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(monthlyProfit, forKey: .monthlyProfit)
        try c.encode(usesDayRate, forKey: .usesDayRate)
        try c.encode(dayRate, forKey: .dayRate)
        try c.encode(daysPerWeek, forKey: .daysPerWeek)
        try c.encode(daysOff, forKey: .daysOff)
        try c.encode(businessCosts, forKey: .businessCosts)
        try c.encode(sideline, forKey: .sideline)
        try c.encode(isTrade, forKey: .isTrade)
        try c.encode(tradeTaxRate, forKey: .tradeTaxRate)
        try c.encode(region, forKey: .region)
        try c.encode(churchMember, forKey: .churchMember)
        try c.encode(married, forKey: .married)
        try c.encode(partnerTaxableIncome, forKey: .partnerTaxableIncome)
        try c.encode(childrenUnder25, forKey: .childrenUnder25)
        try c.encode(isParent, forKey: .isParent)
        try c.encode(health, forKey: .health)
        try c.encode(withSickPay, forKey: .withSickPay)
        try c.encode(healthAdditionalRate, forKey: .healthAdditionalRate)
        try c.encode(privateHealthPremium, forKey: .privateHealthPremium)
        try c.encode(privateCarePremium, forKey: .privateCarePremium)
        try c.encode(pension, forKey: .pension)
        try c.encode(basicPension, forKey: .basicPension)
        try c.encode(artistsInsurance, forKey: .artistsInsurance)
        try c.encode(smallBusiness, forKey: .smallBusiness)
        try c.encode(vatRate, forKey: .vatRate)
        try c.encode(previousYearRevenue, forKey: .previousYearRevenue)
        try c.encode(expectedRevenue, forKey: .expectedRevenue)
        try c.encode(startupGrant, forKey: .startupGrant)
        try c.encode(unemploymentBenefit, forKey: .unemploymentBenefit)
        try c.encodeIfPresent(healthInsurer, forKey: .healthInsurer)
        try c.encode(year, forKey: .year)
    }

    /// Billed days a year: 52 weeks of the chosen days, minus the days off.
    public var billableDays: Int { max(0, 52 * min(max(daysPerWeek, 0), 7) - max(daysOff, 0)) }

    /// The monthly profit the calculation uses: entered directly, or from the day rate.
    public var effectiveMonthlyProfit: Money {
        guard usesDayRate else { return monthlyProfit }
        return dayRate * (Decimal(billableDays) / 12) - businessCosts
    }

    /// Net revenue per month without VAT: day rate times days, or profit plus business costs.
    public var monthlyRevenue: Money {
        usesDayRate ? dayRate * (Decimal(billableDays) / 12) : monthlyProfit + businessCosts
    }

    /// The day rate that gives a monthly profit, with the same days and costs; nil without days.
    public func dayRate(forMonthlyProfit profit: Money) -> Money? {
        guard billableDays > 0 else { return nil }
        return (profit + businessCosts) * (Decimal(12) / Decimal(billableDays))
    }
}

/// What a self-employed person can take out each month, and what to put aside.
public struct SelfEmployedResult: Sendable, Equatable {
    /// Monthly view: gross is the profit, deductions are taxes and contributions per month.
    public var monthly: PayResult
    /// Income tax, solidarity surcharge and church tax for the year, paid in quarterly advances.
    public var quarterlyTaxReserve: Money
    /// Trade tax for the year, also paid quarterly.
    public var quarterlyTradeTax: Money
    /// Taxable income of the year (own share, before splitting).
    public var taxableIncome: Money
    /// VAT charged on the revenue each month, which goes on to the tax office; zero for a small
    /// business. Not part of the profit.
    public var monthlyVAT: Money
    /// Whether the small business rule may be used, when it is chosen.
    public var smallBusinessCheck: SmallBusinessCheck?
    /// With artists' insurance: the yearly income is at or below the minimum, so outside the first
    /// three years the person would not be insured there.
    public var belowArtistsMinimum: Bool

    public init(
        monthly: PayResult, quarterlyTaxReserve: Money, quarterlyTradeTax: Money, taxableIncome: Money,
        monthlyVAT: Money = .zero, smallBusinessCheck: SmallBusinessCheck? = nil,
        belowArtistsMinimum: Bool = false
    ) {
        self.monthly = monthly
        self.quarterlyTaxReserve = quarterlyTaxReserve
        self.quarterlyTradeTax = quarterlyTradeTax
        self.taxableIncome = taxableIncome
        self.monthlyVAT = monthlyVAT
        self.smallBusinessCheck = smallBusinessCheck
        self.belowArtistsMinimum = belowArtistsMinimum
    }
}

/// Result of checking the small business limits of § 19 UStG.
public enum SmallBusinessCheck: Sendable, Equatable {
    case applies
    /// Last year's revenue was above the limit, so VAT is due this year.
    case previousYearTooHigh
    /// This year's revenue goes above the limit, so the rule no longer applies.
    case currentYearTooHigh
}
