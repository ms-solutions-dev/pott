import CloudKit
import CoreData
import Foundation

/// Owns the Core Data stack: a private store for personal data and, with iCloud, a shared store
/// for households owned by someone else.
public final class Persistence: @unchecked Sendable {
    /// Where the data lives.
    public enum Mode: Sendable {
        /// Nothing is written to disk. For tests and previews.
        case inMemory
        /// SQLite files in `directory`, no iCloud.
        case local(directory: URL)
        /// SQLite files in `directory`, synced with the given iCloud container.
        case cloud(containerIdentifier: String, directory: URL)
    }

    public let container: NSPersistentCloudKitContainer
    /// Personal data and households this user owns.
    public let privateStore: NSPersistentStore
    /// Households shared with this user by someone else. Nil without iCloud.
    public let sharedStore: NSPersistentStore?
    /// The iCloud container, nil without iCloud.
    public let cloudContainerIdentifier: String?

    public init(mode: Mode) throws {
        let container = NSPersistentCloudKitContainer(name: "Pott", managedObjectModel: PottModel.shared)
        var descriptions: [NSPersistentStoreDescription] = []
        switch mode {
        case .inMemory:
            let description = NSPersistentStoreDescription(url: URL(fileURLWithPath: "/dev/null"))
            description.configuration = nil
            descriptions = [description]
        case .local(let directory):
            descriptions = [Self.description(directory.appendingPathComponent("private.sqlite"))]
        case .cloud(let identifier, let directory):
            let personal = Self.description(directory.appendingPathComponent("private.sqlite"))
            personal.cloudKitContainerOptions = Self.options(identifier, scope: .private)
            let shared = Self.description(directory.appendingPathComponent("shared.sqlite"))
            shared.cloudKitContainerOptions = Self.options(identifier, scope: .shared)
            descriptions = [personal, shared]
        }
        container.persistentStoreDescriptions = descriptions

        var failure: Error?
        container.loadPersistentStores { _, error in
            if let error { failure = error }
        }
        if let failure { throw failure }

        // Match the stores by file, the load order is not guaranteed.
        let stores = container.persistentStoreCoordinator.persistentStores
        let shared = stores.first { $0.url?.lastPathComponent == "shared.sqlite" }
        guard let personal = stores.first(where: { $0 !== shared }) else {
            throw CocoaError(.persistentStoreOpen)
        }
        self.container = container
        self.privateStore = personal
        self.sharedStore = shared
        if case .cloud(let identifier, _) = mode {
            cloudContainerIdentifier = identifier
        } else {
            cloudContainerIdentifier = nil
        }

        let context = container.viewContext
        context.automaticallyMergesChangesFromParent = true
        context.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        context.name = "view"
    }

    private static func description(_ url: URL) -> NSPersistentStoreDescription {
        let description = NSPersistentStoreDescription(url: url)
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(
            true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        return description
    }

    private static func options(
        _ identifier: String, scope: CKDatabase.Scope
    ) -> NSPersistentCloudKitContainerOptions {
        let options = NSPersistentCloudKitContainerOptions(containerIdentifier: identifier)
        options.databaseScope = scope
        return options
    }
}
