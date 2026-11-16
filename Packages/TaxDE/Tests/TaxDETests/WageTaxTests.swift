import Foundation
import PottCore
import Testing

/// The BMF's test interface results, fetched once into `bmf2026.json`; the tests run offline.
@testable import TaxDE

/// Compares the generated wage tax code with the BMF for every input field the app uses.
enum BMFFixture {
    struct Case: Decodable {
        var input: [String: String]
        var output: [String: Int]
    }

    struct File: Decodable {
        var cases: [Case]
        var scenarios: [String: Case]
    }

    static let file: File = {
        guard
            let url = Bundle.module.url(
                forResource: "bmf2026", withExtension: "json", subdirectory: "Fixtures"),
            let data = try? Data(contentsOf: url),
            let file = try? JSONDecoder().decode(File.self, from: data)
        else { return File(cases: [], scenarios: [:]) }
        return file
    }()

    /// Runs the generated wage tax code with the PAP inputs of a case.
    static func run(_ input: [String: String]) -> Lohnsteuer2026 {
        var tax = Lohnsteuer2026()
        func int(_ key: String) -> Int { Int(input[key] ?? "0") ?? 0 }
        func decimal(_ key: String) -> BigDecimal { BigDecimal(literal: input[key] ?? "0") }
        tax.LZZ = int("LZZ")
        tax.STKL = int("STKL")
        tax.RE4 = decimal("RE4")
        tax.R = int("R")
        tax.ZKF = decimal("ZKF")
        tax.PVZ = int("PVZ")
        tax.PVS = int("PVS")
        tax.PVA = decimal("PVA")
        tax.KVZ = decimal("KVZ")
        tax.KRV = int("KRV")
        tax.ALV = int("ALV")
        tax.PKV = int("PKV")
        tax.PKPV = decimal("PKPV")
        tax.PKPVAGZ = decimal("PKPVAGZ")
        tax.ALTER1 = int("ALTER1")
        tax.AJAHR = int("AJAHR")
        tax.LZZFREIB = decimal("LZZFREIB")
        tax.JFREIB = decimal("JFREIB")
        tax.JRE4 = decimal("JRE4")
        tax.SONSTB = decimal("SONSTB")
        tax.VBEZ = decimal("VBEZ")
        tax.VBEZM = decimal("VBEZM")
        tax.VJAHR = int("VJAHR")
        tax.JVBEZ = decimal("JVBEZ")
        if let af = input["af"] { tax.af = Int(af) ?? 1 }
        if let f = input["f"] { tax.f = Double(f) ?? 1 }
        tax.main()
        return tax
    }

    static func outputs(_ tax: Lohnsteuer2026) -> [(String, BigDecimal)] {
        [
            ("LSTLZZ", tax.LSTLZZ), ("SOLZLZZ", tax.SOLZLZZ), ("BK", tax.BK), ("STS", tax.STS),
            ("SOLZS", tax.SOLZS), ("BKS", tax.BKS),
        ]
    }
}
@Suite("Wage tax 2026 against BMF")
struct WageTaxTests {
    @Test("Fixture is present")
    func present() {
        #expect(BMFFixture.file.cases.count >= 121)
        #expect(BMFFixture.file.scenarios.count >= 16)
    }

    @Test("Every BMF case matches to the cent", arguments: BMFFixture.file.cases.indices)
    func matches(index: Int) {
        let fixture = BMFFixture.file.cases[index]
        let tax = BMFFixture.run(fixture.input)
        for (name, value) in BMFFixture.outputs(tax) {
            guard let expected = fixture.output[name] else { continue }
            #expect(value.longValue() == expected, "\(name) \(fixture.input)")
        }
    }
}
