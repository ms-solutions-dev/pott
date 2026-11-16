import PottCore
import PottDesign
import PottFeatures
import PottStore
import SwiftUI
import WidgetKit

/// Entry point of the app.
@main
struct PottApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var model: AppModel
    @State private var router = Router()
    @State private var toasts = ToastCenter()

    /// The iCloud container; its name never changes, CloudKit keeps containers forever.
    static let cloudContainer = "iCloud.dev.ms-solutions.pott"
    /// Shared with the widget, which reads the same store.
    static let appGroup = "group.dev.ms-solutions.pott"

    init() {
        PottFonts.register()
        let demo = DemoData.model(for: ProcessInfo.processInfo.arguments)
        let model = demo ?? AppModel(repository: Self.openRepository(), settings: AppSettings())
        _model = State(initialValue: model)
        AppDelegate.model = model
        if demo == nil {
            model.onBudgetChange = Self.budgetChanged
            Self.budgetChanged(model)
        }
    }

    /// The real store; `-PottInitCloudSchema` (debug builds) also creates the CloudKit schema.
    @MainActor
    private static func openRepository() -> Repository {
        let repository = Repository(persistence: openStore())
        #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-PottInitCloudSchema") {
                do {
                    try repository.initializeCloudSchema()
                    print("CloudKit schema initialized")
                } catch {
                    print("CloudKit schema failed: \(error)")
                }
            }
        #endif
        // Test builds use CloudKit's development environment and create the schema there once, since
        // a simulator without iCloud cannot. Store builds use production, where this never runs.
        let environment = Bundle.main.object(forInfoDictionaryKey: "PottCloudEnvironment") as? String
        if environment == "Development", !UserDefaults.standard.bool(forKey: "cloudSchemaReady-1") {
            repository.initializeCloudSchemaInBackground { succeeded in
                if succeeded { UserDefaults.standard.set(true, forKey: "cloudSchemaReady-1") }
            }
        }
        return repository
    }

    /// Keeps the widget and the contract reminders in step with the data.
    private static func budgetChanged(_ model: AppModel) {
        let personal = model.budget.personal
        let snapshot = WidgetSnapshot(
            leftCents: personal.left.cents, incomeCents: personal.income.cents,
            ratio: (personal.leftRatio as NSDecimalNumber).doubleValue, hasIncome: personal.income.cents > 0,
            currencyCode: Money.currencyCode, updated: .now)
        if snapshot.write() { WidgetCenter.shared.reloadAllTimelines() }
        Reminders.update(for: model)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(Palette.accentText.color)
                .environment(model)
                .environment(router)
                .environment(toasts)
        }
    }

    /// Opens the store in the app group (so the widget can read it) and syncs it with iCloud;
    /// without iCloud it still works locally. Falls back to memory so the app starts and can
    /// show what went wrong.
    private static func openStore() -> Persistence {
        let base =
            FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
            ?? URL.applicationSupportDirectory
        let directory = base.appending(path: "Pott", directoryHint: .isDirectory)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            return try Persistence(mode: .cloud(containerIdentifier: cloudContainer, directory: directory))
        } catch {
            guard let fallback = try? Persistence(mode: .inMemory) else { fatalError("No store: \(error)") }
            return fallback
        }
    }
}
