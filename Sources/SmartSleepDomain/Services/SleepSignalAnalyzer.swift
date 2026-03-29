import Foundation

public protocol SleepSignalAnalyzer: Sendable {
    func infer(from signal: SleepSignal) -> SleepInference
}

public struct HeuristicSleepSignalAnalyzer: SleepSignalAnalyzer {
    public var awakeMotionThreshold: Double
    public var asleepMotionThreshold: Double
    public var lowHeartRateThreshold: Double
    public var highHeartRateThreshold: Double

    public init(
        awakeMotionThreshold: Double = 1.2,
        asleepMotionThreshold: Double = 0.15,
        lowHeartRateThreshold: Double = 55,
        highHeartRateThreshold: Double = 70
    ) {
        self.awakeMotionThreshold = awakeMotionThreshold
        self.asleepMotionThreshold = asleepMotionThreshold
        self.lowHeartRateThreshold = lowHeartRateThreshold
        self.highHeartRateThreshold = highHeartRateThreshold
    }

    public func infer(from signal: SleepSignal) -> SleepInference {
        let motion = signal.accelerationMagnitude
        let heartRate = signal.heartRateBPM

        if let motion, motion >= awakeMotionThreshold {
            return .awake(confidence: 0.9)
        }
        if let hr = heartRate, hr >= highHeartRateThreshold {
            return .awake(confidence: 0.7)
        }
        if let motion, motion <= asleepMotionThreshold, let hr = heartRate, hr <= lowHeartRateThreshold {
            return .asleep(confidence: 0.85)
        }
        if motion == nil && heartRate == nil {
            return .uncertain
        }
        return .uncertain
    }
}
