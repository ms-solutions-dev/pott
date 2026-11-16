/// The kind of job, because it changes how a salary is taxed.
import Foundation

/// Who the person is for social insurance; changes which contributions apply.

/// How the private use of a company car is taxed.

/// A company car that may also be used privately.

/// A leased company bike paid by salary conversion.

/// Everything a pay calculator needs. Fields a country does not use are ignored.

/// One line of the payslip.

/// What is left of a one-off payment in the month it is paid.

/// Turns gross into net pay for one country. Germany is `TaxDE.GermanPayCalculator`; another
/// country plugs in its own implementation and nothing else in the app changes.

public enum Employment: String, Sendable, Codable, CaseIterable {
    /// The main job with the person's own tax class.
    case main
    /// A second job; in Germany always taxed in class VI.
    case secondary
    /// A mini job with a small, mostly tax-free salary.
    case mini
}
public enum WorkerStatus: String, Sendable, Codable, CaseIterable {
    /// An ordinary employee.
    case employee
    /// A civil servant (Beamter): no social insurance, health cover is private.
    case civilServant
    /// Draws a full old-age pension past the regular retirement age: no pension or unemployment
    /// contribution, health insurance without sick pay.
    case pensioner
}
public enum CarKind: String, Sendable, Codable, CaseIterable {
    /// Combustion engine: 1 % of the list price.
    case combustion
    /// Plug-in hybrid meeting the range rules: half the list price.
    case hybrid
    /// Battery electric: a quarter of the list price below the price limit, half above.
    case electric
}
public struct CompanyCar: Sendable, Equatable, Codable {
    /// Gross list price when first registered, including extras.
    public var listPrice: Money
    public var kind: CarKind
    /// One-way distance from home to work in whole kilometres.
    public var commuteKilometres: Int
    /// What the employee pays the employer for the car each month.
    public var coPayment: Money

    public init(
        listPrice: Money, kind: CarKind = .combustion, commuteKilometres: Int = 0, coPayment: Money = .zero
    ) {
        self.listPrice = listPrice
        self.kind = kind
        self.commuteKilometres = commuteKilometres
        self.coPayment = coPayment
    }
}
public struct CompanyBike: Sendable, Equatable, Codable {
    public var listPrice: Money
    /// Monthly leasing rate taken from the gross salary.
    public var leasingRate: Money

    public init(listPrice: Money, leasingRate: Money) {
        self.listPrice = listPrice
        self.leasingRate = leasingRate
    }
}
public struct PayInput: Sendable, Equatable, Codable {
    /// Gross salary per month.
    public var gross: Money
    public var employment: Employment
    /// Tax class 1…6 where a country has tax classes.
    public var taxClass: Int
    /// Factor of the factor method (class IV only), three decimals, e.g. 0.912; nil when not used.
    public var taxFactor: Decimal?
    /// Region code, e.g. a German state ("BY", "SN"); affects church tax and care insurance.
    public var region: String
    public var churchMember: Bool
    /// Child allowances (0.5 steps in Germany).
    public var childAllowances: Decimal
    /// Children under 25, for care insurance discounts.
    public var childrenUnder25: Int
    /// Ever had children; without, a care insurance surcharge applies.
    public var isParent: Bool
    /// Additional contribution rate of the health insurer in percent, e.g. 2.9.
    public var healthAdditionalRate: Decimal
    /// Name of the chosen health insurer from the bundled list; nil when the rate was typed in.
    public var healthInsurer: String?
    /// Mini job: exempt from pension insurance.
    public var pensionExempt: Bool
    public var status: WorkerStatus
    /// Privately insured instead of statutory health insurance (always for civil servants).
    public var privateInsurance: Bool
    /// Monthly premiums for private basic health and compulsory care cover.
    public var privateHealthPremium: Money
    public var privateCarePremium: Money
    /// Year of birth; from the year after the 64th birthday an age relief applies.
    public var birthYear: Int?
    /// Monthly tax-free allowance registered with the tax office.
    public var monthlyAllowance: Money
    /// Salary converted into a company pension each month.
    public var pensionConversion: Money
    public var companyCar: CompanyCar?
    public var companyBike: CompanyBike?
    /// A one-off payment such as a Christmas bonus, and the month (1…12) it is paid in.
    public var oneOffPayment: Money
    public var oneOffMonth: Int
    /// Pension from a former employer paid through the payroll (Versorgungsbezug: civil-servant
    /// pension, company pension by direct promise), included in `gross`; and the year it started.
    public var pensionBenefit: Money
    public var pensionBenefitStartYear: Int
    /// Short-time work: the gross actually earned this month; `gross` is then the usual gross.
    public var shortTimeGross: Money?
    public var year: Int

    public init(
        gross: Money, employment: Employment = .main, taxClass: Int = 1, taxFactor: Decimal? = nil,
        region: String = "BY", churchMember: Bool = false, childAllowances: Decimal = 0,
        childrenUnder25: Int = 0, isParent: Bool = false,
        healthAdditionalRate: Decimal = Decimal(string: "2.9")!, pensionExempt: Bool = false,
        status: WorkerStatus = .employee, privateInsurance: Bool = false,
        privateHealthPremium: Money = .zero, privateCarePremium: Money = .zero, birthYear: Int? = nil,
        monthlyAllowance: Money = .zero, pensionConversion: Money = .zero, companyCar: CompanyCar? = nil,
        companyBike: CompanyBike? = nil, oneOffPayment: Money = .zero, oneOffMonth: Int = 12,
        pensionBenefit: Money = .zero, pensionBenefitStartYear: Int = 2026, shortTimeGross: Money? = nil,
        year: Int = 2026, healthInsurer: String? = nil
    ) {
        self.gross = gross
        self.employment = employment
        self.taxClass = taxClass
        self.taxFactor = taxFactor
        self.region = region
        self.churchMember = churchMember
        self.childAllowances = childAllowances
        self.childrenUnder25 = childrenUnder25
        self.isParent = isParent
        self.healthAdditionalRate = healthAdditionalRate
        self.healthInsurer = healthInsurer
        self.pensionExempt = pensionExempt
        self.status = status
        self.privateInsurance = privateInsurance
        self.privateHealthPremium = privateHealthPremium
        self.privateCarePremium = privateCarePremium
        self.birthYear = birthYear
        self.monthlyAllowance = monthlyAllowance
        self.pensionConversion = pensionConversion
        self.companyCar = companyCar
        self.companyBike = companyBike
        self.oneOffPayment = oneOffPayment
        self.oneOffMonth = oneOffMonth
        self.pensionBenefit = pensionBenefit
        self.pensionBenefitStartYear = pensionBenefitStartYear
        self.shortTimeGross = shortTimeGross
        self.year = year
    }

    /// Reads older saved inputs too: every field added later falls back to its default.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = PayInput(gross: .zero)
        gross = try c.decodeIfPresent(Money.self, forKey: .gross) ?? d.gross
        employment = try c.decodeIfPresent(Employment.self, forKey: .employment) ?? d.employment
        taxClass = try c.decodeIfPresent(Int.self, forKey: .taxClass) ?? d.taxClass
        taxFactor = try c.decodeIfPresent(Decimal.self, forKey: .taxFactor)
        region = try c.decodeIfPresent(String.self, forKey: .region) ?? d.region
        churchMember = try c.decodeIfPresent(Bool.self, forKey: .churchMember) ?? d.churchMember
        childAllowances = try c.decodeIfPresent(Decimal.self, forKey: .childAllowances) ?? d.childAllowances
        childrenUnder25 = try c.decodeIfPresent(Int.self, forKey: .childrenUnder25) ?? d.childrenUnder25
        isParent = try c.decodeIfPresent(Bool.self, forKey: .isParent) ?? d.isParent
        healthAdditionalRate =
            try c.decodeIfPresent(Decimal.self, forKey: .healthAdditionalRate) ?? d.healthAdditionalRate
        healthInsurer = try c.decodeIfPresent(String.self, forKey: .healthInsurer)
        pensionExempt = try c.decodeIfPresent(Bool.self, forKey: .pensionExempt) ?? d.pensionExempt
        status = try c.decodeIfPresent(WorkerStatus.self, forKey: .status) ?? d.status
        privateInsurance = try c.decodeIfPresent(Bool.self, forKey: .privateInsurance) ?? d.privateInsurance
        privateHealthPremium = try c.decodeIfPresent(Money.self, forKey: .privateHealthPremium) ?? .zero
        privateCarePremium = try c.decodeIfPresent(Money.self, forKey: .privateCarePremium) ?? .zero
        birthYear = try c.decodeIfPresent(Int.self, forKey: .birthYear)
        monthlyAllowance = try c.decodeIfPresent(Money.self, forKey: .monthlyAllowance) ?? .zero
        pensionConversion = try c.decodeIfPresent(Money.self, forKey: .pensionConversion) ?? .zero
        companyCar = try c.decodeIfPresent(CompanyCar.self, forKey: .companyCar)
        companyBike = try c.decodeIfPresent(CompanyBike.self, forKey: .companyBike)
        oneOffPayment = try c.decodeIfPresent(Money.self, forKey: .oneOffPayment) ?? .zero
        oneOffMonth = try c.decodeIfPresent(Int.self, forKey: .oneOffMonth) ?? d.oneOffMonth
        pensionBenefit = try c.decodeIfPresent(Money.self, forKey: .pensionBenefit) ?? .zero
        pensionBenefitStartYear =
            try c.decodeIfPresent(Int.self, forKey: .pensionBenefitStartYear) ?? d.pensionBenefitStartYear
        shortTimeGross = try c.decodeIfPresent(Money.self, forKey: .shortTimeGross)
        year = try c.decodeIfPresent(Int.self, forKey: .year) ?? d.year
    }

    /// Health cover is private for civil servants, or when chosen.
    public var isPrivatelyInsured: Bool { status == .civilServant || privateInsurance }
}
public struct Deduction: Sendable, Equatable, Hashable {
    public enum Kind: String, Sendable, CaseIterable {
        case incomeTax
        case solidaritySurcharge
        case churchTax
        case healthInsurance
        case careInsurance
        case pensionInsurance
        case unemploymentInsurance
        /// Private health and care premiums minus the employer's subsidy.
        case privateInsurance
        /// Salary converted into a company pension.
        case companyPension
        /// Leasing rate of a company bike, taken from the gross.
        case bikeLeasing
        /// The employee's own payment for the company car.
        case carCoPayment
        /// Trade tax of a self-employed trade business.
        case tradeTax
        /// Contribution to a basic pension contract (Rürup) of a self-employed person.
        case basicPension
    }

    public var kind: Kind
    public var amount: Money

    public init(_ kind: Kind, _ amount: Money) {
        self.kind = kind
        self.amount = amount
    }
}
public struct OneOffPay: Sendable, Equatable {
    public var gross: Money
    public var deductions: [Deduction]

    public init(gross: Money, deductions: [Deduction]) {
        self.gross = gross
        self.deductions = deductions
    }

    public var net: Money { gross - deductions.map(\.amount).sum() }

    public func amount(of kind: Deduction.Kind) -> Money {
        deductions.first { $0.kind == kind }?.amount ?? .zero
    }
}
public struct PayResult: Sendable, Equatable {
    /// Gross salary paid out, without non-cash benefits.
    public var gross: Money
    public var deductions: [Deduction]
    /// Non-cash benefits (company car, bike) that are taxed but not paid out.
    public var taxableBenefit: Money
    /// Short-time work allowance paid on top (tax-free).
    public var shortTimeAllowance: Money
    /// Start-up grant of the employment agency paid on top (tax-free), for the self-employed.
    public var startupGrant: Money
    public var oneOff: OneOffPay?

    public init(
        gross: Money, deductions: [Deduction], taxableBenefit: Money = .zero, oneOff: OneOffPay? = nil,
        shortTimeAllowance: Money = .zero, startupGrant: Money = .zero
    ) {
        self.gross = gross
        self.deductions = deductions
        self.taxableBenefit = taxableBenefit
        self.shortTimeAllowance = shortTimeAllowance
        self.startupGrant = startupGrant
        self.oneOff = oneOff
    }

    public var net: Money { gross - deductions.map(\.amount).sum() + shortTimeAllowance + startupGrant }

    public func amount(of kind: Deduction.Kind) -> Money {
        deductions.first { $0.kind == kind }?.amount ?? .zero
    }
}
public protocol NetPayCalculator: Sendable {
    /// Calendar years with official parameters.
    var supportedYears: [Int] { get }
    func calculate(_ input: PayInput) -> PayResult
}
extension NetPayCalculator {
    /// The smallest gross salary whose net pay reaches `targetNet`, found by bisection on cents.
    /// Returns nil if even ten times the target does not reach it.
    public func grossNeeded(forNet targetNet: Money, _ input: PayInput) -> PayResult? {
        guard targetNet.cents > 0 else { return nil }
        func result(_ cents: Int64) -> PayResult {
            var copy = input
            copy.gross = Money(cents: cents)
            return calculate(copy)
        }
        var low = targetNet.cents
        var high = targetNet.cents * 10
        guard result(high).net >= targetNet else { return nil }
        if result(low).net >= targetNet { return result(low) }
        while high - low > 1 {
            let middle = (low + high) / 2
            if result(middle).net >= targetNet { high = middle } else { low = middle }
        }
        return result(high)
    }
}
