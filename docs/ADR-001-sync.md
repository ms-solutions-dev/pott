# ADR-001: Persistence and sharing

Status: accepted · 2026-10-31

## Context

Pott stores everything on the device and syncs through the user's iCloud account. A household is shared between two or more people (couples, flatmates), each with their own Apple ID. Some data must stay private to one member (personal income, personal fixed costs, personal savings goals), other data belongs to the household (shared costs, the household pot, shared savings goals, the split rule).

So the store needs **two CloudKit scopes**: the private database for personal data and the shared database for households another member owns.

## Options

1. **SwiftData.** `ModelConfiguration.CloudKitDatabase` in the iOS 27 SDK offers `.automatic`, `.none` and `.private(_:)`. There is no shared scope and no API to create or accept a `CKShare`. Sharing between Apple IDs is not possible.
2. **Core Data with `NSPersistentCloudKitContainer`.** Supports a private and a shared persistent store side by side (`databaseScope = .shared`), `share(_:to:)`, `acceptShareInvitations(from:into:)`, participant management and `UICloudSharingController` since iOS 15. Apple ships sample code for exactly this case.
3. **`CKSyncEngine` with a custom local store.** Full control, but conflict handling, change tokens, zone management and the share lifecycle would all be ours to write and test.

## Decision

Option 2: **Core Data with `NSPersistentCloudKitContainer`**, one private and one shared store, wrapped in the `PottStore` package. The rest of the app never touches Core Data; it works with value types from `PottCore` through repository protocols. If SwiftData gains shared databases later, only `PottStore` changes.

## Consequences

- The data model follows CloudKit rules: every attribute optional or with a default, no unique constraints, all relationships optional with inverses.
- The model is defined in code (`NSManagedObjectModel` built programmatically) so it lives inside a Swift package and stays reviewable in diffs.
- Personal records live in the private store and are never part of a share. Household records live in a zone that is shared with the members.
- Sharing and accepting invitations can only be verified on real devices with two Apple IDs; simulators cover the local store and the domain logic.
