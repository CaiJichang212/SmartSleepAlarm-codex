import Foundation
import SmartSleepDomain

#if canImport(HealthKit)
import HealthKit
#endif

public protocol SleepSignalProvider: Sendable {
    func latestSignal() async -> SleepSignal?
}

public actor HealthKitSleepSignalProvider: SleepSignalProvider {
    public init() {}

    public func latestSignal() async -> SleepSignal? {
        #if canImport(HealthKit)
        return SleepSignal(timestamp: Date(), heartRateBPM: nil, accelerationMagnitude: nil)
        #else
        return nil
        #endif
    }
}
