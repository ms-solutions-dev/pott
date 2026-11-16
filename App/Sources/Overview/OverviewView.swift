import PottCore
import PottDesign
import PottFeatures
import SwiftUI

/// The main screen: what is left this month, how it is computed, savings goals and fixed costs.
struct OverviewView: View {
    @Environment(AppModel.self) private var model
    @Environment(ToastCenter.self) private var toasts
    /// `-PottTogether` opens the household view directly, for screenshots.
    @State private var scope: OverviewScope =
        ProcessInfo.processInfo.arguments.contains("-PottTogether") ? .together : .me
    /// `-PottScreen settings|incomes|cost|goal` opens a sheet directly, for checks and screenshots.
    @State private var route: Route? = Self.launchRoute()

    private static func launchRoute() -> Route? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-PottScreen"), arguments.indices.contains(index + 1)
        else { return nil }
        switch arguments[index + 1] {
        case "settings": return .settings
        case "incomes": return .incomes
        case "cost": return .cost(nil)
        case "goal": return .goal(nil)
        default: return nil
        }
    }

    enum Route: Identifiable {
        case settings
        case incomes
        case cost(FixedCost?)
        case goal(SavingsGoal?)

        var id: String {
            switch self {
            case .settings: "settings"
            case .incomes: "incomes"
            case .cost(let cost): "cost-\(cost?.id.uuidString ?? "new")"
            case .goal(let goal): "goal-\(goal?.id.uuidString ?? "new")"
            }
        }
    }

    private var visibleScope: OverviewScope { model.householdActive ? scope : .me }

    var body: some View {
        let budget = model.budget
        let costs = model.costs(for: visibleScope)
        let goals = model.goals(for: visibleScope)
        ScrollViewReader { proxy in
            List {
                Group {
                    header
                    HeroRing(budget: budget, scope: visibleScope)
                        .frame(minHeight: 240)
                        .frame(maxWidth: .infinity)
                    if model.needsIdentity {
                        EmptyHint(
                            title: String(localized: "You joined a shared household"),
                            message: String(
                                localized: "Tap here and pick yourself, then Pott works out your share.")
                        ) { route = .settings }
                    }
                    if visibleScope == .me {
                        BreakdownCard(budget: budget) { route = .incomes }
                    } else if let household = model.household, let pot = budget.household {
                        HouseholdCard(household: household, split: pot)
                    }
                    if model.savingsActive {
                        GoalsStrip(goals: goals, scope: visibleScope) {
                            route = .goal($0)
                        } onAdd: {
                            route = .goal(nil)
                        }
                    }
                    if model.settings.isOn(.contractReminders) {
                        DeadlinesCard { route = .cost($0) }.id("deadlines")
                    }
                    if model.settings.isOn(.monthlyReview) && visibleScope == .me {
                        MonthlyReviewCard().id("review")
                    }
                    costsHeader(costs)
                }
                .plainRow()

                if costs.isEmpty {
                    EmptyHint(
                        title: String(localized: "No fixed costs yet"),
                        message: String(
                            localized:
                                "Tap here to add rent, a phone contract or anything else that is due regularly."
                        )
                    ) { route = .cost(nil) }
                    .plainRow()
                }
                ForEach(model.groups(costs)) { group in
                    if let category = group.category, model.settings.sort == .category {
                        GroupHeader(category: category, total: group.total).plainRow(top: 10)
                    }
                    ForEach(group.costs) { cost in
                        CostRow(cost: cost, showsCategory: model.settings.sort != .category) {
                            route = .cost(cost)
                        }
                        .plainRow(top: 3, bottom: 3)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                delete(cost)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                togglePause(cost)
                            } label: {
                                Label(
                                    cost.isPaused ? "Resume" : "Pause",
                                    systemImage: cost.isPaused ? "play" : "pause")
                            }
                            .tint(Palette.shared.color)
                        }
                        .contextMenu {
                            Button {
                                route = .cost(cost)
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            Button {
                                duplicate(cost)
                            } label: {
                                Label("Duplicate", systemImage: "plus.square.on.square")
                            }
                            Button {
                                togglePause(cost)
                            } label: {
                                Label(
                                    cost.isPaused ? "Resume" : "Pause",
                                    systemImage: cost.isPaused ? "play" : "pause")
                            }
                            Button(role: .destructive) {
                                delete(cost)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                Color.clear.frame(height: 96).plainRow()
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Palette.background.color)
            .task {
                // `-PottScrollTo review|deadlines` for checks and screenshots.
                let arguments = ProcessInfo.processInfo.arguments
                if let index = arguments.firstIndex(of: "-PottScrollTo"),
                    arguments.indices.contains(index + 1)
                {
                    try? await Task.sleep(for: .milliseconds(400))
                    proxy.scrollTo(arguments[index + 1], anchor: .top)
                }
            }
        }
        .sheet(item: $route) { route in
            switch route {
            case .settings: SettingsView()
            case .incomes: IncomesSheet()
            case .cost(let cost):
                CostEditor(cost: cost, defaultScope: visibleScope == .together ? .household : .personal)
            case .goal(let goal):
                GoalEditor(goal: goal, defaultScope: visibleScope == .together ? .household : .personal)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            // The same title in every mode; the household switch sits below it.
            VStack(alignment: .leading, spacing: 4) {
                Text(Date.now.formatted(.dateTime.month(.wide).year()))
                    .textRole(.caption)
                    .foregroundStyle(Palette.secondaryText.color)
                Text("Your month").textRole(.title).accessibilityAddTraits(.isHeader)
                if model.householdActive {
                    Picker("View", selection: $scope) {
                        Text("Me").tag(OverviewScope.me)
                        Text("Together").tag(OverviewScope.together)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 230)
                    .padding(.top, 4)
                }
            }
            Spacer()
            CircleButton(symbol: "gearshape", label: "Settings") { route = .settings }
            CircleButton(symbol: "plus", label: "Add fixed cost", prominent: true) { route = .cost(nil) }
        }
        .padding(.top, 8)
    }

    private func costsHeader(_ costs: [FixedCost]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionTitle(
                    title: visibleScope == .together
                        ? "Shared costs" : (model.householdActive ? "My fixed costs" : "Fixed costs"))
                Spacer()
                Text(costs.map(\.monthlyAmount).sum().text).textRole(.amount)
            }
            if !model.settings.hasSeenSwipeHint && !costs.isEmpty {
                // Gestures are invisible; say once what they do.
                HStack(spacing: 10) {
                    Image(systemName: "hand.draw").foregroundStyle(Palette.accentText.color)
                    Text("Tip: swipe left to delete, right to pause, or tap and hold for more.")
                        .textRole(.caption)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button {
                        withAnimation { model.settings.hasSeenSwipeHint = true }
                    } label: {
                        Image(systemName: "xmark").frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Hide tip")
                }
                .padding(.leading, 12)
                .background(Palette.card.color, in: .rect(cornerRadius: 14, style: .continuous))
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    Chip(String(localized: "Category"), isSelected: model.settings.sort == .category) {
                        model.settings.sort = .category
                    }
                    Chip(String(localized: "Amount"), isSelected: model.settings.sort == .amount) {
                        model.settings.sort = .amount
                    }
                    Chip(String(localized: "Due date"), isSelected: model.settings.sort == .dueDate) {
                        model.settings.sort = .dueDate
                    }
                }
            }
            .accessibilityLabel("Sort")
        }
        .padding(.top, 18)
    }

    private func delete(_ cost: FixedCost) {
        model.delete(cost)
        toasts.show(String(localized: "“\(cost.name)” deleted")) { model.save(cost) }
    }

    private func togglePause(_ cost: FixedCost) {
        var updated = cost
        updated.isPaused.toggle()
        model.save(updated)
        toasts.show(
            updated.isPaused
                ? String(localized: "“\(cost.name)” paused") : String(localized: "“\(cost.name)” resumed")
        ) {
            model.save(cost)
        }
    }

    private func duplicate(_ cost: FixedCost) {
        var copy = cost
        copy.id = UUID()
        copy.name = String(localized: "\(cost.name) (copy)")
        model.save(copy)
        route = .cost(copy)
    }
}

extension View {
    /// A list row without background, separator or default insets.
    func plainRow(top: CGFloat = 6, bottom: CGFloat = 6) -> some View {
        listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: top, leading: 18, bottom: bottom, trailing: 18))
    }
}

/// A round icon button, 46 pt.
struct CircleButton: View {
    var symbol: String
    var label: LocalizedStringKey
    var prominent = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 19, weight: .semibold))
                .frame(width: 46, height: 46)
                .foregroundStyle(prominent ? Palette.onAccent.color : Palette.text.color)
                .background(prominent ? Palette.accent.color : Palette.card.color, in: .circle)
                .shadow(color: prominent ? Palette.accent.color.opacity(0.45) : .clear, radius: 12)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
