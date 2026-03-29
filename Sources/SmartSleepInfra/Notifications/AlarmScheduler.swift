import Foundation
import SmartSleepDomain

#if canImport(UserNotifications)
import UserNotifications
#endif

public protocol AlarmScheduler: Sendable {
    func schedule(alarm: Alarm, triggerDate: Date) async throws
    func cancel(alarmID: UUID) async
}

public actor LocalNotificationAlarmScheduler: AlarmScheduler {
    public init() {}

    public func schedule(alarm: Alarm, triggerDate: Date) async throws {
        #if canImport(UserNotifications)
        let content = UNMutableNotificationContent()
        content.title = alarm.label.isEmpty ? "SmartSleep Alarm" : alarm.label
        content.body = "请起床，系统将持续监测你的清醒状态"
        content.sound = .default

        let triggerDateComps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDateComps, repeats: false)
        let request = UNNotificationRequest(identifier: alarm.id.uuidString, content: content, trigger: trigger)

        try await UNUserNotificationCenter.current().add(request)
        #endif
    }

    public func cancel(alarmID: UUID) async {
        #if canImport(UserNotifications)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [alarmID.uuidString])
        #endif
    }
}
