import PottCore
import PottDesign
import PottFeatures
import SwiftUI

/// Creates or edits a fixed cost, including its note (contract number, customer number, …).
struct CostEditor: View {
    @Environment(AppModel.self) private var model
    @Environment(ToastCenter.self) private var toasts
    let original: FixedCost?
    @State private var name: String
    @State private var amount: String
    @State private var recurrence: Recurrence
    @State private var dueDay: Int
    /// No category is preselected for a new cost, so rent does not end up under subscriptions.
    @State private var category: CategoryID?
    @State private var scope: Scope
    @State private var note: String
    @State private var isPaused: Bool
    @State private var hasContractEnd: Bool
    @State private var contractEnd: Date
    @State private var noticeDays: Int

    init(cost: FixedCost?, defaultScope: Scope) {
        original = cost
        _name = State(initialValue: cost?.name ?? "")
        _amount = State(initialValue: cost?.amount.editingText() ?? "")
        _recurrence = State(initialValue: cost?.recurrence ?? .monthly)
        _dueDay = State(initialValue: cost?.dueDay ?? 1)
        _category = State(initialValue: cost?.category)
        _scope = State(initialValue: cost?.scope ?? defaultScope)
        _note = State(initialValue: cost?.note ?? "")
        _isPaused = State(initialValue: cost?.isPaused ?? false)
        _hasContractEnd = State(initialValue: cost?.contractEnd != nil)
        _contractEnd = State(
            initialValue: cost?.contractEnd ?? Calendar.current.date(byAdding: .year, value: 1, to: .now)
                ?? .now)
        _noticeDays = State(initialValue: cost?.noticePeriodDays ?? 30)
    }

    private var parsed: Money? { Money.parse(amount).flatMap { $0.cents > 0 ? $0 : nil } }

    var body: some View {
        EditorSheet(
            title: original == nil ? "New fixed cost" : "Fixed cost",
            canSave: parsed != nil && category != nil && !name.trimmingCharacters(in: .whitespaces).isEmpty,
            save: save, delete: original.map { cost in { delete(cost) } }
        ) {
            LabeledField(title: "Name", text: $name, prompt: "e.g. phone contract")
            AmountField(title: "Amount (€)", text: $amount, large: true)
            if !amount.isEmpty && parsed == nil {
                Text("Please enter an amount, e.g. 18,36.").textRole(.caption).foregroundStyle(
                    Palette.negative.color)
            }
            ChoiceRow(
                title: "How often?", items: Recurrence.allCases, value: { $0 }, label: label(of:),
                selection: $recurrence)
            if recurrence != .monthly, let parsed {
                Text("That is \((recurrence.monthlyShare(of: parsed)).text) a month.")
                    .textRole(.caption).foregroundStyle(Palette.secondaryText.color)
            }
            HStack {
                Text("Due on day").textRole(.body)
                Spacer()
                Picker("Due on day", selection: $dueDay) {
                    ForEach(1...31, id: \.self) { Text("\($0).").tag($0) }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
            .frame(minHeight: 44)
            .padding(.horizontal, 14)
            .background(Palette.card.color, in: .rect(cornerRadius: 14, style: .continuous))
            ChoiceRow(
                title: "Category", items: model.settings.categories.map { Optional($0) }, value: { $0 },
                label: { $0.map { model.settings.name(of: $0) } ?? "" },
                dot: { $0.map { model.settings.color(of: $0) } ?? .clear }, selection: $category)
            if model.householdActive {
                ChoiceRow(
                    title: "Who pays?", items: [Scope.personal, .household], value: { $0 },
                    label: {
                        $0 == .personal ? String(localized: "Only me") : String(localized: "Shared pot")
                    },
                    selection: $scope)
            }
            VStack(alignment: .leading, spacing: 10) {
                Toggle("Contract with an end date", isOn: contractBinding).textRole(.bodyStrong)
                if hasContractEnd {
                    DatePicker("Contract ends on", selection: $contractEnd, displayedComponents: .date)
                    Picker("Notice period", selection: $noticeDays) {
                        Text("None").tag(0)
                        Text("2 weeks").tag(14)
                        Text("1 month").tag(30)
                        Text("2 months").tag(61)
                        Text("3 months").tag(91)
                    }
                    Text("Pott reminds you two weeks before the notice deadline.")
                        .textRole(.caption)
                        .foregroundStyle(Palette.secondaryText.color)
                }
            }
            .textRole(.body)
            .card(padding: 14)
            if original != nil {
                Toggle(isOn: $isPaused) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Paused").textRole(.bodyStrong)
                        Text("Kept, but not counted this month").textRole(.caption)
                            .foregroundStyle(Palette.secondaryText.color)
                    }
                }
                .card(padding: 14)
            }
            LabeledField(
                title: "Note", text: $note, prompt: "Contract number, customer number …", multiline: true)
        }
    }

    /// Switching a contract end on also switches the reminder module on and asks for notifications.
    private var contractBinding: Binding<Bool> {
        Binding(
            get: { hasContractEnd },
            set: { on in
                withAnimation { hasContractEnd = on }
                guard on, !model.settings.isOn(.contractReminders) else { return }
                model.settings.set(.contractReminders, true)
                Task { _ = await Reminders.requestPermission() }
            })
    }

    private func label(of recurrence: Recurrence) -> String {
        switch recurrence {
        case .monthly: String(localized: "Monthly")
        case .quarterly: String(localized: "Quarterly")
        case .yearly: String(localized: "Yearly")
        }
    }

    private func save() {
        guard let parsed, let category else { return }
        let cost = FixedCost(
            id: original?.id ?? UUID(), name: name.trimmingCharacters(in: .whitespaces), amount: parsed,
            recurrence: recurrence, dueDay: dueDay, category: category,
            scope: model.householdActive ? scope : (original?.scope ?? .personal),
            note: note, isPaused: isPaused,
            contractEnd: hasContractEnd ? contractEnd : nil,
            noticePeriodDays: hasContractEnd ? noticeDays : nil)
        model.save(cost)
        toasts.show(String(localized: "“\(cost.name)” saved"))
    }

    private func delete(_ cost: FixedCost) {
        model.delete(cost)
        toasts.show(String(localized: "“\(cost.name)” deleted")) { model.save(cost) }
    }
}
