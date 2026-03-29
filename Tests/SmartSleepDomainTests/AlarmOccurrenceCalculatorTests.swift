import Foundation
import XCTest
@testable import SmartSleepDomain

final class AlarmOccurrenceCalculatorTests: XCTestCase {
    func testOneShotRollsToNextDayWhenTimePassed() throws {
        var calendar = Calendar(identifier: .gregorian)
        let tz = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        calendar.timeZone = tz

        let calculator = AlarmOccurrenceCalculator(calendar: calendar)
        let formatter = ISO8601DateFormatter()
        let now = try XCTUnwrap(formatter.date(from: "2026-03-29T23:10:00Z"))
        let alarm = Alarm(hour: 22, minute: 30, repeatWeekdays: [], label: "Test", soundID: "default")

        let trigger = try XCTUnwrap(calculator.nextTriggerDate(for: alarm, from: now))
        XCTAssertEqual(formatter.string(from: trigger), "2026-03-30T22:30:00Z")
    }

    func testRepeatingSameDayFutureTime() throws {
        var calendar = Calendar(identifier: .gregorian)
        let tz = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        calendar.timeZone = tz

        let calculator = AlarmOccurrenceCalculator(calendar: calendar)
        let formatter = ISO8601DateFormatter()
        let now = try XCTUnwrap(formatter.date(from: "2026-03-30T07:00:00Z"))
        let alarm = Alarm(hour: 8, minute: 0, repeatWeekdays: [.monday, .friday], label: "Work", soundID: "default")

        let trigger = try XCTUnwrap(calculator.nextTriggerDate(for: alarm, from: now))
        XCTAssertEqual(formatter.string(from: trigger), "2026-03-30T08:00:00Z")
    }
}
