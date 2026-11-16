import PottCore
import PottDesign
import PottFeatures
import SwiftUI
import TaxDE

/// The calculator for the self-employed: monthly profit to what can be taken out, and back. The
/// direction and whether the profit comes from a day rate are chosen in the picker at the top.
struct SelfEmployedSection: View {
    @Environment(AppModel.self) private var model
    @Binding var desired: Bool
    /// Changes when the picker changes, to let the result swell.
    var bump: String
    @State private var amountText = ""
    @State private var showsDetails = ProcessInfo.processInfo.arguments.contains("-PottInsurerOpen")
    @State private var taking = false

    private let calculator = GermanSelfEmployedCalculator()

    var body: some View {
        @Bindable var settings = model.settings
        let input = settings.selfEmployedInput
        let result = currentResult
        VStack(alignment: .leading, spacing: 16) {
            AmountField(
                title: desired
                    ? "Desired take-out per month (€)"
                    : input.usesDayRate ? "Day rate (€)" : "Profit per month (€)",
                text: $amountText, large: true
            )
            .onAppear { amountText = mainAmount.editingText() }
            .onChange(of: input.usesDayRate) { _, _ in amountText = mainAmount.editingText() }
            .onChange(of: amountText) { _, value in
                guard !desired, let amount = Money.parse(value) else { return }
                if model.settings.selfEmployedInput.usesDayRate {
                    model.settings.selfEmployedInput.dayRate = amount
                } else {
                    model.settings.selfEmployedInput.monthlyProfit = amount
                }
            }
            if input.usesDayRate {
                dayRateCard
            } else {
                Text("Profit means revenue minus business costs, without VAT.")
                    .textRole(.caption).foregroundStyle(Palette.secondaryText.color)
            }

            VStack(alignment: .leading, spacing: 6) {
                Toggle("Side business next to my job", isOn: $settings.selfEmployedInput.sideline)
                if input.sideline {
                    Text(
                        "Taxed on top of the salary entered for the main job; health insurance runs through the job."
                    )
                    .textRole(.caption).foregroundStyle(Palette.secondaryText.color)
                }
            }
            .textRole(.body)
            .card()

            VStack(alignment: .leading, spacing: 12) {
                Toggle("Trade business", isOn: $settings.selfEmployedInput.isTrade)
                if input.isTrade {
                    Stepper(value: $settings.selfEmployedInput.tradeTaxRate, in: 200...900, step: 5) {
                        Text("Trade tax multiplier: \(input.tradeTaxRate) %")
                    }
                } else {
                    Text("Freelancers (doctors, designers, developers …) pay no trade tax.")
                        .textRole(.caption).foregroundStyle(Palette.secondaryText.color)
                }
            }
            .textRole(.body)
            .card()

            vatCard(result)

            insurance(result)

            startupGrantCard

            details

            resultCard(result)

            Text(
                "Example calculation without guarantee, income tax by the 2026 tariff. Assumes the same profit every month. Child benefit is checked against the child allowances but not counted as income. VAT is shown but is not part of the profit. Not included: other income and deductions, and the artists’ fund subsidy for private insurance."
            )
            .textRole(.caption)
            .foregroundStyle(Palette.secondaryText.color)
        }
        .animation(.snappy, value: input)
        .sheet(isPresented: $taking) {
            if let result {
                TakeOverSheet(
                    result: result.monthly, defaultName: String(localized: "Self-employed"),
                    summary: String(localized: "Profit \(result.monthly.gross.text) · self-employed"))
            }
        }
    }

    private var currentResult: SelfEmployedResult? {
        guard let amount = Money.parse(amountText), amount.cents > 0 else { return nil }
        var input = model.settings.selfEmployedInput
        let salary = input.sideline ? model.settings.payInput : nil
        if desired { return calculator.profitNeeded(forNet: amount, input, salary: salary) }
        if input.usesDayRate { input.dayRate = amount } else { input.monthlyProfit = amount }
        return calculator.calculate(input, salary: salary)
    }

    /// The amount in the big field: the day rate or the monthly profit.
    private var mainAmount: Money {
        let input = model.settings.selfEmployedInput
        return input.usesDayRate ? input.dayRate : input.monthlyProfit
    }

    private var dayRateCard: some View {
        @Bindable var settings = model.settings
        let input = settings.selfEmployedInput
        return VStack(alignment: .leading, spacing: 12) {
            Stepper(value: $settings.selfEmployedInput.daysPerWeek, in: 1...7) {
                Text("Days per week: \(input.daysPerWeek)")
            }
            Stepper(value: $settings.selfEmployedInput.daysOff, in: 0...200, step: 5) {
                Text("Days off a year: \(input.daysOff)")
            }
            MoneyRow(title: "Business costs per month", value: $settings.selfEmployedInput.businessCosts)
            Text(
                "≈ \(input.billableDays) billable days a year · profit \(input.effectiveMonthlyProfit.text) a month. Days off are holidays, sick days, public holidays and gaps."
            )
            .textRole(.caption).foregroundStyle(Palette.secondaryText.color)
        }
        .textRole(.body)
        .card()
    }

    // MARK: VAT

    private func vatCard(_ result: SelfEmployedResult?) -> some View {
        @Bindable var settings = model.settings
        let input = settings.selfEmployedInput
        return VStack(alignment: .leading, spacing: 12) {
            Text("VAT").textRole(.caption).foregroundStyle(Palette.secondaryText.color)
            Toggle("Small business, no VAT (§ 19 UStG)", isOn: $settings.selfEmployedInput.smallBusiness)
            if input.smallBusiness {
                MoneyRow(title: "Revenue last year", value: $settings.selfEmployedInput.previousYearRevenue)
                MoneyRow(
                    title: "Expected revenue this year", value: $settings.selfEmployedInput.expectedRevenue)
                if input.expectedRevenue == .zero {
                    Text(
                        "Left at 0, it is estimated from your profit and costs: \((input.monthlyRevenue * 12).text)."
                    )
                    .textRole(.caption).foregroundStyle(Palette.secondaryText.color)
                }
                if let check = result?.smallBusinessCheck {
                    smallBusinessNote(check)
                }
            }
            if !input.smallBusiness || result?.smallBusinessCheck != .applies {
                Picker("VAT rate", selection: $settings.selfEmployedInput.vatRate) {
                    Text(verbatim: "19 %").tag(Decimal(19))
                    Text(verbatim: "7 %").tag(Decimal(7))
                }
                .pickerStyle(.segmented)
                if let result, result.monthlyVAT > .zero {
                    Text(
                        "Charge \(result.monthlyVAT.text) VAT a month on top of your invoices and pass it on to the tax office. It is not part of the profit."
                    )
                    .textRole(.caption).foregroundStyle(Palette.secondaryText.color)
                    if input.usesDayRate {
                        Text("Day rate on the invoice: \((input.dayRate * (1 + input.vatRate / 100)).text)")
                            .textRole(.bodyStrong)
                    }
                }
            }
        }
        .textRole(.body)
        .card()
    }

    @ViewBuilder
    private func smallBusinessNote(_ check: SmallBusinessCheck) -> some View {
        let (text, ok): (LocalizedStringKey, Bool) =
            switch check {
            case .applies:
                (
                    "The small business rule applies: no VAT on your invoices, but no refund of VAT you pay either.",
                    true
                )
            case .previousYearTooHigh:
                ("Revenue last year was above €25,000, so you charge VAT this year.", false)
            case .currentYearTooHigh:
                (
                    "Revenue this year goes above €100,000, so the small business rule no longer applies.",
                    false
                )
            }
        Label {
            Text(text).textRole(.caption)
        } icon: {
            Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(ok ? Palette.accentText.color : Palette.negative.color)
        }
        .transition(.opacity)
    }

    // MARK: Insurance and pension

    private func insurance(_ result: SelfEmployedResult?) -> some View {
        @Bindable var settings = model.settings
        let input = settings.selfEmployedInput
        return VStack(alignment: .leading, spacing: 12) {
            Toggle("Artists’ social insurance (KSK)", isOn: $settings.selfEmployedInput.artistsInsurance)
            if input.artistsInsurance {
                Text(
                    "For artists and publicists: the Künstlersozialkasse pays the other half of health, care and pension insurance."
                )
                .textRole(.caption).foregroundStyle(Palette.secondaryText.color)
                if result?.belowArtistsMinimum == true {
                    Label {
                        Text(
                            "Up to €3,900 a year from artistic work you are only insured through the KSK in your first three years."
                        )
                        .textRole(.caption)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(
                            Palette.negative.color)
                    }
                }
            }
            Divider()
            if input.sideline {
                Text("Health and care insurance run through your job.")
                    .textRole(.caption).foregroundStyle(Palette.secondaryText.color)
            } else {
                Text("Health insurance").textRole(.caption).foregroundStyle(Palette.secondaryText.color)
                Picker("Health insurance", selection: $settings.selfEmployedInput.health) {
                    Text("Statutory").tag(SelfEmployedHealth.statutory)
                    Text("Private").tag(SelfEmployedHealth.private)
                }
                .pickerStyle(.segmented)
                switch input.health {
                case .statutory:
                    Toggle("With sick pay", isOn: $settings.selfEmployedInput.withSickPay)
                    HealthInsurerRow(
                        rate: $settings.selfEmployedInput.healthAdditionalRate,
                        insurer: $settings.selfEmployedInput.healthInsurer, year: input.year,
                        region: input.region)
                    Text(
                        input.artistsInsurance
                            ? "You pay half, at least on €659.17 a month."
                            : "You pay the full rate yourself, at least on €1,318.33 a month."
                    )
                    .textRole(.caption).foregroundStyle(Palette.secondaryText.color)
                case .private:
                    MoneyRow(
                        title: "Health premium per month",
                        value: $settings.selfEmployedInput.privateHealthPremium
                    )
                    MoneyRow(
                        title: "Care premium per month", value: $settings.selfEmployedInput.privateCarePremium
                    )
                }
            }
            Divider()
            Text("Pension").textRole(.caption).foregroundStyle(Palette.secondaryText.color)
            if input.artistsInsurance {
                Text("Statutory pension through the KSK: you pay half of 18.6 % of your income.")
                    .textRole(.caption).foregroundStyle(Palette.secondaryText.color)
            } else {
                Picker("Statutory pension", selection: $settings.selfEmployedInput.pension) {
                    Text("None").tag(SelfEmployedPension.none)
                    Text("On the profit").tag(SelfEmployedPension.statutory)
                    Text("Standard contribution").tag(SelfEmployedPension.standardContribution)
                    Text("Half, first three years").tag(SelfEmployedPension.halfStandardContribution)
                }
                .pickerStyle(.menu)
                .tint(Palette.accentText.color)
                pensionNote(input.pension)
            }
            MoneyRow(
                title: "Basic pension (Rürup) per month", value: $settings.selfEmployedInput.basicPension)
            Text("Deducted as special expense together with the statutory pension, up to €30,826 a year.")
                .textRole(.caption).foregroundStyle(Palette.secondaryText.color)
        }
        .textRole(.body)
        .card()
    }

    @ViewBuilder
    private func pensionNote(_ pension: SelfEmployedPension) -> some View {
        let text: LocalizedStringKey? =
            switch pension {
            case .none: nil
            case .statutory: "18.6 % of the profit, at least on €603 and at most on €8,450 a month."
            case .standardContribution:
                "Compulsory for some self-employed, e.g. craftspeople, teachers and midwives (§ 2 SGB VI): €735.63 a month in 2026, or by income with proof."
            case .halfStandardContribution:
                "Until three calendar years after the year you started: half the standard contribution, €367.82 a month."
            }
        if let text {
            Text(text).textRole(.caption).foregroundStyle(Palette.secondaryText.color)
        }
    }

    // MARK: Start-up grant

    private var startupGrantCard: some View {
        @Bindable var settings = model.settings
        let input = settings.selfEmployedInput
        return VStack(alignment: .leading, spacing: 12) {
            Text("Start-up grant (Gründungszuschuss)").textRole(.caption).foregroundStyle(
                Palette.secondaryText.color)
            Picker("Start-up grant", selection: $settings.selfEmployedInput.startupGrant) {
                Text("None").tag(StartupGrantPhase.none)
                Text("Months 1–6").tag(StartupGrantPhase.first)
                Text("Months 7–15").tag(StartupGrantPhase.second)
            }
            .pickerStyle(.segmented)
            switch input.startupGrant {
            case .none:
                EmptyView()
            case .first:
                MoneyRow(
                    title: "Last unemployment benefit per month",
                    value: $settings.selfEmployedInput.unemploymentBenefit)
                Text("Your last unemployment benefit plus €300 a month for social insurance. Tax-free.")
                    .textRole(.caption).foregroundStyle(Palette.secondaryText.color)
            case .second:
                Text("€300 a month for nine more months, if the employment agency agrees. Tax-free.")
                    .textRole(.caption).foregroundStyle(Palette.secondaryText.color)
            }
        }
        .textRole(.body)
        .card()
    }

    // MARK: Details and result

    private var details: some View {
        @Bindable var settings = model.settings
        let input = settings.selfEmployedInput
        return VStack(spacing: 0) {
            DisclosureGroup(isExpanded: $showsDetails) {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("State", selection: $settings.selfEmployedInput.region) {
                        ForEach(GermanState.all, id: \.code) { state in
                            Text(verbatim: state.name).tag(state.code)
                        }
                    }
                    Toggle("Church tax", isOn: $settings.selfEmployedInput.churchMember)
                    Toggle("Married, taxed jointly", isOn: $settings.selfEmployedInput.married)
                    if input.married {
                        MoneyRow(
                            title: "Partner’s taxable income per year",
                            value: $settings.selfEmployedInput.partnerTaxableIncome)
                    }
                    Stepper(value: $settings.selfEmployedInput.childrenUnder25, in: 0...10) {
                        Text("Children under 25: \(input.childrenUnder25)")
                    }
                    Toggle("Has had children", isOn: $settings.selfEmployedInput.isParent)
                }
                .textRole(.body)
                .padding(.top, 10)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("More details").textRole(.bodyStrong)
                    Text(summary(input)).textRole(.caption).foregroundStyle(Palette.secondaryText.color)
                }
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .card()
    }

    private func summary(_ input: SelfEmployedInput) -> String {
        let state = GermanState.all.first { $0.code == input.region }?.name ?? input.region
        let church = input.churchMember ? String(localized: "church tax") : String(localized: "no church tax")
        let status = input.married ? String(localized: "married") : String(localized: "single")
        return "\(state) · \(church) · \(status)"
    }

    private func name(_ kind: Deduction.Kind) -> String {
        if kind == .pensionInsurance && model.settings.selfEmployedInput.artistsInsurance {
            return String(localized: "Pension insurance (KSK)")
        }
        return CalculatorView.title(of: kind)
    }

    @ViewBuilder
    private func resultCard(_ result: SelfEmployedResult?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let result {
                let pay = result.monthly
                Text(desired ? "Profit needed" : "You can take out").textRole(.bodyStrong).opacity(0.8)
                Text((desired ? pay.gross : pay.net).text)
                    .textRole(.figure)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: pay.net)
                    .bump(on: bump)
                if desired {
                    Text("leaves \(pay.net.text) to take out").textRole(.caption)
                    if model.settings.selfEmployedInput.usesDayRate,
                        let rate = model.settings.selfEmployedInput.dayRate(forMonthlyProfit: pay.gross)
                    {
                        Text("Day rate needed: \(rate.text)").textRole(.bodyStrong)
                    }
                }
                Button("Take over as income") { taking = true }
                    .textRole(.bodyStrong)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .foregroundStyle(Palette.accent.color)
                    .background(Palette.onAccent.color, in: .rect(cornerRadius: 16, style: .continuous))
                    .padding(.vertical, 6)
                ForEach(pay.deductions.filter { $0.amount.cents > 0 || $0.kind == .incomeTax }, id: \.kind) {
                    deduction in
                    HStack {
                        Text(name(deduction.kind)).textRole(.body)
                        Spacer()
                        Text("− \(deduction.amount.text)").textRole(.bodyStrong)
                    }
                    .frame(minHeight: 40)
                }
                if pay.startupGrant > .zero {
                    HStack {
                        Text("Start-up grant").textRole(.body)
                        Spacer()
                        Text("+ \(pay.startupGrant.text)").textRole(.bodyStrong)
                    }
                    .frame(minHeight: 40)
                }
                Divider().overlay(Palette.onAccent.color.opacity(0.3))
                Text("Put aside each quarter: \(result.quarterlyTaxReserve.text) tax advance")
                    .textRole(.bodyStrong)
                if result.quarterlyTradeTax > .zero {
                    Text("plus \(result.quarterlyTradeTax.text) trade tax").textRole(.body)
                }
                if result.monthlyVAT > .zero {
                    Text("plus \(result.monthlyVAT.text) VAT a month to pass on").textRole(.body)
                }
            } else {
                Text("Enter an amount").textRole(.bodyStrong)
            }
        }
        .foregroundStyle(Palette.onAccent.color)
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.accent.color, in: .rect(cornerRadius: 22, style: .continuous))
    }
}
