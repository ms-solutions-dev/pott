import Foundation

/// A statutory health insurer and its additional contribution rate (Zusatzbeitrag).
public struct HealthInsurer: Sendable, Equatable, Hashable, Decodable, Identifiable {
    /// Where the insurer can be chosen.
    public enum Scope: String, Sendable, Codable {
        case nationwide
        /// Only in the listed states.
        case states
        /// Only for employees of the company (Betriebskrankenkasse closed to others).
        case company
        /// Only for one sector; the SVLFG for agriculture.
        case sector
    }

    public var name: String
    /// Additional contribution in percent; nil when the insurer collects none (SVLFG).
    public var additionalRate: Decimal?
    public var scope: Scope
    /// State codes ("BY", "NW" …) when `scope` is `.states`.
    public var states: [String]
    public var homepage: String?

    public var id: String { name }

    enum CodingKeys: String, CodingKey { case name, additionalRate, scope, states, homepage }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        additionalRate = try c.decodeIfPresent(Double.self, forKey: .additionalRate).map(exactDecimal)
        scope = try c.decode(Scope.self, forKey: .scope)
        states = try c.decode([String].self, forKey: .states)
        homepage = try c.decodeIfPresent(String.self, forKey: .homepage)
    }

    /// Whether someone living in `region` can join; company and sector insurers count as
    /// open, since whether they apply depends on the job, not the state.
    public func isOpen(in region: String) -> Bool {
        scope != .states || states.contains(region)
    }

    /// Short letters for a badge: AOK, IKK, or the first letters of the distinctive word.
    public var monogram: String {
        if name.hasPrefix("AOK") { return "AOK" }
        if name.hasPrefix("IKK") { return "IKK" }
        let isCompanyFund =
            name.range(of: "BKK", options: .caseInsensitive) != nil
            || name.localizedCaseInsensitiveContains("Betriebskrankenkasse")
        var rest = name
        for prefix in ["Betriebskrankenkasse ", "BKK_", "BKK-", "BKK "] where rest.hasPrefix(prefix) {
            rest = String(rest.dropFirst(prefix.count))
        }
        let words = rest.split { !$0.isLetter && !$0.isNumber }
        guard let first = words.first else { return "BKK" }
        let startsWithBKK = name.uppercased().hasPrefix("BKK")
        return String(first.prefix(isCompanyFund && !startsWithBKK ? 2 : 3)).uppercased()
    }
}

/// The insurers of one year as bundled with the app, with where the data comes from.
public struct HealthInsurerList: Sendable, Equatable, Decodable {
    /// The average additional contribution the Federal Ministry of Health sets for a year
    /// (§ 242a SGB V), with its source.
    public struct Average: Sendable, Equatable, Decodable {
        public var rate: Decimal
        public var source: String
        public var note: String

        enum CodingKeys: String, CodingKey { case rate, source, note }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            rate = exactDecimal(try c.decode(Double.self, forKey: .rate))
            source = try c.decode(String.self, forKey: .source)
            note = try c.decode(String.self, forKey: .note)
        }
    }

    public var year: Int
    /// The day the rates were valid on, as printed by the source ("Stand").
    public var asOf: String
    public var retrieved: String
    public var source: String
    public var sourceNote: String
    /// Averages by year ("2026": …).
    public var averages: [String: Average]
    public var insurers: [HealthInsurer]

    /// The average for a year, if known.
    public func average(for year: Int) -> Average? { averages[String(year)] }

    /// `asOf` as a date (midnight UTC), for display.
    public var asOfDate: Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.date(from: asOf)
    }

    /// Years with a bundled file.
    public static let bundledYears: [Int] = {
        let urls = Bundle.module.urls(forResourcesWithExtension: "json", subdirectory: "HealthInsurers") ?? []
        return urls.compactMap {
            Int($0.deletingPathExtension().lastPathComponent.split(separator: "-").last ?? "")
        }
        .sorted()
    }()

    /// The bundled list for `year`; nil if there is none for that year.
    public static func bundled(year: Int) -> HealthInsurerList? {
        guard
            let url = Bundle.module.url(
                forResource: "health-insurers-\(year)", withExtension: "json", subdirectory: "HealthInsurers"),
            let data = try? Data(contentsOf: url)
        else { return nil }
        return try? JSONDecoder().decode(HealthInsurerList.self, from: data)
    }

    /// The list to use for `year`: its own, or the latest earlier one until the new rates are
    /// published (insurers announce them in January). `isFromEarlierYear` tells the app to say so.
    public static func forYear(_ year: Int) -> (list: HealthInsurerList, isFromEarlierYear: Bool)? {
        guard let best = bundledYears.last(where: { $0 <= year }) ?? bundledYears.first,
            let list = bundled(year: best)
        else { return nil }
        return (list, best != year)
    }

    /// The insurer of that name, if it is in the list.
    public func insurer(named name: String) -> HealthInsurer? {
        insurers.first { $0.name == name }
    }

    /// Insurers matching a search text, ignoring case, accents, spaces and punctuation; common
    /// short names (TK, DAK …) find their insurer too.
    public func search(_ text: String, openIn region: String? = nil) -> [HealthInsurer] {
        let query = Self.normalized(text)
        let alias = Self.aliases[query]
        let found = insurers.filter { insurer in
            (region.map { insurer.isOpen(in: $0) } ?? true)
                && (query.isEmpty || Self.normalized(insurer.name).contains(query) || alias == insurer.name)
        }
        // The insurer a short name stands for comes first.
        return found.filter { $0.name == alias } + found.filter { $0.name != alias }
    }

    static let aliases: [String: String] = [
        "tk": "Techniker Krankenkasse", "kkh": "Kaufmännische Krankenkasse - KKH",
        "sbk": "Siemens-Betriebskrankenkasse (SBK)", "hkk": "Handelskrankenkasse (hkk)",
        "dak": "DAK-Gesundheit",
        "svlfg": "Sozialversicherung für Landwirtschaft, Forsten und Gartenbau (SVLFG)",
    ]

    static func normalized(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "de_DE"))
            .filter { $0.isLetter || $0.isNumber }
    }
}

/// A percentage from JSON as the decimal it was written as: 2.98 stays 2.98, not 2.97999….
func exactDecimal(_ value: Double) -> Decimal {
    Decimal(string: "\(value)", locale: Locale(identifier: "en_US_POSIX")) ?? Decimal(value)
}
