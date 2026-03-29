import Foundation

public struct AlarmOccurrenceCalculator {
    private let calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    public func nextTriggerDate(for alarm: Alarm, from now: Date = Date()) -> Date? {
        guard alarm.enabled else { return nil }

        if alarm.repeatWeekdays.isEmpty {
            return nextOneShotDate(for: alarm, from: now)
        }
        return nextRepeatingDate(for: alarm, from: now)
    }

    public func prewarmDate(for triggerDate: Date, config: SmartRuntimeConfig) -> Date {
        triggerDate.addingTimeInterval(TimeInterval(-config.prewarmLeadMinutes * 60))
    }

    private func nextOneShotDate(for alarm: Alarm, from now: Date) -> Date? {
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = alarm.hour
        components.minute = alarm.minute
        components.second = 0

        guard let todayAtAlarm = calendar.date(from: components) else { return nil }
        if todayAtAlarm > now {
            return todayAtAlarm
        }
        return calendar.date(byAdding: .day, value: 1, to: todayAtAlarm)
    }

    private func nextRepeatingDate(for alarm: Alarm, from now: Date) -> Date? {
        let nowWeekday = calendar.component(.weekday, from: now)
        let nowMinutes = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)
        let alarmMinutes = alarm.hour * 60 + alarm.minute

        for offset in 0..<14 {
            let targetWeekday = ((nowWeekday - 1 + offset) % 7) + 1
            guard let weekday = Weekday(rawValue: targetWeekday), alarm.repeatWeekdays.contains(weekday) else {
                continue
            }

            if offset == 0 && alarmMinutes <= nowMinutes {
                continue
            }

            guard let candidateDay = calendar.date(byAdding: .day, value: offset, to: now) else { continue }
            var components = calendar.dateComponents([.year, .month, .day], from: candidateDay)
            components.hour = alarm.hour
            components.minute = alarm.minute
            components.second = 0
            if let candidateDate = calendar.date(from: components) {
                return candidateDate
            }
        }
        return nil
    }
}
