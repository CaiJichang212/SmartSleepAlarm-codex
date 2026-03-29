import Foundation
import SwiftData
import SmartSleepDomain
import SmartSleepiOS

@Model
final class AlarmEntity {
    var id: UUID
    var hour: Int
    var minute: Int
    var repeatWeekdaysRaw: String
    var label: String
    var soundID: String
    var enabled: Bool
    var smartModeEnabled: Bool
    var snoozeMinutes: Int

    init(
        id: UUID,
        hour: Int,
        minute: Int,
        repeatWeekdaysRaw: String,
        label: String,
        soundID: String,
        enabled: Bool,
        smartModeEnabled: Bool,
        snoozeMinutes: Int
    ) {
        self.id = id
        self.hour = hour
        self.minute = minute
        self.repeatWeekdaysRaw = repeatWeekdaysRaw
        self.label = label
        self.soundID = soundID
        self.enabled = enabled
        self.smartModeEnabled = smartModeEnabled
        self.snoozeMinutes = snoozeMinutes
    }
}

final class SwiftDataAlarmRepositoryAdapter: AlarmRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchAlarms() throws -> [Alarm] {
        let descriptor = FetchDescriptor<AlarmEntity>()
        return try context.fetch(descriptor)
            .map(Self.toDomain)
            .sorted { ($0.hour, $0.minute) < ($1.hour, $1.minute) }
    }

    func upsert(_ alarm: Alarm) throws {
        let descriptor = FetchDescriptor<AlarmEntity>(predicate: #Predicate { $0.id == alarm.id })
        if let existing = try context.fetch(descriptor).first {
            patch(existing, with: alarm)
        } else {
            context.insert(Self.fromDomain(alarm))
        }
        try context.save()
    }

    func delete(id: UUID) throws {
        let descriptor = FetchDescriptor<AlarmEntity>(predicate: #Predicate { $0.id == id })
        if let existing = try context.fetch(descriptor).first {
            context.delete(existing)
            try context.save()
        }
    }

    private static func toDomain(_ entity: AlarmEntity) -> Alarm {
        let weekdays = Set(entity.repeatWeekdaysRaw.split(separator: ",").compactMap { Int($0) }.compactMap { Weekday(rawValue: $0) })
        return Alarm(
            id: entity.id,
            hour: entity.hour,
            minute: entity.minute,
            repeatWeekdays: weekdays,
            label: entity.label,
            soundID: entity.soundID,
            enabled: entity.enabled,
            smartModeEnabled: entity.smartModeEnabled,
            snoozeMinutes: entity.snoozeMinutes
        )
    }

    private static func fromDomain(_ alarm: Alarm) -> AlarmEntity {
        AlarmEntity(
            id: alarm.id,
            hour: alarm.hour,
            minute: alarm.minute,
            repeatWeekdaysRaw: alarm.repeatWeekdays.sorted().map { String($0.rawValue) }.joined(separator: ","),
            label: alarm.label,
            soundID: alarm.soundID,
            enabled: alarm.enabled,
            smartModeEnabled: alarm.smartModeEnabled,
            snoozeMinutes: alarm.snoozeMinutes
        )
    }

    private func patch(_ entity: AlarmEntity, with alarm: Alarm) {
        entity.hour = alarm.hour
        entity.minute = alarm.minute
        entity.repeatWeekdaysRaw = alarm.repeatWeekdays.sorted().map { String($0.rawValue) }.joined(separator: ",")
        entity.label = alarm.label
        entity.soundID = alarm.soundID
        entity.enabled = alarm.enabled
        entity.smartModeEnabled = alarm.smartModeEnabled
        entity.snoozeMinutes = alarm.snoozeMinutes
    }
}
