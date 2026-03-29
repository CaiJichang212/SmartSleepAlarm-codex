import Foundation
import SmartSleepDomain

public struct AlarmPlanSync: Codable, Equatable, Sendable {
    public var alarms: [Alarm]
    public var syncedAt: Date

    public init(alarms: [Alarm], syncedAt: Date = Date()) {
        self.alarms = alarms
        self.syncedAt = syncedAt
    }
}

public struct PrewarmCommand: Codable, Equatable, Sendable {
    public var alarmID: UUID
    public var triggerDate: Date
    public var prewarmDate: Date

    public init(alarmID: UUID, triggerDate: Date, prewarmDate: Date) {
        self.alarmID = alarmID
        self.triggerDate = triggerDate
        self.prewarmDate = prewarmDate
    }
}

public struct RingEvent: Codable, Equatable, Sendable {
    public var alarmID: UUID
    public var state: RuntimeState
    public var at: Date

    public init(alarmID: UUID, state: RuntimeState, at: Date = Date()) {
        self.alarmID = alarmID
        self.state = state
        self.at = at
    }
}

public struct AwakeDecision: Codable, Equatable, Sendable {
    public var alarmID: UUID
    public var isAwake: Bool
    public var confidence: Double
    public var at: Date

    public init(alarmID: UUID, isAwake: Bool, confidence: Double, at: Date = Date()) {
        self.alarmID = alarmID
        self.isAwake = isAwake
        self.confidence = confidence
        self.at = at
    }
}

public struct SnoozeGestureEvent: Codable, Equatable, Sendable {
    public var alarmID: UUID
    public var snoozeMinutes: Int
    public var at: Date

    public init(alarmID: UUID, snoozeMinutes: Int, at: Date = Date()) {
        self.alarmID = alarmID
        self.snoozeMinutes = snoozeMinutes
        self.at = at
    }
}

public struct DegradeEvent: Codable, Equatable, Sendable {
    public var alarmID: UUID?
    public var reason: DegradeReason
    public var detail: String
    public var at: Date

    public init(alarmID: UUID?, reason: DegradeReason, detail: String, at: Date = Date()) {
        self.alarmID = alarmID
        self.reason = reason
        self.detail = detail
        self.at = at
    }
}

public enum WatchMessageEnvelope: Codable, Equatable, Sendable {
    case alarmPlanSync(AlarmPlanSync)
    case prewarm(PrewarmCommand)
    case ring(RingEvent)
    case awake(AwakeDecision)
    case snooze(SnoozeGestureEvent)
    case degrade(DegradeEvent)

    private enum CodingKeys: String, CodingKey {
        case type
        case payload
    }

    private enum MessageType: String, Codable {
        case alarmPlanSync
        case prewarm
        case ring
        case awake
        case snooze
        case degrade
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(MessageType.self, forKey: .type)

        switch type {
        case .alarmPlanSync:
            self = .alarmPlanSync(try container.decode(AlarmPlanSync.self, forKey: .payload))
        case .prewarm:
            self = .prewarm(try container.decode(PrewarmCommand.self, forKey: .payload))
        case .ring:
            self = .ring(try container.decode(RingEvent.self, forKey: .payload))
        case .awake:
            self = .awake(try container.decode(AwakeDecision.self, forKey: .payload))
        case .snooze:
            self = .snooze(try container.decode(SnoozeGestureEvent.self, forKey: .payload))
        case .degrade:
            self = .degrade(try container.decode(DegradeEvent.self, forKey: .payload))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .alarmPlanSync(let payload):
            try container.encode(MessageType.alarmPlanSync, forKey: .type)
            try container.encode(payload, forKey: .payload)
        case .prewarm(let payload):
            try container.encode(MessageType.prewarm, forKey: .type)
            try container.encode(payload, forKey: .payload)
        case .ring(let payload):
            try container.encode(MessageType.ring, forKey: .type)
            try container.encode(payload, forKey: .payload)
        case .awake(let payload):
            try container.encode(MessageType.awake, forKey: .type)
            try container.encode(payload, forKey: .payload)
        case .snooze(let payload):
            try container.encode(MessageType.snooze, forKey: .type)
            try container.encode(payload, forKey: .payload)
        case .degrade(let payload):
            try container.encode(MessageType.degrade, forKey: .type)
            try container.encode(payload, forKey: .payload)
        }
    }
}
