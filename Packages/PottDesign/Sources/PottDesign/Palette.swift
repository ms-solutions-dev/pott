import SwiftUI

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

/// An sRGB color given as 0xRRGGBB.
public struct RGB: Hashable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double

    public init(_ hex: UInt32) {
        red = Double((hex >> 16) & 0xFF) / 255
        green = Double((hex >> 8) & 0xFF) / 255
        blue = Double(hex & 0xFF) / 255
    }

    /// Relative luminance after WCAG 2.
    public var luminance: Double {
        func channel(_ value: Double) -> Double {
            value <= 0.040_45 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(red) + 0.7152 * channel(green) + 0.0722 * channel(blue)
    }

    /// WCAG contrast ratio between two colors, 1…21.
    public func contrast(with other: RGB) -> Double {
        let (a, b) = (luminance, other.luminance)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }
}

/// A color for the light and the dark appearance.
public struct Tone: Hashable, Sendable {
    public var light: RGB
    public var dark: RGB

    public init(light: UInt32, dark: UInt32) {
        self.light = RGB(light)
        self.dark = RGB(dark)
    }

    public var color: Color {
        #if canImport(UIKit)
            Color(
                uiColor: UIColor { traits in
                    let rgb = traits.userInterfaceStyle == .dark ? dark : light
                    return UIColor(red: rgb.red, green: rgb.green, blue: rgb.blue, alpha: 1)
                })
        #else
            Color(
                nsColor: NSColor(name: nil) { appearance in
                    let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                    let rgb = isDark ? dark : light
                    return NSColor(srgbRed: rgb.red, green: rgb.green, blue: rgb.blue, alpha: 1)
                })
        #endif
    }
}

/// Every color of Pott. Views use only these roles; `check.sh` reports color values elsewhere.
///
/// Lime is always a fill. As text on light backgrounds it is unreadable, so text in the accent
/// color uses `accentText` and strokes use `ring`.
public enum Palette {
    public static let background = Tone(light: 0xF3F4EE, dark: 0x111111)
    public static let card = Tone(light: 0xFFFFFF, dark: 0x1E1E1E)
    public static let raised = Tone(light: 0xE9EBE2, dark: 0x2C2C2C)
    public static let track = Tone(light: 0xE3E6DA, dark: 0x2C2C2C)
    public static let separator = Tone(light: 0xDCDFD3, dark: 0x3A3A3A)
    /// Borders of inputs and unselected chips (≥ 3:1 against cards).
    public static let control = Tone(light: 0x8A8F80, dark: 0x7A7A7A)
    public static let text = Tone(light: 0x141612, dark: 0xFFFFFF)
    public static let secondaryText = Tone(light: 0x5A5E54, dark: 0xBDBDBD)
    /// Lime fill for the ring, buttons and the tab bar.
    public static let accent = Tone(light: 0xC6FF4D, dark: 0xC6FF4D)
    public static let onAccent = Tone(light: 0x141612, dark: 0x111111)
    public static let accentText = Tone(light: 0x3F6B00, dark: 0xC6FF4D)
    public static let ring = Tone(light: 0x4F7A00, dark: 0xC6FF4D)
    /// Shared things: the household pot and shared savings goals.
    public static let shared = Tone(light: 0x2A6FD6, dark: 0x6FB6FF)
    public static let onShared = Tone(light: 0xFFFFFF, dark: 0x0A1420)
    public static let negative = Tone(light: 0xB83A28, dark: 0xFF7A6B)
    public static let selected = Tone(light: 0x141612, dark: 0xFFFFFF)
    public static let onSelected = Tone(light: 0xFFFFFF, dark: 0x111111)
    public static let switchOn = Tone(light: 0x248A3D, dark: 0x34C759)

    /// The colors a category can take, by index. Indices are stored, so the palette may change
    /// between appearances without losing the choice.
    public static let categories: [Tone] = [
        Tone(light: 0x1B8A5E, dark: 0x7BE495),  // green
        Tone(light: 0x9A6A00, dark: 0xFFE14D),  // yellow
        Tone(light: 0x2F6FDB, dark: 0x6FB6FF),  // blue
        Tone(light: 0x7A55D6, dark: 0xB79CFF),  // violet
        Tone(light: 0xC24A30, dark: 0xFF8A65),  // orange
        Tone(light: 0xB53A84, dark: 0xFF8FD0),  // pink
        Tone(light: 0x0F7C8C, dark: 0x5CE1E6),  // teal
        Tone(light: 0x4F7A00, dark: 0xC6FF4D),  // lime
    ]

    /// The color of a category index; out-of-range indices wrap around.
    public static func category(_ index: Int) -> Tone {
        categories[((index % categories.count) + categories.count) % categories.count]
    }
}
