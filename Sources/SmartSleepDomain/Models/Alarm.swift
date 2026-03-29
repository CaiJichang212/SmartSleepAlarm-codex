import Foundation

public enum Weekday: Int, Codable, CaseIterable, Comparable, Sendable {
    case sunday = 1
    case monday
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday

    public static func < (lhs: Weekday, rhs: Weekday) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public struct Alarm: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var hour: Int
    public var minute: Int
    public var repeatWeekdays: Set<Weekday>
    public var label: String
    public var soundID: String
    public var enabled: Bool
    public var smartModeEnabled: Bool
    public var snoozeMinutes: Int

    public init(
        id: UUID = UUID(),
        hour: Int,
        minute: Int,
        repeatWeekdays: Set<Weekday>,
        label: String,
        soundID: String,
        enabled: Bool = true,
        smartModeEnabled: Bool = true,
        snoozeMinutes: Int = 5
    ) {
        self.id = id
        self.hour = max(0, min(23, hour))
        self.minute = max(0, min(59, minute))
        self.repeatWeekdays = repeatWeekdays
        self.label = label
        self.soundID = soundID
        self.enabled = enabled
        self.smartModeEnabled = smartModeEnabled
        self.snoozeMinutes = max(1, min(30, snoozeMinutes))
    }

    public var isOneShot: Bool {
        repeatWeekdays.isEmpty
    }
}
