import CoreText
import SwiftUI

/// Font roles: Barlow Condensed for figures and headings, Barlow for text.
///
/// Static cuts instead of `.weight()`, because SwiftUI silently falls back to the nearest cut for
/// custom fonts. Every role scales with Dynamic Type; the smallest text is 14 pt at default size.
public enum TextRole: Sendable {
    /// Screen titles.
    case title
    /// Section headings, uppercase.
    case section
    /// Amounts in lists.
    case amount
    /// The large figure in the ring.
    case hero
    /// Large input figures in the calculator.
    case figure
    case body
    case bodyStrong
    /// Secondary lines; never below 14 pt.
    case caption

    public var font: Font {
        switch self {
        case .title: .custom("BarlowCondensed-Bold", size: 30, relativeTo: .largeTitle)
        case .section: .custom("BarlowCondensed-Bold", size: 20, relativeTo: .headline)
        case .amount: .custom("BarlowCondensed-Bold", size: 21, relativeTo: .body)
        case .hero: .custom("BarlowCondensed-ExtraBold", size: 50, relativeTo: .largeTitle)
        case .figure: .custom("BarlowCondensed-ExtraBold", size: 52, relativeTo: .largeTitle)
        case .body: .custom("Barlow-Regular", size: 17, relativeTo: .body)
        case .bodyStrong: .custom("Barlow-SemiBold", size: 17, relativeTo: .body)
        case .caption: .custom("Barlow-Medium", size: 14, relativeTo: .subheadline)
        }
    }
}

public enum PottFonts {
    /// Registers the bundled fonts once at launch.
    @MainActor public static func register() {
        guard !registered else { return }
        registered = true
        guard let folder = Bundle.module.url(forResource: "Fonts", withExtension: nil),
            let files = try? FileManager.default.contentsOfDirectory(
                at: folder, includingPropertiesForKeys: nil)
        else { return }
        for url in files where url.pathExtension == "ttf" {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    @MainActor private static var registered = false
}

extension View {
    /// Applies a text role; figures are tabular so nothing jumps.
    public func textRole(_ role: TextRole) -> some View {
        font(role.font).monospacedDigit()
    }
}
