import Foundation
import Testing

@testable import TaxDE

/// Checks the bundled insurer lists, so a broken run of `tools/update_health_insurers.py` (changed
/// page layout, wrong encoding, missing pages) fails here instead of in the app.
@Suite("Health insurer lists")
struct HealthInsurerListTests {
    static let stateCodes: Set<String> = [
        "BW", "BY", "BE", "BB", "HB", "HH", "HE", "MV", "NI", "NW", "RP", "SL", "SN", "ST", "SH", "TH",
    ]

    @Test("Every bundled year decodes and is plausible")
    func allYears() throws {
        #expect(HealthInsurerList.bundledYears.contains(2026))
        for year in HealthInsurerList.bundledYears {
            let list = try #require(HealthInsurerList.bundled(year: year), "\(year)")
            #expect(list.year == year)
            #expect(list.asOfDate != nil, "asOf \(list.asOf)")
            #expect(list.source.hasPrefix("https://www.gkv-spitzenverband.de/"))
            // There were 92 insurers in 2026; mergers lower the number slowly, a parser fault fast.
            #expect((70...130).contains(list.insurers.count), "\(list.insurers.count) insurers")
            #expect(Set(list.insurers.map(\.name)).count == list.insurers.count, "duplicate names")
            #expect(list.average(for: year) != nil, "no average for \(year)")
            for insurer in list.insurers {
                #expect(!insurer.name.isEmpty)
                // Mojibake from reading UTF-8 as Latin-1, or soft hyphens left in.
                #expect(!insurer.name.contains("Ã") && !insurer.name.contains("\u{AD}"), "\(insurer.name)")
                if let rate = insurer.additionalRate {
                    #expect(rate > 0 && rate < 10, "\(insurer.name): \(rate)")
                    var scaled = rate * 100
                    var whole = Decimal()
                    NSDecimalRound(&whole, &scaled, 0, .plain)
                    #expect(scaled == whole, "\(insurer.name): more than two decimals")
                }
                #expect(insurer.scope == .states ? !insurer.states.isEmpty : insurer.states.isEmpty)
                #expect(
                    Set(insurer.states).isSubset(of: Self.stateCodes), "\(insurer.name): \(insurer.states)")
            }
        }
    }

    @Test("2026 as published on 02.11.2026")
    func year2026() throws {
        let list = try #require(HealthInsurerList.bundled(year: 2026))
        #expect(list.insurers.count == 92)
        #expect(list.asOf == "2026-11-02")
        #expect(list.average(for: 2026)?.rate == Decimal(string: "2.9")!)
        let rates = list.insurers.compactMap(\.additionalRate)
        #expect(rates.count == 91)  // the SVLFG collects none
        #expect(rates.min() == Decimal(string: "2.18")!)
        #expect(rates.max() == Decimal(string: "4.39")!)
        #expect(list.insurer(named: "BKK firmus")?.additionalRate == Decimal(string: "2.18")!)
        #expect(list.insurer(named: "BKK24")?.additionalRate == Decimal(string: "4.39")!)
        #expect(list.insurer(named: "BARMER")?.additionalRate == Decimal(string: "3.29")!)
        #expect(list.insurer(named: "Techniker Krankenkasse")?.scope == .nationwide)
        #expect(list.insurer(named: "AOK Bayern - Die Gesundheitskasse")?.states == ["BY"])
        #expect(list.insurer(named: "BMW BKK")?.scope == .company)
        let svlfg = try #require(list.insurers.first { $0.name.contains("SVLFG") })
        #expect(svlfg.additionalRate == nil)
        #expect(svlfg.scope == .sector)
    }

    @Test("Search: short names, accents, region filter")
    func search() throws {
        let list = try #require(HealthInsurerList.bundled(year: 2026))
        #expect(list.search("tk").first?.name == "Techniker Krankenkasse")
        #expect(list.search("Kaufmannische").first?.name == "Kaufmännische Krankenkasse - KKH")
        #expect(list.search("").count == 92)
        let bavaria = list.search("aok", openIn: "BY").map(\.name)
        #expect(bavaria == ["AOK Bayern - Die Gesundheitskasse"])
        #expect(list.search("bkk").count > 30)
    }

    @Test("A later year falls back to the latest list until its own exists")
    func fallback() throws {
        let latest = try #require(HealthInsurerList.bundledYears.last)
        let next = try #require(HealthInsurerList.forYear(latest + 1))
        #expect(next.isFromEarlierYear)
        #expect(next.list.year == latest)
        #expect(HealthInsurerList.forYear(2026)?.isFromEarlierYear == false)
    }

    @Test("Badges")
    func monograms() throws {
        let list = try #require(HealthInsurerList.bundled(year: 2026))
        #expect(list.insurer(named: "AOK Bayern - Die Gesundheitskasse")?.monogram == "AOK")
        #expect(list.insurer(named: "IKK classic")?.monogram == "IKK")
        #expect(list.insurer(named: "BARMER")?.monogram == "BAR")
        #expect(list.insurer(named: "BMW BKK")?.monogram == "BM")
        #expect(list.insurer(named: "BKK firmus")?.monogram == "FIR")
    }
}
