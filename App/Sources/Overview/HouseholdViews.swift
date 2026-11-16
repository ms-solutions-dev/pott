import PottCore
import PottDesign
import PottFeatures
import PottStore
import SwiftUI

/// The household view: who pays how much, and by which rule.
struct HouseholdCard: View {
    @Environment(AppModel.self) private var model
    var household: Repository.HouseholdInfo
    var split: HouseholdSplit

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Payments into the pot").textRole(.caption).foregroundStyle(Palette.secondaryText.color)
            ForEach(Array(household.members.enumerated()), id: \.element.id) { index, member in
                MemberLine(
                    member: member, amount: split.contribution(of: member.id), share: share(of: member),
                    tint: tint(index))
            }
            HStack {
                Text("Shared costs and goals").textRole(.body).foregroundStyle(Palette.secondaryText.color)
                Spacer()
                Text(split.required.text).textRole(.bodyStrong)
            }
            Divider().overlay(Palette.separator.color)
            Text("How do you pay in?").textRole(.bodyStrong)
            FlowLayout(spacing: 6) {
                ForEach(SplitRule.allCases, id: \.self) { rule in
                    Chip(title(of: rule), isSelected: household.rule == rule) { model.setRule(rule) }
                }
            }
            RuleInputs(household: household)
            Text(explanation).textRole(.caption).foregroundStyle(Palette.secondaryText.color)
        }
        .card()
    }

    private func share(of member: Member) -> Double {
        split.paidIn.cents > 0
            ? Double(split.contribution(of: member.id).cents) / Double(split.paidIn.cents) : 0
    }

    private func tint(_ index: Int) -> Color {
        index == 0 ? Palette.accent.color : Palette.category(index + 1).color
    }

    private func title(of rule: SplitRule) -> String {
        switch rule {
        case .fixedAmounts: String(localized: "Fixed amount")
        case .equal: String(localized: "Equal")
        case .byIncome: String(localized: "By income")
        case .customShares: String(localized: "Own shares")
        }
    }

    private var explanation: String {
        switch household.rule {
        case .fixedAmounts:
            String(localized: "Everyone pays a fixed amount. Whatever is not needed stays in the pot.")
        case .equal: String(localized: "The shared costs are split equally.")
        case .byIncome: String(localized: "Whoever earns more pays proportionally more.")
        case .customShares: String(localized: "You agree on the percentages yourselves.")
        }
    }
}

private struct MemberLine: View {
    var member: Member
    var amount: Money
    var share: Double
    var tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Text(String(member.name.prefix(1)).uppercased())
                .textRole(.bodyStrong)
                .frame(width: 38, height: 38)
                .foregroundStyle(Palette.onAccent.color)
                .background(tint, in: .circle)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(member.name).textRole(.bodyStrong)
                GeometryReader { proxy in
                    Capsule().fill(Palette.track.color)
                        .overlay(alignment: .leading) {
                            Capsule().fill(tint).frame(width: proxy.size.width * share)
                        }
                }
                .frame(height: 6)
            }
            Text(amount.text).textRole(.amount)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Inputs the chosen rule needs: fixed amounts, partner incomes or percentages.
private struct RuleInputs: View {
    @Environment(AppModel.self) private var model
    var household: Repository.HouseholdInfo

    var body: some View {
        switch household.rule {
        case .fixedAmounts:
            ForEach(household.members) { member in
                MemberAmountField(
                    member: member,
                    title: member.id == model.settings.meMemberID ? "You pay (€)" : "\(member.name) pays (€)",
                    keyPath: \.fixedContribution)
            }
        case .byIncome:
            ForEach(household.members.filter { $0.id != model.settings.meMemberID }) { member in
                MemberAmountField(
                    member: member, title: "Net income of \(member.name) (€)", keyPath: \.monthlyNetIncome)
            }
        case .customShares:
            ForEach(household.members) { member in
                MemberPercentField(member: member, isMe: member.id == model.settings.meMemberID)
            }
        case .equal:
            EmptyView()
        }
    }
}

private struct MemberAmountField: View {
    @Environment(AppModel.self) private var model
    var member: Member
    var title: LocalizedStringKey
    var keyPath: WritableKeyPath<Member, Money>
    @State private var text = ""

    var body: some View {
        AmountField(title: title, text: $text)
            .onAppear { text = member[keyPath: keyPath].editingText() }
            // Save after a short pause, so shared members do not see every keystroke (8, 80, 800 …).
            .task(id: text) {
                try? await Task.sleep(for: .milliseconds(900))
                guard !Task.isCancelled, let amount = Money.parse(text), amount != member[keyPath: keyPath]
                else { return }
                var updated = member
                updated[keyPath: keyPath] = amount
                model.save(updated)
            }
    }
}

private struct MemberPercentField: View {
    @Environment(AppModel.self) private var model
    var member: Member
    var isMe: Bool
    @State private var text = ""

    var body: some View {
        AmountField(title: isMe ? "Your share in %" : "Share of \(member.name) in %", text: $text)
            .onAppear { text = "\(member.sharePercent)" }
            .task(id: text) {
                try? await Task.sleep(for: .milliseconds(900))
                guard !Task.isCancelled, let parsed = Money.parse(text), parsed.decimal != member.sharePercent
                else { return }
                var updated = member
                updated.sharePercent = min(max(parsed.decimal, 0), 100)
                model.save(updated)
            }
    }
}

/// Savings goals as a horizontal strip.
struct GoalsStrip: View {
    @Environment(AppModel.self) private var model
    @Environment(ToastCenter.self) private var toasts
    var goals: [SavingsGoal]
    var scope: OverviewScope
    var open: (SavingsGoal) -> Void
    var onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionTitle(title: scope == .together ? "Shared savings goals" : "Savings goals")
                Spacer()
                Button("+ New goal", action: onAdd)
                    .textRole(.bodyStrong)
                    .foregroundStyle(Palette.accentText.color)
                    .frame(minHeight: 44)
            }
            if goals.isEmpty {
                EmptyHint(
                    title: String(localized: "No savings goal yet"),
                    message: String(
                        localized:
                            "A holiday, a new phone, an emergency fund: Pott works out the monthly rate."),
                    action: onAdd)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(goals) { goal in
                            GoalCard(goal: goal, shared: model.householdActive && goal.scope == .household) {
                                open(goal)
                            } deposit: {
                                let before = model.deposit(into: goal)
                                toasts.show(
                                    String(localized: "\(goal.monthlyRate.text) saved for “\(goal.name)”")
                                ) { model.save(before) }
                            }
                        }
                    }
                }
                .scrollClipDisabled()
            }
        }
        .padding(.top, 18)
    }
}

private struct GoalCard: View {
    var goal: SavingsGoal
    var shared: Bool
    var open: () -> Void
    var deposit: () -> Void

    var body: some View {
        let tint = shared ? Palette.shared.color : Palette.ring.color
        VStack(alignment: .leading, spacing: 8) {
            Button(action: open) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 10) {
                        RingGauge(
                            progress: (goal.progress as NSDecimalNumber).doubleValue, tint: tint,
                            lineWidth: 7, glows: false
                        ) {
                            EmptyView()
                        }
                        .frame(width: 58, height: 58)
                        Text("\(Int(((goal.progress as NSDecimalNumber).doubleValue * 100).rounded())) %")
                            .textRole(.amount)
                            .foregroundStyle(shared ? Palette.shared.color : Palette.accentText.color)
                    }
                    Text(goal.name).textRole(.bodyStrong).lineLimit(1)
                    Text("\(goal.saved.text) of \(goal.target.text)").textRole(.caption).foregroundStyle(
                        Palette.secondaryText.color)
                    Text(status).textRole(.caption).foregroundStyle(Palette.secondaryText.color)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            Button(action: deposit) {
                Text("+\(goal.monthlyRate.text) saved")
                    .textRole(.bodyStrong)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Palette.raised.color, in: .rect(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(goal.isReached)
            .sensoryFeedback(.success, trigger: goal.saved)
        }
        .frame(width: 208)
        .card(padding: 14)
    }

    private var status: String {
        if goal.isReached { return String(localized: "Goal reached") }
        return String(localized: "\(goal.monthlyRate.text) a month for \(goal.months) months")
    }
}
