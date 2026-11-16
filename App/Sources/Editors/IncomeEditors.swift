import PottCore
import PottDesign
import PottFeatures
import SwiftUI

/// All income sources; several jobs, a mini job, child benefit, rent income …
struct IncomesSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(ToastCenter.self) private var toasts
    @Environment(\.dismiss) private var dismiss
    @State private var editing: IncomeRoute?

    struct IncomeRoute: Identifiable {
        var income: IncomeSource?
        var id: String { income?.id.uuidString ?? "new" }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(model.incomes) { income in
                        Button {
                            editing = IncomeRoute(income: income)
                        } label: {
                            row(income)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Palette.card.color)
                        .swipeActions {
                            Button(role: .destructive) {
                                model.delete(income)
                                model.syncMyIncome()
                                toasts.show(String(localized: "“\(income.name)” deleted")) {
                                    model.save(income)
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    Text("Together \(model.incomes.map(\.monthlyNet).sum().text) a month").textRole(.caption)
                } footer: {
                    Text(
                        "Several jobs? Work out each one in the calculator and take it over as its own income. Enter a mini job, child benefit or rent income by hand."
                    )
                    .textRole(.caption)
                }
                Section {
                    Button {
                        editing = IncomeRoute(income: nil)
                    } label: {
                        Label("Add by hand", systemImage: "plus").textRole(.bodyStrong)
                    }
                    .frame(minHeight: 44)
                    if model.settings.isOn(.calculator) {
                        Button {
                            dismiss()
                            router.tab = .calculator
                        } label: {
                            Label("Work out in the calculator", systemImage: "function").textRole(.bodyStrong)
                        }
                        .frame(minHeight: 44)
                    }
                }
                .listRowBackground(Palette.card.color)
            }
            .scrollContentBackground(.hidden)
            .background(Palette.background.color)
            .navigationTitle("Income")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .sheet(item: $editing) { route in IncomeEditor(income: route.income) }
        }
    }

    private func row(_ income: IncomeSource) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(income.name).textRole(.bodyStrong)
                Text(origin(income)).textRole(.caption).foregroundStyle(Palette.secondaryText.color)
            }
            Spacer()
            Text(income.monthlyNet.text).textRole(.amount)
        }
        .frame(minHeight: 56)
        .contentShape(.rect)
    }

    private func origin(_ income: IncomeSource) -> String {
        switch income.origin {
        case .manual: String(localized: "Entered by hand")
        case .calculator(let summary): String(localized: "From the calculator · \(summary)")
        }
    }
}

/// Creates or edits one income source.
struct IncomeEditor: View {
    @Environment(AppModel.self) private var model
    @Environment(ToastCenter.self) private var toasts
    let original: IncomeSource?
    @State private var name: String
    @State private var amount: String
    @State private var note: String

    init(income: IncomeSource?) {
        original = income
        _name = State(initialValue: income?.name ?? "")
        _amount = State(initialValue: income?.monthlyNet.editingText() ?? "")
        _note = State(initialValue: income?.note ?? "")
    }

    private var parsed: Money? { Money.parse(amount).flatMap { $0.cents > 0 ? $0 : nil } }

    var body: some View {
        EditorSheet(
            title: original == nil ? "New income" : "Income",
            canSave: parsed != nil && !name.trimmingCharacters(in: .whitespaces).isEmpty,
            save: save,
            delete: original.map { income in
                {
                    model.delete(income)
                    model.syncMyIncome()
                    toasts.show(String(localized: "“\(income.name)” deleted")) { model.save(income) }
                }
            }
        ) {
            LabeledField(title: "Name", text: $name, prompt: "e.g. mini job, child benefit")
            AmountField(title: "Net per month (€)", text: $amount, large: true)
            if case .calculator(let summary) = original?.origin {
                Text("Taken over from the calculator · \(summary)")
                    .textRole(.caption)
                    .foregroundStyle(Palette.secondaryText.color)
                    .card(padding: 12)
            }
            LabeledField(title: "Note", text: $note, prompt: "e.g. employer, payday", multiline: true)
        }
    }

    private func save() {
        guard let parsed else { return }
        model.save(
            IncomeSource(
                id: original?.id ?? UUID(), name: name.trimmingCharacters(in: .whitespaces),
                monthlyNet: parsed,
                origin: original?.origin ?? .manual, note: note))
        model.syncMyIncome()
        toasts.show(String(localized: "“\(name)” saved"))
    }
}

/// Creates or edits a savings goal; the monthly rate follows from target and months.
struct GoalEditor: View {
    @Environment(AppModel.self) private var model
    @Environment(ToastCenter.self) private var toasts
    let original: SavingsGoal?
    @State private var name: String
    @State private var target: String
    @State private var saved: String
    @State private var months: Int
    @State private var scope: Scope
    @State private var note: String

    static var nextMonth: Date { Calendar.current.date(byAdding: .month, value: 1, to: .now) ?? .now }

    /// The target date shown in the picker, derived from and writing back to `months`.
    private var targetDate: Binding<Date> {
        Binding(
            get: { Calendar.current.date(byAdding: .month, value: months, to: .now) ?? .now },
            set: { date in
                // Count whole calendar months, so reading and writing the same date keeps the value.
                let calendar = Calendar.current
                let start = calendar.dateComponents([.year, .month], from: .now)
                let end = calendar.dateComponents([.year, .month], from: date)
                let count = ((end.year ?? 0) - (start.year ?? 0)) * 12 + (end.month ?? 0) - (start.month ?? 0)
                months = min(max(count, 1), 600)
            })
    }

    init(goal: SavingsGoal?, defaultScope: Scope) {
        original = goal
        _name = State(initialValue: goal?.name ?? "")
        _target = State(initialValue: goal?.target.editingText() ?? "")
        _saved = State(initialValue: goal?.saved.editingText() ?? "")
        _months = State(initialValue: goal?.months ?? 12)
        _scope = State(initialValue: goal?.scope ?? defaultScope)
        _note = State(initialValue: goal?.note ?? "")
    }

    private var draft: SavingsGoal? {
        guard let goal = Money.parse(target), goal.cents > 0 else { return nil }
        return SavingsGoal(
            id: original?.id ?? UUID(), name: name.trimmingCharacters(in: .whitespaces), target: goal,
            saved: Money.parse(saved) ?? .zero, months: months,
            scope: model.householdActive ? scope : (original?.scope ?? .personal), note: note)
    }

    var body: some View {
        EditorSheet(
            title: original == nil ? "New savings goal" : "Savings goal",
            canSave: draft != nil && !name.trimmingCharacters(in: .whitespaces).isEmpty,
            save: save,
            delete: original.map { goal in
                {
                    model.delete(goal)
                    toasts.show(String(localized: "“\(goal.name)” deleted")) { model.save(goal) }
                }
            }
        ) {
            LabeledField(title: "Name", text: $name, prompt: "e.g. holiday, new car")
            AmountField(title: "Target (€)", text: $target, large: true)
            AmountField(title: "Already saved (€)", text: $saved)
            // People think "by July", not "in 9 months"; the months follow from the date.
            DatePicker(selection: targetDate, in: Self.nextMonth..., displayedComponents: .date) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Reach the goal by").textRole(.bodyStrong)
                    Text("in \(months) months").textRole(.caption).foregroundStyle(
                        Palette.secondaryText.color)
                }
            }
            .frame(minHeight: 44)
            if let draft {
                Text("That is \(draft.monthlyRate.text) a month.")
                    .textRole(.bodyStrong)
                    .foregroundStyle(Palette.accentText.color)
            }
            if model.householdActive {
                ChoiceRow(
                    title: "Who saves?", items: [Scope.personal, .household], value: { $0 },
                    label: {
                        $0 == .personal ? String(localized: "Only me") : String(localized: "Shared pot")
                    },
                    selection: $scope)
            }
            LabeledField(title: "Note", text: $note, multiline: true)
        }
    }

    private func save() {
        guard let draft else { return }
        model.save(draft)
        toasts.show(String(localized: "Savings goal “\(draft.name)”: \(draft.monthlyRate.text) a month"))
    }
}
