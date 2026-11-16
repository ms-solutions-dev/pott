import Foundation
import Testing

@testable import PottCore

@Suite("Reminders and months")
struct ReminderTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }()

    func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 9))!
    }

    @Test("Notice deadline and reminder two weeks before")
    func reminder() {
        let phone = FixedCost(
            name: "Phone", amount: Money(units: 20), category: .subscriptions, contractEnd: date(2027, 3, 31),
            noticePeriodDays: 30)
        #expect(phone.noticeDeadline(calendar: calendar) == date(2027, 3, 1))
        #expect(phone.reminderDate(now: date(2026, 11, 1), calendar: calendar) == date(2027, 2, 15))
        #expect(phone.reminderDate(now: date(2027, 2, 20), calendar: calendar) == date(2027, 3, 1))
        #expect(phone.reminderDate(now: date(2027, 3, 2), calendar: calendar) == nil)
    }

    @Test("Costs without a contract end have no reminder")
    func noContract() {
        #expect(FixedCost(name: "Rent", amount: Money(units: 800), category: .housing).reminderDate() == nil)
    }

    @Test("Month keys")
    func monthKey() {
        #expect(MonthSummary.key(for: date(2026, 10, 31), calendar: calendar) == "2026-10")
        #expect(MonthSummary.key(for: date(2027, 1, 1), calendar: calendar) == "2027-01")
    }
}
