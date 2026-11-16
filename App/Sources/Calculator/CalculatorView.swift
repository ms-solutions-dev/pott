import PottCore
import PottDesign
import PottFeatures
import SwiftUI
/// Gross to net and back ("desired net"), for a main job, a second job or a mini job.
import TaxDE

/// Lets the user add the result as a new income or update an existing one from the calculator.

/// The 16 German states with the codes the tax rules use.
struct CalculatorView: View {
    @Environment(AppModel.self) private var model
    @State private var desiredNet = false
    @State private var amountText = ""
    @State private var showsOptions = ProcessInfo.processInfo.arguments.contains("-PottInsurerOpen")
    @State private var taking = false
    @State private var explained: Deduction.Kind?
    @State private var showsPicker = ProcessInfo.processInfo.arguments.contains("-PottPickerOpen")

    private let calculator = GermanPayCalculator()

    var body: some View {
        @Bindable var settings = model.settings
        let input = settings.payInput
        let result = currentResult
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Calculator").textRole(.title).accessibilityAddTraits(.isHeader)
                    Spacer()
                    Text("Rules of 2026")
                        .textRole(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .foregroundStyle(Palette.onAccent.color)
                        .background(Palette.accent.color, in: .capsule)
                }
                .padding(.top, 8)

                CalculatorSentence(choice: choice, isOpen: showsPicker) { showsPicker = true }

                if settings.calculatorSelfEmployed {
                    SelfEmployedSection(desired: $desiredNet, bump: choice.key)
                } else {
                    AmountField(
                        title: desiredNet ? "Desired net per month (€)" : "Gross per month (€)",
                        text: $amountText, large: true
                    )
                    .onAppear { amountText = input.gross.editingText() }

                    if input.employment == .mini {
                        miniJobOptions
                    } else {
                        optionsCard
                        SpecialCasesCard()
                    }

                    resultCard(result)
                    if let oneOff = result?.oneOff, input.employment != .mini {
                        OneOffCard(pay: oneOff, name: name(of:))
                    }

                    Text(
                        "Example calculation without guarantee. Wage tax as in the official program of the German Federal Ministry of Finance. Not included: several jobs on one payslip, and the effect of short-time allowance on next year's tax return."
                    )
                    .textRole(.caption)
                    .foregroundStyle(Palette.secondaryText.color)
                }
                Color.clear.frame(height: 90)
            }
            .padding(.horizontal, 18)
        }
        .scrollDismissesKeyboard(.interactively)
        // The calculator steps back while the wheels are open, like behind a system sheet.
        .scaleEffect(showsPicker ? 0.93 : 1, anchor: .top)
        .offset(y: showsPicker ? 12 : 0)
        .blur(radius: showsPicker ? 1.5 : 0)
        .brightness(showsPicker ? -0.12 : 0)
        .animation(.spring(duration: 0.55, bounce: 0.12), value: showsPicker)
        .background(Palette.background.color)
        .sheet(isPresented: $showsPicker) { CalculatorPickerSheet(choice: choice) }
        .sheet(isPresented: $taking) {
            if let result {
                TakeOverSheet(
                    result: result, defaultName: Self.jobName(input), summary: Self.jobSummary(result, input))
            }
        }
        .alert(explanationTitle, isPresented: explanationShown) {
            Button("OK") { explained = nil }
        } message: {
            Text(explanationText)
        }
    }

    private var choice: CalculatorChoice {
        CalculatorChoice(settings: model.settings, desired: $desiredNet)
    }

    /// The result for the current text: gross → net, or the gross needed for a desired net.
    private var currentResult: PayResult? {
        guard let amount = Money.parse(amountText), amount.cents > 0 else { return nil }
        var input = model.settings.payInput
        if desiredNet {
            // Short-time work changes what the gross means, so the search ignores it.
            input.shortTimeGross = nil
            return calculator.grossNeeded(forNet: amount, input)
        }
        input.gross = amount
        return calculator.calculate(input)
    }

    private var optionsCard: some View {
        @Bindable var settings = model.settings
        return VStack(spacing: 0) {
            DisclosureGroup(isExpanded: $showsOptions) {
                VStack(spacing: 12) {
                    Picker("State", selection: $settings.payInput.region) {
                        ForEach(GermanState.all, id: \.code) { state in
                            Text(verbatim: state.name).tag(state.code)
                        }
                    }
                    Toggle("Church tax", isOn: $settings.payInput.churchMember)
                    Stepper(
                        value: $settings.payInput.childAllowances, in: 0...8, step: Decimal(string: "0.5")!
                    ) {
                        Text("Child allowances: \(settings.payInput.childAllowances.formatted())")
                    }
                    Stepper(value: $settings.payInput.childrenUnder25, in: 0...10) {
                        Text("Children under 25: \(settings.payInput.childrenUnder25)")
                    }
                    Toggle("Has had children", isOn: $settings.payInput.isParent)
                    if !settings.payInput.isPrivatelyInsured {
                        HealthInsurerRow(
                            rate: $settings.payInput.healthAdditionalRate,
                            insurer: $settings.payInput.healthInsurer,
                            year: settings.payInput.year, region: settings.payInput.region)
                    }
                }
                .textRole(.body)
                .padding(.top, 10)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("More details").textRole(.bodyStrong)
                    Text(summary).textRole(.caption).foregroundStyle(Palette.secondaryText.color)
                }
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .card()
    }

    private var summary: String {
        let input = model.settings.payInput
        let state = GermanState.all.first { $0.code == input.region }?.name ?? input.region
        let church = input.churchMember ? String(localized: "church tax") : String(localized: "no church tax")
        let health =
            input.healthInsurer.map { "\($0) \(input.healthAdditionalRate.formatted()) %" }
            ?? String(localized: "additional contribution \(input.healthAdditionalRate.formatted()) %")
        return "\(state) · \(church) · \(String(localized: "\(input.childrenUnder25) children")) · \(health)"
    }

    private var miniJobOptions: some View {
        @Bindable var settings = model.settings
        return VStack(alignment: .leading, spacing: 10) {
            Text(
                "In a mini job you pay no wage tax and no health or care insurance. Only 3.6 % pension insurance is due, unless you are exempt."
            )
            .textRole(.body)
            Toggle("Exempt from pension insurance", isOn: $settings.payInput.pensionExempt).textRole(
                .bodyStrong)
        }
        .card()
    }

    @ViewBuilder
    private func resultCard(_ result: PayResult?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let result {
                Text(desiredNet ? "Gross needed" : "Your net pay").textRole(.bodyStrong).opacity(0.8)
                Text((desiredNet ? result.gross : result.net).text)
                    .textRole(.figure)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: result.net)
                    .bump(on: choice.key)
                if desiredNet {
                    Text("gives \(result.net.text) net").textRole(.caption)
                }
                if result.taxableBenefit > .zero {
                    Text("Includes \(result.taxableBenefit.text) taxed benefit, not paid out").textRole(
                        .caption)
                }
                // The main action right under the result, not hidden behind the tab bar.
                Button("Take over as income") { taking = true }
                    .textRole(.bodyStrong)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .foregroundStyle(Palette.accent.color)
                    .background(Palette.onAccent.color, in: .rect(cornerRadius: 16, style: .continuous))
                    .padding(.vertical, 6)
                ForEach(result.deductions.filter { $0.amount.cents > 0 || $0.kind == .incomeTax }, id: \.kind)
                { deduction in
                    let explains = model.settings.isOn(.explanations)
                    Button {
                        if explains { explained = deduction.kind }
                    } label: {
                        HStack {
                            Text(name(of: deduction.kind)).textRole(.body)
                            if explains { Image(systemName: "info.circle") }
                            Spacer()
                            Text("− \(deduction.amount.text)").textRole(.bodyStrong)
                        }
                        .frame(minHeight: 44)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .disabled(!explains)
                    .accessibilityHint(explains ? Text("Shows an explanation") : Text(""))
                }
                if result.shortTimeAllowance > .zero {
                    HStack {
                        Text("Short-time allowance").textRole(.body)
                        Spacer()
                        Text("+ \(result.shortTimeAllowance.text)").textRole(.bodyStrong)
                    }
                    .frame(minHeight: 44)
                }
            } else {
                Text("Enter an amount").textRole(.bodyStrong)
            }
        }
        .foregroundStyle(Palette.onAccent.color)
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.accent.color, in: .rect(cornerRadius: 22, style: .continuous))
        .onChange(of: amountText) { _, value in
            if !desiredNet, let amount = Money.parse(value) { model.settings.payInput.gross = amount }
        }
    }

    private func name(of kind: Deduction.Kind) -> String { Self.title(of: kind) }

    static func title(of kind: Deduction.Kind) -> String {
        switch kind {
        case .incomeTax: String(localized: "Wage tax")
        case .solidaritySurcharge: String(localized: "Solidarity surcharge")
        case .churchTax: String(localized: "Church tax")
        case .healthInsurance: String(localized: "Health insurance")
        case .careInsurance: String(localized: "Care insurance")
        case .pensionInsurance: String(localized: "Pension insurance")
        case .unemploymentInsurance: String(localized: "Unemployment insurance")
        case .privateInsurance: String(localized: "Private insurance")
        case .companyPension: String(localized: "Company pension")
        case .bikeLeasing: String(localized: "Bike leasing")
        case .carCoPayment: String(localized: "Own payment for the car")
        case .tradeTax: String(localized: "Trade tax")
        case .basicPension: String(localized: "Basic pension (Rürup)")
        }
    }

    private var explanationTitle: String { explained.map(name(of:)) ?? "" }

    private var explanationShown: Binding<Bool> {
        Binding(get: { explained != nil }, set: { if !$0 { explained = nil } })
    }

    private var explanationText: String {
        switch explained {
        case .incomeTax:
            String(
                localized:
                    "Income tax taken directly from your salary. How much depends on your tax class, child allowances and the progressive tax rate."
            )
        case .solidaritySurcharge:
            String(
                localized:
                    "5.5 % of the wage tax, but only above a high allowance. Most employees pay nothing.")
        case .churchTax:
            String(
                localized:
                    "Only for members of a church that collects it: 8 % of the wage tax in Bavaria and Baden-Württemberg, 9 % elsewhere."
            )
        case .healthInsurance:
            String(
                localized:
                    "Half of 14.6 % plus half of your health insurer’s additional contribution, up to the contribution ceiling."
            )
        case .careInsurance:
            String(
                localized:
                    "Your share of 3.6 %. Without children you pay 0.6 % more; from the second child under 25 it gets cheaper. Saxony has its own split."
            )
        case .pensionInsurance:
            String(localized: "Half of 18.6 %, up to the contribution ceiling. In a mini job 3.6 %.")
        case .unemploymentInsurance:
            String(localized: "Half of 2.6 %, up to the contribution ceiling.")
        case .privateInsurance:
            String(
                localized:
                    "Your health and care premiums minus the employer’s subsidy: half the premium, at most what it would pay for statutory insurance."
            )
        case .companyPension:
            String(
                localized:
                    "Salary paid into a company pension. Up to €676 a month is tax-free and up to €338 free of social insurance."
            )
        case .bikeLeasing:
            String(
                localized:
                    "The leasing rate comes out of your gross. In return, only 0.25 % of the list price is taxed as a benefit."
            )
        case .carCoPayment:
            String(localized: "What you pay for the car yourself. It lowers the taxed benefit.")
        case .tradeTax:
            String(
                localized:
                    "For a trade business: 3.5 % of the profit above €24,500 times the town’s multiplier. Up to four times that base amount is credited against income tax."
            )
        case .basicPension:
            String(
                localized:
                    "A basic pension contract (Rürup). Deducted as special expense together with the statutory pension contributions, up to €30,826 a year."
            )
        case nil: ""
        }
    }
}
extension CalculatorView {
    static func jobSummary(_ result: PayResult, _ input: PayInput) -> String {
        if input.employment == .mini { return String(localized: "Mini job · gross \(result.gross.text)") }
        let taxClass = input.employment == .secondary ? 6 : input.taxClass
        return String(
            localized:
                "Gross \(result.gross.text) · class \(["I", "II", "III", "IV", "V", "VI"][taxClass - 1])")
    }

    static func jobName(_ input: PayInput) -> String {
        switch input.employment {
        case .main: String(localized: "Main job")
        case .secondary: String(localized: "Second job")
        case .mini: String(localized: "Mini job")
        }
    }
}

struct TakeOverSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(ToastCenter.self) private var toasts
    @Environment(\.dismiss) private var dismiss
    var result: PayResult
    var defaultName: String
    var summary: String

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("\(defaultName) · \(result.net.text) net a month").textRole(.body).foregroundStyle(
                    Palette.secondaryText.color)
                Button("Add as new income “\(defaultName)”") { apply(nil) }
                    .buttonStyle(AccentButtonStyle())
                ForEach(model.incomes.filter { if case .calculator = $0.origin { true } else { false } }) {
                    income in
                    Button {
                        apply(income)
                    } label: {
                        Text("Update “\(income.name)” (so far \(income.monthlyNet.text))")
                            .textRole(.bodyStrong)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Palette.control.color))
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(18)
            .background(Palette.background.color)
            .navigationTitle("Take over as income")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
        .presentationDetents([.medium])
    }

    private func apply(_ existing: IncomeSource?) {
        let before = existing
        let income = IncomeSource(
            id: existing?.id ?? UUID(), name: existing?.name ?? defaultName, monthlyNet: result.net,
            origin: .calculator(summary: summary), note: existing?.note ?? "")
        model.save(income)
        model.syncMyIncome()
        dismiss()
        router.tab = .overview
        toasts.show(String(localized: "\(income.name) · \(result.net.text) taken over")) {
            if let before { model.save(before) } else { model.delete(income) }
            model.syncMyIncome()
        }
    }
}
enum GermanState {
    static let all: [(code: String, name: String)] = [
        ("BW", "Baden-Württemberg"), ("BY", "Bayern"), ("BE", "Berlin"), ("BB", "Brandenburg"),
        ("HB", "Bremen"),
        ("HH", "Hamburg"), ("HE", "Hessen"), ("MV", "Mecklenburg-Vorpommern"), ("NI", "Niedersachsen"),
        ("NW", "Nordrhein-Westfalen"), ("RP", "Rheinland-Pfalz"), ("SL", "Saarland"), ("SN", "Sachsen"),
        ("ST", "Sachsen-Anhalt"), ("SH", "Schleswig-Holstein"), ("TH", "Thüringen"),
    ]
}
