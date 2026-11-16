import CloudKit
import PottCore
import PottDesign
import PottFeatures
import SwiftUI

/// Inviting members through iCloud, and telling the app who you are after joining.
struct HouseholdSharingSection: View {
    @Environment(AppModel.self) private var model
    @State private var sharing: SharingSheet?
    @State private var preparing = false
    @State private var askName = false
    @State private var newName = ""

    struct SharingSheet: Identifiable {
        let id = UUID()
        var share: CKShare
        var container: CKContainer
    }

    var body: some View {
        if model.needsIdentity, let household = model.household {
            Section {
                ForEach(household.members) { member in
                    Button {
                        model.claim(member)
                    } label: {
                        Label("I am \(member.name)", systemImage: "person.crop.circle")
                    }
                }
                Button {
                    askName = true
                } label: {
                    Label("I am new in this household", systemImage: "person.badge.plus")
                }
            } header: {
                Text("Who are you?")
            } footer: {
                Text("You joined a shared household. Pick yourself so Pott can work out your share.")
            }
            .alert("Your name", isPresented: $askName) {
                TextField("Name", text: $newName)
                Button("Cancel", role: .cancel) {}
                Button("Join") {
                    model.joinAsNewMember(named: newName.isEmpty ? String(localized: "Me") : newName)
                }
            }
        }
        if model.householdActive {
            Section {
                if model.isCloudEnabled {
                    Button {
                        Task { await openSharing() }
                    } label: {
                        Label(
                            model.isHouseholdShared ? "Manage sharing" : "Invite through iCloud",
                            systemImage: model.isHouseholdShared
                                ? "person.2.fill" : "person.crop.circle.badge.plus")
                    }
                    .disabled(preparing)
                } else {
                    Label("Sign in to iCloud to share the household", systemImage: "icloud.slash")
                        .foregroundStyle(Palette.secondaryText.color)
                }
            } header: {
                Text("Sharing")
            } footer: {
                Text(
                    model.isHouseholdJoined
                        ? "This household was shared with you. Your personal entries stay private."
                        : "Everyone invited sees and edits the shared costs and goals. Personal entries stay private. All members need an iPhone with iCloud."
                )
            }
            .sheet(item: $sharing) { sheet in
                CloudSharingView(share: sheet.share, container: sheet.container) { share in
                    Task { await model.shareDidChange(share) }
                }
                .ignoresSafeArea()
            }
        }
    }

    private func openSharing() async {
        preparing = true
        defer { preparing = false }
        do {
            let result = try await model.shareHousehold(title: String(localized: "Our household in Pott"))
            sharing = SharingSheet(share: result.share, container: result.container)
        } catch {
            model.failure = error.localizedDescription
        }
    }
}
