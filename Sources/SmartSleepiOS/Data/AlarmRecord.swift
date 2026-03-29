import Foundation

public struct AlarmRecord: Codable, Equatable, Sendable {
    public var id: UUID
    public var hour: Int
    public var minute: Int
    public var repeatWeekdaysRaw: String
    public var label: String
    public var soundID: String
    public var enabled: Bool
    public var smartModeEnabled: Bool
    public var snoozeMinutes: Int

    public init(
        id: UUID = UUID(),
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

public struct GlobalSettingsRecord: Codable, Equatable, Sendable {
    public var defaultSnoozeMinutes: Int

    public init(defaultSnoozeMinutes: Int = 5) {
        self.defaultSnoozeMinutes = defaultSnoozeMinutes
    }
}
