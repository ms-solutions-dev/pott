import Foundation
import PottCore
import PottFeatures
import UserNotifications

/// Local notifications before notice deadlines. Nothing leaves the device.
@MainActor
enum Reminders {
    private static let prefix = "pott-notice-"

    /// Asks for permission when the module is switched on.
    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]))
            ?? false
    }

    /// Replaces all scheduled reminders with the current deadlines.
    static func update(for model: AppModel) {
        let center = UNUserNotificationCenter.current()
        let costs = model.settings.isOn(.contractReminders) ? model.costs : []
        let requests: [UNNotificationRequest] = costs.compactMap { cost in
            guard let date = cost.reminderDate(), let deadline = cost.noticeDeadline() else { return nil }
            let content = UNMutableNotificationContent()
            content.title = String(localized: "Cancel “\(cost.name)”?")
            content.body = String(
                localized: "The notice period ends on \(deadline.formatted(date: .long, time: .omitted)).")
            content.sound = .default
            var parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
            parts.hour = 9
            let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
            return UNNotificationRequest(
                identifier: prefix + cost.id.uuidString, content: content, trigger: trigger)
        }
        Task {
            let pending = await center.pendingNotificationRequests()
            center.removePendingNotificationRequests(
                withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(prefix) })
            for request in requests { try? await center.add(request) }
        }
    }
}
