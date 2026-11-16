import SwiftUI

/// The ring of the overview: a track and an animated arc.
public struct RingGauge<Label: View>: View {
    var progress: Double
    var tint: Color
    var lineWidth: CGFloat
    var glows: Bool
    @ViewBuilder var label: () -> Label
    @State private var shown = 0.0
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        progress: Double, tint: Color, lineWidth: CGFloat = 16, glows: Bool = true,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.progress = progress
        self.tint = tint
        self.lineWidth = lineWidth
        self.glows = glows
        self.label = label
    }

    public var body: some View {
        ZStack {
            if glows && scheme == .dark {
                Circle()
                    .fill(tint.opacity(0.35))
                    .padding(lineWidth * 2.5)
                    .blur(radius: 24)
                    .accessibilityHidden(true)
            }
            Circle()
                .stroke(Palette.track.color, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0, min(1, shown)))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            label()
                .padding(lineWidth * 1.5)
        }
        .onAppear { animate(to: progress) }
        .onChange(of: progress) { _, value in animate(to: value) }
    }

    private func animate(to value: Double) {
        if reduceMotion {
            shown = value
        } else {
            withAnimation(.spring(duration: 1.2, bounce: 0.15)) { shown = value }
        }
    }
}

/// A rounded surface for grouped content.
public struct CardModifier: ViewModifier {
    var padding: CGFloat

    public func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Palette.card.color, in: .rect(cornerRadius: 20, style: .continuous))
    }
}

extension View {
    /// Places the content on a card.
    public func card(padding: CGFloat = 16) -> some View {
        modifier(CardModifier(padding: padding))
    }
}

/// A selectable pill, at least 44 pt high.
public struct Chip: View {
    var title: String
    var isSelected: Bool
    var dot: Color?
    var action: () -> Void

    public init(_ title: String, isSelected: Bool, dot: Color? = nil, action: @escaping () -> Void) {
        self.title = title
        self.isSelected = isSelected
        self.dot = dot
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let dot {
                    Circle().fill(dot).frame(width: 10, height: 10)
                }
                Text(title).textRole(.caption)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .foregroundStyle(isSelected ? Palette.onSelected.color : Palette.text.color)
            .background(isSelected ? Palette.selected.color : .clear, in: .capsule)
            .overlay(Capsule().strokeBorder(isSelected ? .clear : Palette.control.color, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// A primary action in the lime accent.
public struct AccentButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .textRole(.bodyStrong)
            .frame(maxWidth: .infinity, minHeight: 52)
            .foregroundStyle(Palette.onAccent.color)
            .background(Palette.accent.color, in: .rect(cornerRadius: 16, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.25), value: configuration.isPressed)
    }
}

/// A short confirmation at the bottom, optionally with an undo action.
public struct Toast: View {
    var message: String
    var undoTitle: String?
    var undo: (() -> Void)?

    public init(_ message: String, undoTitle: String? = nil, undo: (() -> Void)? = nil) {
        self.message = message
        self.undoTitle = undoTitle
        self.undo = undo
    }

    public var body: some View {
        HStack(spacing: 10) {
            Text(message).textRole(.bodyStrong).frame(maxWidth: .infinity, alignment: .leading)
            if let undo, let undoTitle {
                Button(undoTitle, action: undo)
                    .textRole(.bodyStrong)
                    .frame(minHeight: 44)
                    .foregroundStyle(Palette.accentText.color)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .foregroundStyle(Palette.text.color)
        .background(Palette.raised.color, in: .rect(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.3), radius: 16, y: 8)
        .accessibilityElement(children: .combine)
        // Always dark, so it stands out on both backgrounds and the lime stays readable.
        .environment(\.colorScheme, .dark)
    }
}

/// What a section shows when it has no entries yet.
public struct EmptyHint: View {
    var title: String
    var message: String
    var action: (() -> Void)?

    public init(title: String, message: String, action: (() -> Void)? = nil) {
        self.title = title
        self.message = message
        self.action = action
    }

    public var body: some View {
        Button {
            action?()
        } label: {
            VStack(spacing: 4) {
                Text(title).textRole(.bodyStrong)
                Text(message).textRole(.caption).foregroundStyle(Palette.secondaryText.color)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .padding(.horizontal, 16)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Palette.control.color, style: StrokeStyle(lineWidth: 1.5, dash: [6, 5])))
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }
}
