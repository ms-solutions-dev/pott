import PottCore
import PottDesign
import PottFeatures
import SwiftUI
import TaxDE

/// Three steps on first launch: net income, common fixed costs, optional modules.
struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss
    @State private var step = 1
    @State private var income = ""
    @State private var picked: Set<String> = []
    @State private var household = false
    @State private var savings = false
    @State private var knowsGross = false
    @State private var gross = ""
    @State private var taxClass = 1

    /// Suggestions with typical amounts; everything can be changed afterwards.
    private var suggestions: [(name: String, category: CategoryID, euros: Int64)] {
        [
            (String(localized: "Rent"), .housing, 800), (String(localized: "Power & gas"), .energy, 100),
            (String(localized: "Internet"), .subscriptions, 40),
            (String(localized: "Phone"), .subscriptions, 20),
            (String(localized: "Insurance"), .insurance, 60),
            (String(localized: "Streaming"), .subscriptions, 15),
            (String(localized: "Car"), .mobility, 200), (String(localized: "Gym"), .subscriptions, 30),
            (String(localized: "Public transport ticket"), .mobility, 58),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                ForEach(1...3, id: \.self) { index in
                    Capsule()
                        .fill(index <= step ? Palette.ring.color : Palette.separator.color)
                        .frame(width: index == step ? 28 : 10, height: 6)
                }
                Spacer()
                Button("Skip") { finish(openCalculator: false) }
                    .textRole(.bodyStrong)
                    .foregroundStyle(Palette.secondaryText.color)
                    .frame(minHeight: 44)
            }
            .animation(.spring(duration: 0.3), value: step)

            Group {
                switch step {
                case 1: incomeStep
                case 2: costsStep
                default: modulesStep
                }
            }
            .transition(
                .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity)
            )
            .id(step)
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.top, 28)

            Button(step == 3 ? "Let’s go" : "Next") {
                if step < 3 {
                    withAnimation(.spring(duration: 0.4)) { step += 1 }
                } else {
                    finish(openCalculator: false)
                }
            }
            .buttonStyle(AccentButtonStyle())
        }
        .padding(22)
        .background(Palette.background.color)
        .interactiveDismissDisabled()
    }

    private var incomeStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("What arrives each month?").textRole(.title)
            Text(
                "Your net pay, what actually lands in your account. You can add more income like a mini job later."
            )
            .textRole(.body).foregroundStyle(Palette.secondaryText.color)
            if knowsGross {
                // A small calculator right here, so the introduction does not end on the way.
                AmountField(title: "Gross per month (€)", text: $gross, large: true)
                ChoiceRow(
                    title: "Tax class", items: Array(1...6), value: { $0 },
                    label: { ["I", "II", "III", "IV", "V", "VI"][$0 - 1] }, selection: $taxClass)
                if let net = grossResult?.net {
                    Text("That is about \(net.text) net a month.")
                        .textRole(.bodyStrong)
                        .foregroundStyle(Palette.accentText.color)
                }
                Text("Without church tax and children; you can refine it later in the calculator.")
                    .textRole(.caption)
                    .foregroundStyle(Palette.secondaryText.color)
            } else {
                AmountField(title: "Net per month (€)", text: $income, large: true)
            }
            Button(knowsGross ? "I know my net pay" : "I only know my gross pay") {
                withAnimation { knowsGross.toggle() }
            }
            .textRole(.bodyStrong)
            .foregroundStyle(Palette.accentText.color)
            .frame(minHeight: 44)
        }
    }

    private var grossResult: PayResult? {
        guard let amount = Money.parse(gross), amount.cents > 0 else { return nil }
        return GermanPayCalculator().calculate(PayInput(gross: amount, taxClass: taxClass))
    }

    private var costsStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Which fixed costs do you have?").textRole(.title)
            Text("Tap what applies. You adjust the amounts afterwards.")
                .textRole(.body).foregroundStyle(Palette.secondaryText.color)
            ScrollView {
                FlowLayout(spacing: 8) {
                    ForEach(suggestions, id: \.name) { item in
                        Chip(
                            "\(item.name) · \(Money(units: item.euros).text)",
                            isSelected: picked.contains(item.name),
                            dot: model.settings.color(of: item.category)
                        ) {
                            if picked.contains(item.name) {
                                picked.remove(item.name)
                            } else {
                                picked.insert(item.name)
                            }
                        }
                    }
                }
            }
        }
    }

    private var modulesStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("What else do you need?").textRole(.title)
            Text("Both are optional and can be changed in the settings at any time.")
                .textRole(.body).foregroundStyle(Palette.secondaryText.color)
            option(
                "Share costs with a partner", "A shared pot for rent, groceries and the like.",
                isOn: $household)
            option("Save for goals", "A holiday or an emergency fund with a monthly rate.", isOn: $savings)
        }
    }

    private func option(
        _ title: LocalizedStringKey, _ detail: LocalizedStringKey, isOn: Binding<Bool>
    ) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).textRole(.bodyStrong)
                    Text(detail).textRole(.caption).foregroundStyle(Palette.secondaryText.color)
                }
                Spacer()
                Image(systemName: isOn.wrappedValue ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isOn.wrappedValue ? Palette.ring.color : Palette.control.color)
            }
            .padding(16)
            .background(Palette.card.color, in: .rect(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        isOn.wrappedValue ? Palette.ring.color : Palette.separator.color, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn.wrappedValue ? .isSelected : [])
        .sensoryFeedback(.selection, trigger: isOn.wrappedValue)
    }

    private func finish(openCalculator: Bool) {
        if knowsGross, let result = grossResult {
            let summary = String(
                localized:
                    "Gross \(result.gross.text) · class \(["I", "II", "III", "IV", "V", "VI"][taxClass - 1])")
            model.save(
                IncomeSource(
                    name: String(localized: "Salary"), monthlyNet: result.net,
                    origin: .calculator(summary: summary)))
            var input = model.settings.payInput
            input.gross = result.gross
            input.taxClass = taxClass
            model.settings.payInput = input
        } else if let net = Money.parse(income), net.cents > 0 {
            model.save(IncomeSource(name: String(localized: "Salary"), monthlyNet: net))
        }
        for item in suggestions where picked.contains(item.name) {
            model.save(FixedCost(name: item.name, amount: Money(units: item.euros), category: item.category))
        }
        model.settings.set(.savings, savings)
        if household {
            model.startHousehold(myName: String(localized: "Me"), partnerName: String(localized: "Partner"))
            model.syncMyIncome()
        }
        if openCalculator { router.tab = .calculator }
        model.settings.hasOnboarded = true
        dismiss()
    }
}
