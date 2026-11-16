import PottCore
import PottDesign
import PottFeatures
import SwiftUI
import UniformTypeIdentifiers

/// Modules, household, categories, display, security and data.
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var askNames = false
    @State private var confirmLeave = false
    @State private var myName = ""
    @State private var partnerName = ""

    var body: some View {
        @Bindable var settings = model.settings
        NavigationStack {
            Form {
                Section {
                    Picker("View", selection: viewModeBinding) {
                        Text("Simple").tag(ViewMode.simple)
                        Text("Full").tag(ViewMode.full)
                        if viewMode == .custom { Text("Custom").tag(ViewMode.custom) }
                    }
                    .pickerStyle(.segmented)
                } footer: {
                    Text("Simple shows income, fixed costs and what is left. Full switches every module on.")
                }

                Section {
                    Toggle(isOn: householdBinding) {
                        title("Household", "Shared pot with partner or flatmates")
                    }
                    Toggle(isOn: moduleBinding(.savings)) {
                        title("Savings goals", "Goals like a holiday with a monthly rate")
                    }
                    Toggle(isOn: moduleBinding(.calculator)) {
                        title("Pay calculator", "Gross to net, second tab")
                    }
                    Toggle(isOn: moduleBinding(.monthlyReview)) {
                        title("Monthly review", "What was left in past months")
                    }
                    Toggle(isOn: remindersBinding) {
                        title("Contract reminders", "Notice before a contract renews")
                    }
                    Toggle(isOn: moduleBinding(.explanations)) {
                        title("Explanations", "Short help on taxes and terms")
                    }
                } header: {
                    Text("Modules")
                } footer: {
                    Text("All off is the simple view: income, fixed costs and what is left.")
                }

                if model.householdActive, let household = model.household {
                    Section("Household") {
                        ForEach(household.members) { member in
                            MemberNameRow(member: member, isMe: member.id == model.settings.meMemberID)
                        }
                        .onDelete { offsets in
                            for index in offsets
                            where household.members[index].id != model.settings.meMemberID {
                                model.delete(household.members[index])
                            }
                        }
                        Button {
                            model.save(Member(name: String(localized: "Flatmate"), sharePercent: 0))
                        } label: {
                            Label("Add member", systemImage: "person.badge.plus")
                        }
                    }
                }

                HouseholdSharingSection()

                Section("Categories & colors") {
                    ForEach(model.settings.categories, id: \.self) { category in
                        NavigationLink {
                            CategoryEditor(category: category)
                        } label: {
                            HStack(spacing: 12) {
                                RoundedRectangle(cornerRadius: 8).fill(model.settings.color(of: category))
                                    .frame(width: 30, height: 30)
                                Text(model.settings.name(of: category)).textRole(.body)
                            }
                        }
                    }
                    Button {
                        settings.customCategories.append(
                            CustomCategory(name: String(localized: "New category")))
                    } label: {
                        Label("New category", systemImage: "plus")
                    }
                }

                Section("Display") {
                    Picker("Sort fixed costs by", selection: $settings.sort) {
                        Text("Category").tag(CostSort.category)
                        Text("Amount").tag(CostSort.amount)
                        Text("Due date").tag(CostSort.dueDate)
                    }
                    Picker("Appearance", selection: $settings.appearance) {
                        Text("Like the iPhone").tag(Appearance.system)
                        Text("Light").tag(Appearance.light)
                        Text("Dark").tag(Appearance.dark)
                    }
                    Picker("App icon", selection: iconBinding) {
                        Text("Dark").tag(false)
                        Text("Lime").tag(true)
                    }
                    Toggle("Lock with Face ID", isOn: $settings.requiresFaceID)
                }

                Section {
                    ShareLink(
                        item: CSVExport(text: model.csv { model.settings.name(of: $0) }),
                        preview: SharePreview("Pott.csv")
                    ) {
                        Label("Export as CSV", systemImage: "square.and.arrow.up")
                    }
                    Button {
                        settings.hasOnboarded = false
                        dismiss()
                    } label: {
                        Label("Show the introduction again", systemImage: "sparkles")
                    }
                } header: {
                    Text("Data")
                } footer: {
                    Text(
                        "Your data stays on your devices and in your iCloud. Pott has no account, no ads and no tracking."
                    )
                }

                Section("About") {
                    Link(destination: URL(string: "https://github.com/ms-solutions-dev/pott/issues")!) {
                        Label("Feedback & support", systemImage: "envelope")
                    }
                    LabeledContent("Version", value: Bundle.main.appVersion)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.background.color)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .alert("Who lives in the household?", isPresented: $askNames) {
                TextField("Your name", text: $myName)
                TextField("Partner or flatmate", text: $partnerName)
                Button("Cancel", role: .cancel) {}
                Button("Create") {
                    model.startHousehold(
                        myName: myName.isEmpty ? String(localized: "Me") : myName,
                        partnerName: partnerName.isEmpty ? String(localized: "Partner") : partnerName)
                    model.syncMyIncome()
                }
            } message: {
                Text("You can add more members later.")
            }
            .confirmationDialog(
                "Turn off the household?", isPresented: $confirmLeave, titleVisibility: .visible
            ) {
                Button("Turn off", role: .destructive) { model.settings.set(.household, false) }
            } message: {
                Text(
                    "All shared costs then count as yours. Nothing is deleted; turning it on again restores the shared view."
                )
            }
        }
    }

    private var householdBinding: Binding<Bool> {
        Binding(
            get: { model.settings.isOn(.household) },
            set: { on in
                if on {
                    if model.household == nil {
                        askNames = true
                    } else {
                        model.settings.set(.household, true)
                    }
                } else {
                    confirmLeave = true
                }
            })
    }

    enum ViewMode: Hashable {
        case simple
        case full
        case custom
    }

    private static let simpleModules: Set<FeatureModule> = [.calculator, .explanations]

    private var viewMode: ViewMode {
        let modules = model.settings.modules
        if modules.isSubset(of: Self.simpleModules) { return .simple }
        let all = Set(FeatureModule.allCases).subtracting(model.household == nil ? [.household] : [])
        return modules.isSuperset(of: all) ? .full : .custom
    }

    /// One switch for "simple" and "everything"; the household only comes on if it exists, since it
    /// needs names first. Nothing is deleted either way.
    private var viewModeBinding: Binding<ViewMode> {
        Binding(
            get: { viewMode },
            set: { mode in
                switch mode {
                case .simple: model.settings.modules = Self.simpleModules
                case .full:
                    var all = Set(FeatureModule.allCases)
                    if model.household == nil { all.remove(.household) }
                    model.settings.modules = all
                    Task {
                        _ = await Reminders.requestPermission()
                        Reminders.update(for: model)
                    }
                case .custom: break
                }
            })
    }

    /// Switches between the dark icon and the lime alternative.
    private var iconBinding: Binding<Bool> {
        Binding(
            get: { UIApplication.shared.alternateIconName == "AppIconLight" },
            set: { lime in
                Task { try? await UIApplication.shared.setAlternateIconName(lime ? "AppIconLight" : nil) }
            })
    }

    /// Asks for notification permission when reminders are switched on.
    private var remindersBinding: Binding<Bool> {
        Binding(
            get: { model.settings.isOn(.contractReminders) },
            set: { on in
                model.settings.set(.contractReminders, on)
                Task {
                    if on { _ = await Reminders.requestPermission() }
                    Reminders.update(for: model)
                }
            })
    }

    private func moduleBinding(_ module: FeatureModule) -> Binding<Bool> {
        Binding(get: { model.settings.isOn(module) }, set: { model.settings.set(module, $0) })
    }

    private func title(_ title: LocalizedStringKey, _ detail: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).textRole(.bodyStrong)
            Text(detail).textRole(.caption).foregroundStyle(Palette.secondaryText.color)
        }
    }
}

private struct MemberNameRow: View {
    @Environment(AppModel.self) private var model
    var member: Member
    var isMe: Bool
    @State private var name = ""

    var body: some View {
        HStack {
            TextField("Name", text: $name)
                .textRole(.body)
                .onAppear { name = member.name }
                .onSubmit { rename() }
            if isMe { Text("You").textRole(.caption).foregroundStyle(Palette.secondaryText.color) }
        }
        .onDisappear { rename() }
    }

    private func rename() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed != member.name else { return }
        var updated = member
        updated.name = trimmed
        model.save(updated)
    }
}

/// Color (and for own categories the name) of a category.
private struct CategoryEditor: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var category: CategoryID
    @State private var name = ""

    private var isCustom: Bool { !CategoryID.builtIn.contains(category) }

    var body: some View {
        @Bindable var settings = model.settings
        Form {
            if isCustom {
                Section("Name") {
                    TextField("Name", text: $name)
                        .onAppear { name = model.settings.name(of: category) }
                        .onChange(of: name) { _, value in
                            if let index = settings.customCategories.firstIndex(where: { $0.id == category })
                            {
                                settings.customCategories[index].name = value
                            }
                        }
                }
            }
            Section("Color") {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10
                ) {
                    ForEach(Palette.categories.indices, id: \.self) { index in
                        let selected = model.settings.colorIndex(of: category) == index
                        Button {
                            settings.categoryColors[category.rawValue] = index
                        } label: {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Palette.category(index).color)
                                .frame(height: 52)
                                .overlay {
                                    if selected {
                                        Image(systemName: "checkmark").font(.title3.bold()).foregroundStyle(
                                            .white)
                                    }
                                }
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12).strokeBorder(
                                        Palette.text.color, lineWidth: selected ? 3 : 0))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("Color \(index + 1)"))
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
                .padding(.vertical, 6)
            }
            if isCustom {
                Section {
                    Button("Delete category", role: .destructive) {
                        settings.customCategories.removeAll { $0.id == category }
                        dismiss()
                    }
                } footer: {
                    Text("Fixed costs of this category stay and are listed under “Other”.")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.background.color)
        .navigationTitle(model.settings.name(of: category))
    }
}

/// The CSV file handed to the share sheet.
struct CSVExport: Transferable {
    var text: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .commaSeparatedText) { Data($0.text.utf8) }
            .suggestedFileName("Pott.csv")
    }
}

extension Bundle {
    var appVersion: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}
