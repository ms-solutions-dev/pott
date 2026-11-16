import Foundation
import PottCore

/// Optional parts of the app. A module that is off shows nothing anywhere.
public enum FeatureModule: String, CaseIterable, Codable, Sendable {
    case household
    case savings
    case calculator
    case monthlyReview
    case contractReminders
    case explanations
}

/// How fixed costs are listed.
public enum CostSort: String, CaseIterable, Codable, Sendable {
    case category
    case amount
    case dueDate
}

public enum Appearance: String, CaseIterable, Codable, Sendable {
    case system
    case light
    case dark
}

/// A category the user added.
public struct CustomCategory: Identifiable, Hashable, Codable, Sendable {
    public var id: CategoryID
    public var name: String

    public init(id: CategoryID = CategoryID(rawValue: "custom-\(UUID().uuidString)"), name: String) {
        self.id = id
        self.name = name
    }
}

/// Preferences of this device, stored in `UserDefaults`.
@MainActor
@Observable
public final class AppSettings {
    @ObservationIgnored private let defaults: UserDefaults

    public var modules: Set<FeatureModule> { didSet { store(modules.map(\.rawValue).sorted(), "modules") } }
    public var sort: CostSort { didSet { store(sort.rawValue, "sort") } }
    public var appearance: Appearance { didSet { store(appearance.rawValue, "appearance") } }
    public var requiresFaceID: Bool { didSet { store(requiresFaceID, "requiresFaceID") } }
    public var hasOnboarded: Bool { didSet { store(hasOnboarded, "hasOnboarded") } }
    /// The one-time hint about swipe gestures was dismissed.
    public var hasSeenSwipeHint: Bool { didSet { store(hasSeenSwipeHint, "hasSeenSwipeHint") } }
    /// Palette index per category; see `PottDesign.Palette.categories`.
    public var categoryColors: [String: Int] { didSet { store(categoryColors, "categoryColors") } }
    public var customCategories: [CustomCategory] { didSet { encode(customCategories, "customCategories") } }
    /// The household member that is this user.
    public var meMemberID: UUID? { didSet { store(meMemberID?.uuidString, "meMemberID") } }
    /// The last inputs of the pay calculator, so it opens where the user left it.
    public var payInput: PayInput { didSet { encode(payInput, "payInput") } }
    /// The calculator shows the self-employed view instead of the employee one.
    public var calculatorSelfEmployed: Bool {
        didSet { store(calculatorSelfEmployed, "calculatorSelfEmployed") }
    }
    /// The last inputs of the self-employed view.
    public var selfEmployedInput: SelfEmployedInput {
        didSet { encode(selfEmployedInput, "selfEmployedInput") }
    }

    /// Default palette indices of the built-in categories.
    public static let defaultColors: [CategoryID: Int] = [
        .housing: 0, .energy: 1, .subscriptions: 2, .mobility: 3, .insurance: 4, .everyday: 5,
    ]

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.stringArray(forKey: "modules")
        modules =
            stored.map { Set($0.compactMap(FeatureModule.init(rawValue:))) } ?? [.calculator, .explanations]
        sort = CostSort(rawValue: defaults.string(forKey: "sort") ?? "") ?? .category
        appearance = Appearance(rawValue: defaults.string(forKey: "appearance") ?? "") ?? .system
        requiresFaceID = defaults.bool(forKey: "requiresFaceID")
        hasOnboarded = defaults.bool(forKey: "hasOnboarded")
        hasSeenSwipeHint = defaults.bool(forKey: "hasSeenSwipeHint")
        categoryColors = defaults.dictionary(forKey: "categoryColors") as? [String: Int] ?? [:]
        customCategories =
            (defaults.data(forKey: "customCategories")).flatMap {
                try? JSONDecoder().decode([CustomCategory].self, from: $0)
            } ?? []
        meMemberID = defaults.string(forKey: "meMemberID").flatMap(UUID.init(uuidString:))
        payInput =
            defaults.data(forKey: "payInput").flatMap { try? JSONDecoder().decode(PayInput.self, from: $0) }
            ?? PayInput(gross: Money(units: 3000))
        calculatorSelfEmployed = defaults.bool(forKey: "calculatorSelfEmployed")
        selfEmployedInput =
            defaults.data(forKey: "selfEmployedInput").flatMap {
                try? JSONDecoder().decode(SelfEmployedInput.self, from: $0)
            } ?? SelfEmployedInput(monthlyProfit: Money(units: 4000))
    }

    public func isOn(_ module: FeatureModule) -> Bool {
        modules.contains(module)
    }

    public func set(_ module: FeatureModule, _ on: Bool) {
        if on { modules.insert(module) } else { modules.remove(module) }
    }

    /// Palette index of a category.
    public func colorIndex(of category: CategoryID) -> Int {
        categoryColors[category.rawValue] ?? Self.defaultColors[category] ?? 6
    }

    /// All categories in display order: built-in first, then custom ones.
    public var categories: [CategoryID] {
        CategoryID.builtIn + customCategories.map(\.id)
    }

    private func store(_ value: Any?, _ key: String) {
        defaults.set(value, forKey: key)
    }

    private func encode<T: Encodable>(_ value: T, _ key: String) {
        defaults.set(try? JSONEncoder().encode(value), forKey: key)
    }
}
