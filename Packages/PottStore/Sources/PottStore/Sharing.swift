import CloudKit
import CoreData
import Foundation

/// Sharing the household with other iCloud users through `NSPersistentCloudKitContainer`.
///
/// Only the household and what hangs off it (members, shared costs, shared goals) is shared.
/// Personal entries live in other records of the private store and never become part of the share.
extension Repository {
    public enum SharingError: Error {
        case noHousehold
        case noCloud
    }

    /// True when the stores sync with iCloud.
    public var isCloudEnabled: Bool { persistence.sharedStore != nil }

    /// The CloudKit container, for the system sharing sheet.
    public var cloudContainer: CKContainer? {
        persistence.cloudContainerIdentifier.map(CKContainer.init(identifier:))
    }

    /// The existing share of the household, if it is shared.
    public func householdShare() -> CKShare? {
        guard let household = householdObject() else { return nil }
        let shares = try? persistence.container.fetchShares(matching: [household.objectID])
        return shares?[household.objectID]
    }

    /// Shares the household, or returns the existing share.
    public func shareHousehold(title: String) async throws -> CKShare {
        guard isCloudEnabled else { throw SharingError.noCloud }
        guard let household = householdObject() else { throw SharingError.noHousehold }
        if let existing = householdShare() { return existing }
        let (_, share, _) = try await persistence.container.share([household], to: nil)
        share[CKShare.SystemFieldKey.title] = title
        return share
    }

    /// Accepts an invitation the system handed to the app.
    public func accept(_ metadata: CKShare.Metadata) async throws {
        guard let shared = persistence.sharedStore else { throw SharingError.noCloud }
        _ = try await persistence.container.acceptShareInvitations(from: [metadata], into: shared)
    }

    /// Writes changes the sharing sheet made to the share (participants, stop sharing).
    public func persistUpdatedShare(_ share: CKShare) async throws {
        guard let household = householdObject(), let store = household.objectID.persistentStore else {
            return
        }
        _ = try await persistence.container.persistUpdatedShare(share, in: store)
    }
}
