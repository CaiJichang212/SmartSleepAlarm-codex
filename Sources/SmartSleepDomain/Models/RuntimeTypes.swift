import Foundation

public struct SmartRuntimeConfig: Codable, Equatable, Sendable {
    public var awakeConfirmSeconds: TimeInterval
    public var postSilenceMonitorMinutes: Int
    public var prewarmLeadMinutes: Int

    public init(
        awakeConfirmSeconds: TimeInterval = 3,
        postSilenceMonitorMinutes: Int = 5,
        prewarmLeadMinutes: Int = 30
    ) {
        self.awakeConfirmSeconds = awakeConfirmSeconds
        self.postSilenceMonitorMinutes = postSilenceMonitorMinutes
        self.prewarmLeadMinutes = prewarmLeadMinutes
    }
}

public enum RuntimeState: String, Codable, Equatable, Sendable {
    case idle
    case prewarming
    case ringing
    case awakeCandidate
    case silenced
    case monitoring
    case reringing
    case dismissed
    case degraded
}

public enum DegradeReason: String, Codable, Equatable, Sendable {
    case healthPermissionMissing
    case watchNotWorn
    case sensorTimeout
    case connectivityFailure
    case runtimeSessionFailure
    case lowBattery
    case unknown
}

public struct SleepSignal: Equatable, Sendable {
    public var timestamp: Date
    public var heartRateBPM: Double?
    public var accelerationMagnitude: Double?

    public init(timestamp: Date = Date(), heartRateBPM: Double?, accelerationMagnitude: Double?) {
        self.timestamp = timestamp
        self.heartRateBPM = heartRateBPM
        self.accelerationMagnitude = accelerationMagnitude
    }
}

public enum SleepInference: Equatable, Sendable {
    case awake(confidence: Double)
    case asleep(confidence: Double)
    case uncertain
}
