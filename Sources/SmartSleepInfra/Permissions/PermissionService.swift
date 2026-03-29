import Foundation
import SmartSleepDomain

#if canImport(UserNotifications)
@preconcurrency import UserNotifications
#endif

#if canImport(HealthKit)
import HealthKit
#endif

public struct PermissionStatus: Sendable, Equatable {
    public var notificationGranted: Bool
    public var healthKitGranted: Bool

    public init(notificationGranted: Bool, healthKitGranted: Bool) {
        self.notificationGranted = notificationGranted
        self.healthKitGranted = healthKitGranted
    }

    public var isReadyForSmartMode: Bool {
        notificationGranted && healthKitGranted
    }
}

public protocol PermissionService: Sendable {
    func currentStatus() async -> PermissionStatus
    func requestAll() async -> PermissionStatus
}

public actor LivePermissionService: PermissionService {
    public init() {}

    public func currentStatus() async -> PermissionStatus {
        async let notification = notificationStatus()
        async let health = healthKitStatus()
        return await PermissionStatus(notificationGranted: notification, healthKitGranted: health)
    }

    public func requestAll() async -> PermissionStatus {
        async let notification = requestNotificationPermission()
        async let health = requestHealthKitPermission()
        return await PermissionStatus(notificationGranted: notification, healthKitGranted: health)
    }

    private func notificationStatus() async -> Bool {
        #if canImport(UserNotifications)
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        return settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
        #else
        return false
        #endif
    }

    private func requestNotificationPermission() async -> Bool {
        #if canImport(UserNotifications)
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
        #else
        return false
        #endif
    }

    private func healthKitStatus() async -> Bool {
        #if canImport(HealthKit)
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return false }
        return HKHealthStore().authorizationStatus(for: heartRateType) == .sharingAuthorized
        #else
        return false
        #endif
    }

    private func requestHealthKitPermission() async -> Bool {
        #if canImport(HealthKit)
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return false }
        let readTypes: Set = [heartRateType]

        do {
            try await HKHealthStore().requestAuthorization(toShare: [], read: readTypes)
            return true
        } catch {
            return false
        }
        #else
        return false
        #endif
    }
}
