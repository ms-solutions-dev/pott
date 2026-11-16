import SwiftUI

/// One option of a `Wheel`.
public struct WheelOption<Value: Hashable & Sendable>: Hashable, Sendable {
    public var value: Value
    public var title: String

    public init(_ value: Value, _ title: String) {
        self.value = value
        self.title = title
    }
}

/// A picker wheel like the date picker's: rows turn away in 3D above and below the middle, the
/// middle one is set in the display font. Scrolling snaps to a row; tapping a row turns it to the
/// middle. The highlight band behind the middle row comes from `WheelBand`, so several wheels share
/// one band.
public struct Wheel<Value: Hashable & Sendable>: View {
    var options: [WheelOption<Value>]
    @Binding var selection: Value
    var isEnabled: Bool
    var label: String

    /// Scroll offset in points; row `i` sits in the middle at `i × rowHeight`.
    @State private var offset: CGFloat = 0
    @State private var position = ScrollPosition()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public static var rowHeight: CGFloat { 38 }
    public static var height: CGFloat { 190 }

    public init(
        _ label: String, options: [WheelOption<Value>], selection: Binding<Value>, isEnabled: Bool = true
    ) {
        self.label = label
        self.options = options
        self._selection = selection
        self.isEnabled = isEnabled
    }

    /// The row nearest to the middle right now.
    private var centredIndex: Int {
        min(max(Int((offset / Self.rowHeight).rounded()), 0), max(options.count - 1, 0))
    }

    private func scroll(to value: Value, animated: Bool) {
        guard let index = options.firstIndex(where: { $0.value == value }) else { return }
        let y = CGFloat(index) * Self.rowHeight
        if animated && !reduceMotion {
            withAnimation(.spring(duration: 0.4, bounce: 0.2)) { position.scrollTo(y: y) }
        } else {
            position.scrollTo(y: y)
        }
    }

    public var body: some View {
        let row = Self.rowHeight
        let padding = (Self.height - row) / 2
        let centred = centredIndex
        ScrollView(.vertical) {
            VStack(spacing: 0) {
                Color.clear.frame(height: padding)
                ForEach(Array(options.enumerated()), id: \.element.value) { index, option in
                    // How many rows this one is away from the middle, for the 3D turn and fading.
                    let distance = (CGFloat(index) * row - offset) / row
                    Button {
                        selection = option.value
                        scroll(to: option.value, animated: true)
                    } label: {
                        Text(option.title)
                            .font(index == centred ? TextRole.amount.font : TextRole.caption.font)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .foregroundStyle(Palette.text.color)
                            .frame(maxWidth: .infinity, minHeight: row, maxHeight: row)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .rotation3DEffect(.degrees(-distance * 22), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
                    .opacity(max(0.25, 1 - abs(distance) * 0.28))
                    .accessibilityAddTraits(option.value == selection ? .isSelected : [])
                }
                Color.clear.frame(height: padding)
            }
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(WheelSnap(row: row))
        .scrollPosition($position)
        .onScrollGeometryChange(for: CGFloat.self) {
            $0.contentOffset.y
        } action: { _, y in
            offset = y
        }
        .onScrollPhaseChange { old, phase in
            // Only a wheel the user turned picks a value; programmatic scrolls (on appear, after a
            // tap) must not overwrite the selection with whatever row happened to be in the middle.
            guard phase == .idle, old == .interacting || old == .decelerating,
                options.indices.contains(centredIndex)
            else { return }
            let value = options[centredIndex].value
            if value != selection { selection = value }
        }
        .frame(height: Self.height)
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0), .init(color: .black, location: 0.3),
                    .init(color: .black, location: 0.7), .init(color: .clear, location: 1),
                ], startPoint: .top, endPoint: .bottom)
        )
        .opacity(isEnabled ? 1 : 0.28)
        .allowsHitTesting(isEnabled)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.35), value: isEnabled)
        .sensoryFeedback(.selection, trigger: centred)
        .onAppear { scroll(to: selection, animated: false) }
        .onChange(of: selection) { _, value in
            if options.indices.contains(centredIndex), options[centredIndex].value != value {
                scroll(to: value, animated: true)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(label))
    }
}

/// Lets a wheel come to rest with a row exactly in the middle.
struct WheelSnap: ScrollTargetBehavior {
    var row: CGFloat

    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        target.rect.origin.y = (target.rect.origin.y / row).rounded() * row
    }
}
/// The rounded band behind the middle row of one or more wheels.
public struct WheelBand: View {
    public init() {}

    public var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Palette.raised.color)
            .frame(height: Wheel<Int>.rowHeight)
            .accessibilityHidden(true)
    }
}

extension View {
    /// Swells briefly whenever `trigger` changes, to show that a figure was worked out anew.
    public func bump<T: Equatable & Sendable>(on trigger: T) -> some View {
        modifier(Bump(trigger: trigger))
    }
}

private struct Bump<T: Equatable & Sendable>: ViewModifier {
    var trigger: T
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content.keyframeAnimator(initialValue: 1.0, trigger: trigger) { view, scale in
                view.scaleEffect(scale, anchor: .leading)
            } keyframes: { _ in
                SpringKeyframe(1.06, duration: 0.14)
                SpringKeyframe(1.0, duration: 0.35, spring: .bouncy)
            }
        }
    }
}
