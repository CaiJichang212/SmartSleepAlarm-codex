import Foundation
import SmartSleepDomain

#if canImport(HealthKit)
import HealthKit
#endif

#if canImport(CoreMotion) && (os(iOS) || os(watchOS))
import CoreMotion
#endif

public protocol SleepSignalProvider: Sendable {
    func latestReadout() async -> SleepSignalReadout
}

public struct SleepSignalReadout: Sendable {
    public var signal: SleepSignal?
    public var degradeReason: DegradeReason?
    public var detail: String?

    public init(signal: SleepSignal?, degradeReason: DegradeReason?, detail: String? = nil) {
        self.signal = signal
        self.degradeReason = degradeReason
        self.detail = detail
    }
}

public actor HealthKitSleepSignalProvider: SleepSignalProvider {
    #if canImport(CoreMotion) && (os(iOS) || os(watchOS))
    private let motionManager = CMMotionManager()
    private let motionStore = MotionSampleStore()
    #endif

    public init() {}

    public func latestReadout() async -> SleepSignalReadout {
        #if canImport(HealthKit)
        #if canImport(CoreMotion) && (os(iOS) || os(watchOS))
        startMotionSamplingIfNeeded()
        #endif

        let heartRateResult = await readLatestHeartRate()
        let motionMagnitude = currentMotionMagnitude(maxStaleness: 6)

        switch heartRateResult {
        case .unauthorized:
            return .init(signal: nil, degradeReason: .healthPermissionMissing, detail: "heart_rate_permission_missing")
        case .failed(let message):
            return .init(signal: nil, degradeReason: .sensorTimeout, detail: "heart_rate_query_failed:\(message)")
        case .value(let bpm):
            if bpm == nil && motionMagnitude == nil {
                return .init(signal: nil, degradeReason: .sensorTimeout, detail: "heart_and_motion_missing")
            }

            if bpm == nil, let motionMagnitude, motionMagnitude < 0.02 {
                return .init(signal: nil, degradeReason: .watchNotWorn, detail: "low_motion_and_no_heart_rate")
            }

            return .init(
                signal: SleepSignal(timestamp: Date(), heartRateBPM: bpm, accelerationMagnitude: motionMagnitude),
                degradeReason: nil
            )
        }
        #else
        return .init(signal: nil, degradeReason: .healthPermissionMissing, detail: "healthkit_unavailable")
        #endif
    }

    #if canImport(CoreMotion) && (os(iOS) || os(watchOS))
    private func startMotionSamplingIfNeeded() {
        guard motionManager.isAccelerometerAvailable else { return }
        guard !motionManager.isAccelerometerActive else { return }

        motionManager.accelerometerUpdateInterval = 0.2
        motionManager.startAccelerometerUpdates(to: .main) { [motionStore] data, _ in
            guard let data else { return }
            let magnitude = sqrt(
                data.acceleration.x * data.acceleration.x +
                data.acceleration.y * data.acceleration.y +
                data.acceleration.z * data.acceleration.z
            )
            motionStore.store(magnitude: magnitude, timestamp: Date())
        }
    }

    private func currentMotionMagnitude(maxStaleness seconds: TimeInterval) -> Double? {
        motionStore.latestMagnitude(maxStaleness: seconds)
    }
    #else
    private func currentMotionMagnitude(maxStaleness seconds: TimeInterval) -> Double? {
        _ = seconds
        return nil
    }
    #endif

    private enum HeartRateResult {
        case unauthorized
        case value(Double?)
        case failed(String)
    }

    private func readLatestHeartRate() async -> HeartRateResult {
        #if canImport(HealthKit)
        guard HKHealthStore.isHealthDataAvailable(),
              let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            return .unauthorized
        }

        let healthStore = HKHealthStore()
        let authorizationStatus = healthStore.authorizationStatus(for: heartRateType)
        guard authorizationStatus == .sharingAuthorized else {
            return .unauthorized
        }

        let startDate = Date().addingTimeInterval(-10 * 60)
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        do {
            let bpm = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Double?, Error>) in
                let query = HKSampleQuery(sampleType: heartRateType, predicate: predicate, limit: 1, sortDescriptors: [sort]) { _, samples, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }
                    guard let sample = samples?.first as? HKQuantitySample else {
                        continuation.resume(returning: nil)
                        return
                    }
                    let unit = HKUnit.count().unitDivided(by: HKUnit.minute())
                    continuation.resume(returning: sample.quantity.doubleValue(for: unit))
                }
                healthStore.execute(query)
            }
            return .value(bpm)
        } catch {
            return .failed(error.localizedDescription)
        }
        #else
        return .unauthorized
        #endif
    }
}

#if canImport(CoreMotion) && (os(iOS) || os(watchOS))
private final class MotionSampleStore: @unchecked Sendable {
    private let lock = NSLock()
    private var latestMagnitude: Double?
    private var latestTimestamp: Date?

    func store(magnitude: Double, timestamp: Date) {
        lock.lock()
        latestMagnitude = magnitude
        latestTimestamp = timestamp
        lock.unlock()
    }

    func latestMagnitude(maxStaleness: TimeInterval) -> Double? {
        lock.lock()
        defer { lock.unlock() }
        guard let latestTimestamp,
              Date().timeIntervalSince(latestTimestamp) <= maxStaleness else {
            return nil
        }
        return latestMagnitude
    }
}
#endif
