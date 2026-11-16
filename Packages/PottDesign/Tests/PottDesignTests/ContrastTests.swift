import Testing

@testable import PottDesign

/// The review of the mockup found unreadable combinations in the light theme. These tests keep
/// every text and control pair at WCAG AA in both appearances.
@Suite("Contrast")
struct ContrastTests {
    typealias Pair = (name: String, foreground: Tone, background: Tone, minimum: Double)

    let pairs: [Pair] = [
        ("text on background", Palette.text, Palette.background, 4.5),
        ("text on card", Palette.text, Palette.card, 4.5),
        ("secondary text on background", Palette.secondaryText, Palette.background, 4.5),
        ("secondary text on card", Palette.secondaryText, Palette.card, 4.5),
        ("accent text on background", Palette.accentText, Palette.background, 4.5),
        ("accent text on card", Palette.accentText, Palette.card, 4.5),
        ("text on accent", Palette.onAccent, Palette.accent, 4.5),
        ("negative on card", Palette.negative, Palette.card, 4.5),
        ("shared on card", Palette.shared, Palette.card, 4.5),
        ("text on shared", Palette.onShared, Palette.shared, 4.5),
        ("text on selected", Palette.onSelected, Palette.selected, 4.5),
        ("ring on background", Palette.ring, Palette.background, 3),
        ("controls on card", Palette.control, Palette.card, 3),
    ]

    @Test("Text and controls meet WCAG AA in light mode")
    func light() {
        for pair in pairs {
            let ratio = pair.foreground.light.contrast(with: pair.background.light)
            #expect(ratio >= pair.minimum, "\(pair.name): \(ratio)")
        }
    }

    @Test("Text and controls meet WCAG AA in dark mode")
    func dark() {
        for pair in pairs {
            let ratio = pair.foreground.dark.contrast(with: pair.background.dark)
            #expect(ratio >= pair.minimum, "\(pair.name): \(ratio)")
        }
    }

    @Test("Category colors stay readable as dots and headings")
    func categories() {
        for (index, tone) in Palette.categories.enumerated() {
            #expect(tone.light.contrast(with: Palette.card.light) >= 3, "light category \(index)")
            #expect(tone.dark.contrast(with: Palette.card.dark) >= 3, "dark category \(index)")
        }
        #expect(Palette.category(9) == Palette.category(1))
        #expect(Palette.category(-1) == Palette.category(7))
    }
}
