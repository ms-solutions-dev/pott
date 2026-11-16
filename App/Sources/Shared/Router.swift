import PottDesign
import SwiftUI

/// The two tabs of the app.
enum AppTab: Hashable {
    case overview
    case calculator
}

/// Navigation state shared by all screens.
@MainActor
@Observable
final class Router {
    /// `-PottCalculator` starts on the calculator, for checks and screenshots.
    var tab: AppTab = ProcessInfo.processInfo.arguments.contains("-PottCalculator") ? .calculator : .overview
}

/// Short confirmations at the bottom of the screen, optionally with undo.
@MainActor
@Observable
final class ToastCenter {
    struct Item: Identifiable {
        let id = UUID()
        var message: String
        var undo: (@MainActor () -> Void)?
    }

    private(set) var current: Item?
    @ObservationIgnored private var dismissal: Task<Void, Never>?

    func show(_ message: String, undo: (@MainActor () -> Void)? = nil) {
        current = Item(message: message, undo: undo)
        dismissal?.cancel()
        dismissal = Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            self?.current = nil
        }
    }

    func performUndo() {
        current?.undo?()
        current = nil
    }
}
