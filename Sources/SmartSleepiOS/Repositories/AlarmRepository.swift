import Foundation
import SmartSleepDomain

public protocol AlarmRepository {
    func fetchAlarms() throws -> [Alarm]
    func upsert(_ alarm: Alarm) throws
    func delete(id: UUID) throws
}

public final class FileAlarmRepository: AlarmRepository {
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(baseDirectory: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory) {
        let directory = baseDirectory.appendingPathComponent("SmartSleepAlarm", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        self.fileURL = directory.appendingPathComponent("alarms.json")
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    public func fetchAlarms() throws -> [Alarm] {
        let records = try loadRecords()
        return records.map(Self.toDomain)
            .sorted { ($0.hour, $0.minute) < ($1.hour, $1.minute) }
    }

    public func upsert(_ alarm: Alarm) throws {
        var records = try loadRecords()
        let record = Self.fromDomain(alarm)
        if let idx = records.firstIndex(where: { $0.id == alarm.id }) {
            records[idx] = record
        } else {
            records.append(record)
        }
        try saveRecords(records)
    }

    public func delete(id: UUID) throws {
        var records = try loadRecords()
        records.removeAll { $0.id == id }
        try saveRecords(records)
    }

    private func loadRecords() throws -> [AlarmRecord] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        let data = try Data(contentsOf: fileURL)
        return try decoder.decode([AlarmRecord].self, from: data)
    }

    private func saveRecords(_ records: [AlarmRecord]) throws {
        let data = try encoder.encode(records)
        try data.write(to: fileURL, options: .atomic)
    }

    private static func toDomain(_ record: AlarmRecord) -> Alarm {
        let weekdays = Set(
            record.repeatWeekdaysRaw
                .split(separator: ",")
                .compactMap { Int($0) }
                .compactMap { Weekday(rawValue: $0) }
        )
        return Alarm(
            id: record.id,
            hour: record.hour,
            minute: record.minute,
            repeatWeekdays: weekdays,
            label: record.label,
            soundID: record.soundID,
            enabled: record.enabled,
            smartModeEnabled: record.smartModeEnabled,
            snoozeMinutes: record.snoozeMinutes
        )
    }

    private static func fromDomain(_ alarm: Alarm) -> AlarmRecord {
        AlarmRecord(
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
}
