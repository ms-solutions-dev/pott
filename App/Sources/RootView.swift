import LocalAuthentication
import PottDesign
import PottFeatures
import SwiftUI

/// Tabs, onboarding, the Face ID lock and toasts.
struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(ToastCenter.self) private var toasts
    @Environment(\.scenePhase) private var phase
    @State private var locked = false

    var body: some View {
        @Bindable var settings = model.settings
        ZStack(alignment: .bottom) {
            Palette.background.color.ignoresSafeArea()
            Group {
                switch currentTab {
                case .overview: OverviewView()
                case .calculator: CalculatorView()
                }
            }
            if model.settings.isOn(.calculator) {
                TabBar()
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
            }
            if let toast = toasts.current {
                Toast(toast.message, undoTitle: toast.undo == nil ? nil : String(localized: "Undo")) {
                    toasts.performUndo()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, model.settings.isOn(.calculator) ? 88 : 16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .id(toast.id)
            }
            if locked {
                LockView { unlock() }
                    .transition(.opacity)
            }
        }
        .animation(.spring(duration: 0.35), value: toasts.current?.id)
        .preferredColorScheme(colorScheme)
        .fullScreenCover(isPresented: onboarding) { OnboardingView() }
        .alert(
            "Something went wrong", isPresented: failureShown,
            actions: { Button("OK") { model.failure = nil } },
            message: { Text(model.failure ?? "") }
        )
        .onAppear { if settings.requiresFaceID { locked = true } }
        .onChange(of: phase) { _, new in
            if new == .background && settings.requiresFaceID { locked = true }
            if new == .active { model.reload() }
        }
    }

    /// The calculator tab disappears with its module.
    private var currentTab: AppTab {
        model.settings.isOn(.calculator) ? router.tab : .overview
    }

    private var colorScheme: ColorScheme? {
        switch model.settings.appearance {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    private var onboarding: Binding<Bool> {
        Binding(get: { !model.settings.hasOnboarded }, set: { if !$0 { model.settings.hasOnboarded = true } })
    }

    private var failureShown: Binding<Bool> {
        Binding(get: { model.failure != nil }, set: { if !$0 { model.failure = nil } })
    }

    private func unlock() {
        let context = LAContext()
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: String(localized: "Unlock Pott"))
        { success, _ in
            Task { @MainActor in
                if success { withAnimation { locked = false } }
            }
        }
    }
}

/// The floating tab bar.
private struct TabBar: View {
    @Environment(Router.self) private var router

    var body: some View {
        HStack(spacing: 6) {
            item(.overview, title: "Overview", symbol: "chart.pie.fill")
            item(.calculator, title: "Calculator", symbol: "function")
        }
        .padding(6)
        .background(.ultraThinMaterial, in: .capsule)
        .shadow(color: .black.opacity(0.25), radius: 18, y: 8)
    }

    private func item(_ tab: AppTab, title: LocalizedStringKey, symbol: String) -> some View {
        let selected = router.tab == tab
        return Button {
            withAnimation(.spring(duration: 0.3)) { router.tab = tab }
        } label: {
            Label(title, systemImage: symbol)
                .labelStyle(TabLabelStyle())
                .textRole(.bodyStrong)
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: 52)
                .foregroundStyle(selected ? Palette.onAccent.color : Palette.secondaryText.color)
                .background(selected ? Palette.accent.color : .clear, in: .capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .sensoryFeedback(.selection, trigger: selected)
    }
}

/// Icon and title; with accessibility text sizes only the icon, the title stays for VoiceOver.
private struct TabLabelStyle: LabelStyle {
    @Environment(\.dynamicTypeSize) private var size

    func makeBody(configuration: Configuration) -> some View {
        if size.isAccessibilitySize {
            configuration.icon.font(.title2)
        } else {
            HStack(spacing: 8) {
                configuration.icon
                configuration.title
            }
        }
    }
}

/// Covers the app until Face ID or the passcode unlocks it.
private struct LockView: View {
    var unlock: () -> Void

    var body: some View {
        ZStack {
            Palette.background.color.ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "lock.fill").font(.system(size: 44)).foregroundStyle(
                    Palette.accentText.color)
                Text("Pott is locked").textRole(.title)
                Button("Unlock", action: unlock).buttonStyle(AccentButtonStyle()).padding(.horizontal, 40)
            }
        }
        .onAppear(perform: unlock)
    }
}
