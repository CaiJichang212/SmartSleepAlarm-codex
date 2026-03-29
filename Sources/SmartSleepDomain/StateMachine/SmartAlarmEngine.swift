import Foundation

public struct SmartAlarmEvent: Sendable, Equatable {
    public enum Kind: Sendable, Equatable {
        case ringStarted
        case awakeSignal
        case asleepSignal
        case uncertainSignal
        case awakeConfirmTimeout
        case postSilenceMonitorTimeout
        case snoozeTriggered(minutes: Int)
        case snoozeTimeout
        case manualDismiss
        case degrade(reason: DegradeReason)
    }

    public var kind: Kind
    public var at: Date

    public init(kind: Kind, at: Date = Date()) {
        self.kind = kind
        self.at = at
    }
}

public struct SmartAlarmTransition: Sendable, Equatable {
    public var from: RuntimeState
    public var to: RuntimeState
    public var shouldRing: Bool
    public var note: String

    public init(from: RuntimeState, to: RuntimeState, shouldRing: Bool, note: String) {
        self.from = from
        self.to = to
        self.shouldRing = shouldRing
        self.note = note
    }
}

public struct SmartAlarmEngine: Sendable {
    public private(set) var state: RuntimeState
    public let config: SmartRuntimeConfig

    public init(state: RuntimeState = .idle, config: SmartRuntimeConfig = .init()) {
        self.state = state
        self.config = config
    }

    @discardableResult
    public mutating func handle(_ event: SmartAlarmEvent) -> SmartAlarmTransition {
        let current = state

        let transition: SmartAlarmTransition
        switch (state, event.kind) {
        case (_, .degrade):
            state = .degraded
            transition = .init(from: current, to: state, shouldRing: true, note: "Degraded fallback: keep ringing")

        case (_, .manualDismiss):
            state = .dismissed
            transition = .init(from: current, to: state, shouldRing: false, note: "Manually dismissed")

        case (.idle, .ringStarted), (.prewarming, .ringStarted):
            state = .ringing
            transition = .init(from: current, to: state, shouldRing: true, note: "Alarm ringing")

        case (.ringing, .awakeSignal):
            state = .awakeCandidate
            transition = .init(from: current, to: state, shouldRing: true, note: "Awake signal detected, start 3s window")

        case (.awakeCandidate, .awakeConfirmTimeout):
            state = .silenced
            transition = .init(from: current, to: state, shouldRing: false, note: "Awake confirmed, stop ringing")

        case (.awakeCandidate, .asleepSignal), (.awakeCandidate, .uncertainSignal):
            state = .ringing
            transition = .init(from: current, to: state, shouldRing: true, note: "Awake confirmation failed")

        case (.silenced, .awakeSignal):
            state = .monitoring
            transition = .init(from: current, to: state, shouldRing: false, note: "Start anti-fallback monitoring")

        case (.monitoring, .asleepSignal):
            state = .reringing
            transition = .init(from: current, to: state, shouldRing: true, note: "Asleep again, re-ring")

        case (.monitoring, .postSilenceMonitorTimeout):
            state = .dismissed
            transition = .init(from: current, to: state, shouldRing: false, note: "Stayed awake for monitor window")

        case (.reringing, .awakeSignal):
            state = .awakeCandidate
            transition = .init(from: current, to: state, shouldRing: true, note: "Re-ring awake candidate")

        case (.ringing, .snoozeTriggered), (.reringing, .snoozeTriggered):
            state = .silenced
            transition = .init(from: current, to: state, shouldRing: false, note: "Gesture snooze triggered")

        case (.silenced, .snoozeTimeout), (.dismissed, .snoozeTimeout):
            state = .reringing
            transition = .init(from: current, to: state, shouldRing: true, note: "Snooze timeout reached")

        case (.idle, _):
            transition = .init(from: current, to: state, shouldRing: false, note: "No-op in idle")

        default:
            transition = .init(from: current, to: state, shouldRing: state == .ringing || state == .reringing || state == .degraded, note: "No-op")
        }

        return transition
    }
}
