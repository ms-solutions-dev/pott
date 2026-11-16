import PottCore
import PottDesign
import PottFeatures
import SwiftUI

/// What the calculator works out: the kind of work, the direction and the tax class (or, for the
/// self-employed, whether the profit is entered directly or from a day rate).
enum CalculatorKind: Hashable, Sendable, CaseIterable {
    case main
    case secondary
    case mini
    case selfEmployed

    var title: String {
        switch self {
        case .main: String(localized: "Main job")
        case .secondary: String(localized: "Second job")
        case .mini: String(localized: "Mini job")
        case .selfEmployed: String(localized: "Self-employed")
        }
    }
}

/// The calculator's choices in one place, read from and written to the settings.
@MainActor
struct CalculatorChoice {
    var settings: AppSettings
    @Binding var desired: Bool

    var kind: CalculatorKind {
        get {
            if settings.calculatorSelfEmployed { return .selfEmployed }
            switch settings.payInput.employment {
            case .main: return .main
            case .secondary: return .secondary
            case .mini: return .mini
            }
        }
        nonmutating set {
            switch newValue {
            case .selfEmployed: settings.calculatorSelfEmployed = true
            case .main, .secondary, .mini:
                settings.calculatorSelfEmployed = false
                settings.payInput.employment =
                    newValue == .main ? .main : newValue == .secondary ? .secondary : .mini
                // A mini job has only one direction.
                if newValue == .mini { desired = false }
            }
        }
    }

    static let roman = ["I", "II", "III", "IV", "V", "VI"]

    /// The three parts of the sentence: kind · direction · class or input.
    var parts: [String] {
        let direction: String
        switch kind {
        case .mini: direction = String(localized: "Gross → net")
        case .selfEmployed:
            direction =
                desired ? String(localized: "Desired take-out") : String(localized: "Profit → take-out")
        case .main, .secondary:
            direction = desired ? String(localized: "Desired net") : String(localized: "Gross → net")
        }
        let last: String
        switch kind {
        case .main: last = String(localized: "Class \(Self.roman[settings.payInput.taxClass - 1])")
        case .secondary: last = String(localized: "Class \(Self.roman[5])")
        case .mini: last = String(localized: "flat-rate")
        case .selfEmployed:
            last =
                settings.selfEmployedInput.usesDayRate
                ? String(localized: "Day rate") : String(localized: "Profit")
        }
        return [kind.title, direction, last]
    }

    /// Changes whenever any choice changes; drives the animations.
    var key: String { parts.joined(separator: "|") }

    /// The line under the wheels: what the current choice means.
    var explanation: AttributedString {
        let title: String
        let detail: String
        switch kind {
        case .mini:
            title = String(localized: "Mini job:")
            detail = String(
                localized:
                    "no wage tax, no health or care insurance. Only 3.6 % pension insurance, unless you are exempt."
            )
        case .secondary:
            title = String(localized: "Second job:")
            detail = String(localized: "always taxed in class VI, which is why the deductions are higher.")
        case .selfEmployed:
            title = String(localized: "Self-employed:")
            detail = String(
                localized:
                    "income tax instead of wage tax, health and care insurance paid in full yourself, pension voluntary or compulsory for some professions."
            )
        case .main:
            let taxClass = settings.payInput.taxClass
            title = String(localized: "Class \(Self.roman[taxClass - 1]):")
            detail = Self.classMeaning(taxClass)
        }
        var bold = AttributedString(title)
        bold.font = TextRole.bodyStrong.font
        bold.foregroundColor = Palette.text.color
        return bold + AttributedString(" " + detail)
    }

    static func classMeaning(_ taxClass: Int) -> String {
        switch taxClass {
        case 1: String(localized: "single, separated or widowed.")
        case 2: String(localized: "single parent.")
        case 3: String(localized: "married, earns more.")
        case 4: String(localized: "married, both earn about the same.")
        case 5: String(localized: "married, earns less.")
        default: String(localized: "second job.")
        }
    }
}

/// The card at the top of the calculator: reads like a sentence ("Main job · Gross → net ·
/// Class I") and opens the wheels.
struct CalculatorSentence: View {
    var choice: CalculatorChoice
    var isOpen: Bool
    var open: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: open) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("I calculate as")
                        .textRole(.caption)
                        .textCase(.uppercase)
                        .tracking(0.8)
                        .foregroundStyle(Palette.secondaryText.color)
                    Text(sentence)
                        .textRole(.section)
                        .foregroundStyle(Palette.text.color)
                        .fixedSize(horizontal: false, vertical: true)
                        .id(choice.key)
                        .transition(
                            reduceMotion
                                ? .opacity
                                : .asymmetric(
                                    insertion: .opacity.combined(with: .offset(y: 6)).combined(
                                        with: .scale(scale: 0.96)),
                                    removal: .opacity))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.up")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(Palette.onAccent.color)
                    .rotationEffect(.degrees(isOpen ? 180 : 0))
                    .frame(width: 34, height: 34)
                    .background(Palette.accent.color, in: .circle)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(minHeight: 64)
            .background(
                LinearGradient(
                    colors: [Palette.raised.color, Palette.card.color], startPoint: .topLeading,
                    endPoint: .bottomTrailing),
                in: .rect(cornerRadius: 20, style: .continuous)
            )
            .overlay { if !reduceMotion { Sheen() } }
            .clipShape(.rect(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Palette.text.color.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.35), radius: 14, y: 8)
        }
        .buttonStyle(PressScaleStyle())
        .animation(.spring(duration: 0.45, bounce: 0.35), value: isOpen)
        .animation(.spring(duration: 0.38), value: choice.key)
        .accessibilityLabel(Text("I calculate as \(choice.parts.joined(separator: ", "))"))
        .accessibilityHint(Text("Changes what is calculated"))
        .accessibilityIdentifier("calculatorPicker")
    }

    /// The parts with lime dots between them.
    private var sentence: AttributedString {
        var result = AttributedString()
        for (index, part) in choice.parts.enumerated() {
            if index > 0 {
                var dot = AttributedString(" · ")
                dot.foregroundColor = Palette.accentText.color
                result += dot
            }
            result += AttributedString(part)
        }
        return result
    }
}

/// A soft lime light that sweeps across the card now and then.
private struct Sheen: View {
    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            LinearGradient(
                colors: [.clear, Palette.accent.color.opacity(0.12), .clear], startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: width * 0.5, height: height * 3)
            .rotationEffect(.degrees(20))
            .position(x: width / 2, y: height / 2)
            .keyframeAnimator(initialValue: -1.0, repeating: true) { content, phase in
                content.offset(x: phase * width * 1.2)
            } keyframes: { _ in
                LinearKeyframe(-1.0, duration: 3.2)
                CubicKeyframe(1.2, duration: 1.3)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Shrinks a little while pressed.
struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.25), value: configuration.isPressed)
    }
}

/// The sheet with three wheels: kind, direction, and class or input.
struct CalculatorPickerSheet: View {
    var choice: CalculatorChoice
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let settings = choice.settings
        let kind = choice.kind
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Calculation").textRole(.section).accessibilityAddTraits(.isHeader)
                Spacer()
                Button("Done") { dismiss() }
                    .textRole(.bodyStrong)
                    .padding(.horizontal, 18)
                    .frame(minHeight: 44)
                    .foregroundStyle(Palette.onAccent.color)
                    .background(Palette.accent.color, in: .capsule)
                    .buttonStyle(PressScaleStyle())
            }
            Text(choice.parts.joined(separator: " · "))
                .textRole(.bodyStrong)
                .foregroundStyle(Palette.accentText.color)
                .contentTransition(.opacity)
                .animation(.easeOut(duration: 0.25), value: choice.key)
                .accessibilityHidden(true)

            GeometryReader { proxy in
                let unit = (proxy.size.width - 8) / 3.25
                VStack(spacing: 6) {
                    HStack(spacing: 4) {
                        header("Kind").frame(width: unit * 1.15)
                        header(kind == .mini ? "n/a" : "Direction").frame(width: unit * 1.3)
                        header(kind == .selfEmployed ? "Input" : kind == .main ? "Class" : "n/a")
                            .frame(width: unit * 0.8)
                    }
                    ZStack {
                        WheelBand()
                        HStack(spacing: 4) {
                            Wheel(
                                String(localized: "Kind"),
                                options: CalculatorKind.allCases.map { WheelOption($0, $0.title) },
                                selection: kindBinding
                            )
                            .frame(width: unit * 1.15)
                            .accessibilityIdentifier("wheel.kind")
                            directionWheel.frame(width: unit * 1.3)
                            lastWheel(settings).frame(width: unit * 0.8)
                        }
                    }
                }
            }
            .frame(height: Wheel<Int>.height + 22)

            Text(choice.explanation)
                .textRole(.caption)
                .foregroundStyle(Palette.secondaryText.color)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 56, alignment: .topLeading)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Palette.background.color, in: .rect(cornerRadius: 16, style: .continuous))
                .animation(.easeOut(duration: 0.25), value: choice.key)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.top, 24)
        .presentationDetents([.height(450)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(32)
        .presentationBackground(Palette.card.color)
    }

    private func header(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .textRole(.caption)
            .textCase(.uppercase)
            .tracking(0.8)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(Palette.secondaryText.color)
    }

    private var kindBinding: Binding<CalculatorKind> {
        let choice = choice
        return Binding(get: { choice.kind }, set: { value in withAnimation(.snappy) { choice.kind = value } })
    }

    private var directionWheel: some View {
        let selfEmployed = choice.kind == .selfEmployed
        return Wheel(
            String(localized: "Direction"),
            options: [
                WheelOption(
                    false,
                    selfEmployed ? String(localized: "Profit→take-out") : String(localized: "Gross→net")),
                WheelOption(
                    true,
                    selfEmployed ? String(localized: "Desired take-out") : String(localized: "Desired net")),
            ],
            selection: choice.$desired.animation(.snappy),
            isEnabled: choice.kind != .mini
        )
        .id(selfEmployed)
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }

    @ViewBuilder
    private func lastWheel(_ settings: AppSettings) -> some View {
        @Bindable var settings = settings
        switch choice.kind {
        case .selfEmployed:
            Wheel(
                String(localized: "Input"),
                options: [
                    WheelOption(false, String(localized: "Profit")),
                    WheelOption(true, String(localized: "Day rate")),
                ],
                selection: $settings.selfEmployedInput.usesDayRate.animation(.snappy)
            )
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
        case .main, .secondary, .mini:
            Wheel(
                String(localized: "Tax class"),
                options: (1...6).map { WheelOption($0, CalculatorChoice.roman[$0 - 1]) },
                selection: choice.kind == .main
                    ? $settings.payInput.taxClass.animation(.snappy)
                    : .constant(choice.kind == .secondary ? 6 : settings.payInput.taxClass),
                isEnabled: choice.kind == .main
            )
            .id(choice.kind == .main)
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
        }
    }
}
