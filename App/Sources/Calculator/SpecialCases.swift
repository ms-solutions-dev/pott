import PottCore
import PottDesign
import PottFeatures
/// Less common situations, folded away: civil servants, pensioners, private health insurance,
/// factor method, allowances, company pension, company car and bike, one-off payments.
import SwiftUI

/// List price, drive, distance and own payment of the company car.

/// A compact money input: label on the left, amount on the right.

/// Year of birth; empty when not given.

/// The factor of the factor method, three decimals; empty when not used.

/// The one-off payment in its month: gross, deductions and what is paid out.
struct SpecialCasesCard: View {
    @Environment(AppModel.self) private var model
    @State private var expanded = ProcessInfo.processInfo.arguments.contains("-PottSpecialCasesOpen")

    var body: some View {
        @Bindable var settings = model.settings
        let input = settings.payInput
        VStack(spacing: 0) {
            DisclosureGroup(isExpanded: $expanded) {
                VStack(alignment: .leading, spacing: 14) {
                    Picker("You are", selection: $settings.payInput.status) {
                        Text("Employee").tag(WorkerStatus.employee)
                        Text("Civil servant").tag(WorkerStatus.civilServant)
                        Text("Pensioner").tag(WorkerStatus.pensioner)
                    }
                    .pickerStyle(.segmented)
                    statusNote(input.status)

                    if input.status != .civilServant {
                        Toggle("Private health insurance", isOn: $settings.payInput.privateInsurance)
                    }
                    if input.isPrivatelyInsured {
                        MoneyRow(
                            title: "Health premium per month", value: $settings.payInput.privateHealthPremium)
                        MoneyRow(
                            title: "Care premium per month", value: $settings.payInput.privateCarePremium)
                        note(
                            input.status == .civilServant
                                ? "Your own premium after the state aid (Beihilfe). There is no employer subsidy."
                                : "Your employer pays half, at most €508.59 for health and €104.63 for care.")
                    }

                    YearRow(value: $settings.payInput.birthYear)
                    if input.taxClass == 4 && input.employment == .main {
                        FactorRow(value: $settings.payInput.taxFactor)
                    }
                    MoneyRow(title: "Tax allowance per month", value: $settings.payInput.monthlyAllowance)

                    Divider()
                    MoneyRow(
                        title: "Company pension from salary", value: $settings.payInput.pensionConversion)
                    note("Tax-free up to €676, free of social insurance up to €338 a month.")

                    Divider()
                    Toggle("Company car", isOn: carBinding)
                    if input.companyCar != nil { CarFields() }

                    Toggle("Company bike (salary conversion)", isOn: bikeBinding)
                    if input.companyBike != nil {
                        MoneyRow(title: "Bike list price", value: bikeBinding(\.listPrice))
                        MoneyRow(title: "Leasing rate per month", value: bikeBinding(\.leasingRate))
                    }

                    Divider()
                    MoneyRow(
                        title: "Pension from a former employer", value: $settings.payInput.pensionBenefit)
                    if input.pensionBenefit > .zero {
                        Stepper(value: $settings.payInput.pensionBenefitStartYear, in: 1980...2026) {
                            Text("Paid since \(String(input.pensionBenefitStartYear))")
                        }
                    }
                    note(
                        "Civil-servant pension or company pension paid through the payroll, included in the gross above."
                    )

                    Divider()
                    Toggle("Short-time work this month", isOn: shortTimeBinding)
                    if input.shortTimeGross != nil {
                        MoneyRow(title: "Gross actually earned", value: shortTimeAmount)
                        note(
                            "The gross above is your usual pay. The allowance is 60 % of the lost net pay, 67 % with a child; it is tax-free but raises the tax rate on your other income."
                        )
                    }

                    Divider()
                    MoneyRow(title: "One-off payment", value: $settings.payInput.oneOffPayment)
                    if input.oneOffPayment > .zero {
                        Picker("Paid in", selection: $settings.payInput.oneOffMonth) {
                            ForEach(1...12, id: \.self) { month in
                                Text(Calendar.current.monthSymbols[month - 1]).tag(month)
                            }
                        }
                    }
                }
                .textRole(.body)
                .padding(.top, 10)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Special cases").textRole(.bodyStrong)
                    Text(summary(input)).textRole(.caption).foregroundStyle(Palette.secondaryText.color)
                }
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .card()
    }

    private func statusNote(_ status: WorkerStatus) -> some View {
        Group {
            switch status {
            case .employee: EmptyView()
            case .civilServant: note("No social insurance; health cover is private.")
            case .pensioner:
                note(
                    "Working with a full old-age pension past the regular retirement age: no pension or unemployment contribution, health insurance without sick pay."
                )
            }
        }
    }

    private func note(_ text: LocalizedStringKey) -> some View {
        Text(text).textRole(.caption).foregroundStyle(Palette.secondaryText.color)
    }

    /// What is switched on, in a few words; "none" when nothing is.
    private func summary(_ input: PayInput) -> String {
        var parts: [String] = []
        switch input.status {
        case .employee: break
        case .civilServant: parts.append(String(localized: "civil servant"))
        case .pensioner: parts.append(String(localized: "pensioner"))
        }
        if input.privateInsurance && input.status != .civilServant {
            parts.append(String(localized: "private insurance"))
        }
        if input.taxFactor != nil && input.taxClass == 4 { parts.append(String(localized: "factor")) }
        if input.monthlyAllowance > .zero { parts.append(String(localized: "allowance")) }
        if input.pensionConversion > .zero { parts.append(String(localized: "company pension")) }
        if input.companyCar != nil { parts.append(String(localized: "company car")) }
        if input.companyBike != nil { parts.append(String(localized: "company bike")) }
        if input.oneOffPayment > .zero { parts.append(String(localized: "one-off payment")) }
        if input.pensionBenefit > .zero { parts.append(String(localized: "pension")) }
        if input.shortTimeGross != nil { parts.append(String(localized: "short-time work")) }
        return parts.isEmpty
            ? String(localized: "Civil servants, pensioners, company car …") : parts.joined(separator: " · ")
    }

    private var shortTimeBinding: Binding<Bool> {
        Binding(
            get: { model.settings.payInput.shortTimeGross != nil },
            set: { model.settings.payInput.shortTimeGross = $0 ? .zero : nil })
    }

    private var shortTimeAmount: Binding<Money> {
        Binding(
            get: { model.settings.payInput.shortTimeGross ?? .zero },
            set: { model.settings.payInput.shortTimeGross = $0 })
    }

    private var carBinding: Binding<Bool> {
        Binding(
            get: { model.settings.payInput.companyCar != nil },
            set: { model.settings.payInput.companyCar = $0 ? CompanyCar(listPrice: .zero) : nil })
    }

    private var bikeBinding: Binding<Bool> {
        Binding(
            get: { model.settings.payInput.companyBike != nil },
            set: {
                model.settings.payInput.companyBike =
                    $0 ? CompanyBike(listPrice: .zero, leasingRate: .zero) : nil
            })
    }

    private func bikeBinding(_ path: WritableKeyPath<CompanyBike, Money>) -> Binding<Money> {
        Binding(
            get: { model.settings.payInput.companyBike?[keyPath: path] ?? .zero },
            set: { model.settings.payInput.companyBike?[keyPath: path] = $0 })
    }
}
private struct CarFields: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            MoneyRow(title: "List price", value: binding(\.listPrice))
            Picker("Drive", selection: binding(\.kind)) {
                Text("Combustion").tag(CarKind.combustion)
                Text("Plug-in hybrid").tag(CarKind.hybrid)
                Text("Electric").tag(CarKind.electric)
            }
            .pickerStyle(.segmented)
            Stepper(value: binding(\.commuteKilometres), in: 0...200) {
                Text("Distance to work: \(model.settings.payInput.companyCar?.commuteKilometres ?? 0) km")
            }
            MoneyRow(title: "Your own payment per month", value: binding(\.coPayment))
            Text(
                "Taxed each month: 1 % of the list price plus 0.03 % per kilometre to work. Hybrids count half, electric cars up to €100,000 a quarter."
            )
            .textRole(.caption).foregroundStyle(Palette.secondaryText.color)
        }
    }

    private func binding<Value>(_ path: WritableKeyPath<CompanyCar, Value>) -> Binding<Value> {
        Binding(
            get: { (model.settings.payInput.companyCar ?? CompanyCar(listPrice: .zero))[keyPath: path] },
            set: { model.settings.payInput.companyCar?[keyPath: path] = $0 })
    }
}
struct MoneyRow: View {
    var title: LocalizedStringKey
    @Binding var value: Money
    @State private var text = ""

    var body: some View {
        HStack {
            Text(title)
            Spacer(minLength: 12)
            TextField(text: $text, prompt: Text("0")) { Text(title) }
                .accessibilityLabel(Text(title))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 110)
            Text(verbatim: "€").foregroundStyle(Palette.secondaryText.color)
        }
        .onAppear { text = value > .zero ? value.editingText() : "" }
        .onChange(of: text) { _, newValue in value = Money.parse(newValue) ?? .zero }
    }
}
private struct YearRow: View {
    @Binding var value: Int?
    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Year of birth")
                Spacer(minLength: 12)
                TextField(text: $text, prompt: Text(verbatim: "1960")) { Text("Year of birth") }
                    .accessibilityLabel(Text("Year of birth"))
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 80)
            }
            Text("Only needed from 64: an age relief lowers the tax.")
                .textRole(.caption).foregroundStyle(Palette.secondaryText.color)
        }
        .onAppear { text = value.map { String($0) } ?? "" }
        .onChange(of: text) { _, newValue in
            let year = Int(newValue)
            value = year.flatMap { (1900...2010).contains($0) ? $0 : nil }
        }
    }
}
private struct FactorRow: View {
    @Binding var value: Decimal?
    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Factor")
                Spacer(minLength: 12)
                TextField(text: $text, prompt: Text(verbatim: "0,912")) { Text("Factor") }
                    .accessibilityLabel(Text("Factor"))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 80)
            }
            Text("Class IV with factor, as on your tax notice. Leave empty without.")
                .textRole(.caption).foregroundStyle(Palette.secondaryText.color)
        }
        .onAppear { text = value.map { $0.formatted(.number.precision(.fractionLength(3))) } ?? "" }
        .onChange(of: text) { _, newValue in
            let parsed = Decimal(string: newValue.replacingOccurrences(of: ",", with: "."))
            value = parsed.flatMap { $0 > 0 && $0 < 1 ? $0 : nil }
        }
    }
}
struct OneOffCard: View {
    var pay: OneOffPay
    var name: (Deduction.Kind) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("One-off payment").textRole(.bodyStrong)
            HStack(alignment: .firstTextBaseline) {
                Text(pay.net.text).textRole(.figure)
                Text("of \(pay.gross.text)").textRole(.caption).foregroundStyle(Palette.secondaryText.color)
            }
            ForEach(pay.deductions.filter { $0.amount.cents > 0 }, id: \.kind) { deduction in
                HStack {
                    Text(name(deduction.kind)).textRole(.body)
                    Spacer()
                    Text("− \(deduction.amount.text)").textRole(.bodyStrong)
                }
                .frame(minHeight: 36)
            }
            Text("Paid once on top of the month above, taxed with the annual table.")
                .textRole(.caption).foregroundStyle(Palette.secondaryText.color)
        }
        .card()
    }
}
