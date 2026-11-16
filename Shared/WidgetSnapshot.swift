import Foundation

/// What the widget shows, written by the app into the app group after every change.
///
/// The widget never opens the database: two processes syncing the same CloudKit store would
/// compete. A small file is enough for one number and a ring.
struct WidgetSnapshot: Codable, Equatable {
    /// What is left this month, in cents. Negative when short.
    var leftCents: Int64
    var incomeCents: Int64
    /// Share of the income that is left, 0…1.
    var ratio: Double
    var hasIncome: Bool
    var currencyCode: String
    var updated: Date

    static let appGroup = "group.dev.ms-solutions.pott"
    static let placeholder = WidgetSnapshot(
        leftCents: 98_700, incomeCents: 224_000, ratio: 0.44, hasIncome: true, currencyCode: "EUR",
        updated: .now)

    private static var url: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appending(path: "widget.json")
    }

    static func read() -> WidgetSnapshot? {
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    /// Writes the snapshot; returns true when it changed, so the caller reloads the widget only then.
    @discardableResult
    func write() -> Bool {
        guard let url = Self.url else { return false }
        var unchanged = self
        unchanged.updated = Self.read()?.updated ?? updated
        if Self.read() == unchanged { return false }
        guard let data = try? JSONEncoder().encode(self) else { return false }
        return (try? data.write(to: url, options: .atomic)) != nil
    }

    func amount(_ cents: Int64) -> String {
        let value = Decimal(cents) / 100
        let whole = cents % 100 == 0
        return value.formatted(.currency(code: currencyCode).precision(.fractionLength(whole ? 0 : 2)))
    }
}
