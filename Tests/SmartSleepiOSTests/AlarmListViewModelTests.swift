import XCTest
import SmartSleepDomain
import SmartSleepInfra
import SmartSleepShared
@testable import SmartSleepiOS

private final class MockAlarmRepository: AlarmRepository {
    var alarms: [Alarm] = []
    func fetchAlarms() throws -> [Alarm] { alarms }
    func upsert(_ alarm: Alarm) throws {
        if let idx = alarms.firstIndex(where: { $0.id == alarm.id }) {
            alarms[idx] = alarm
        } else {
            alarms.append(alarm)
        }
    }
    func delete(id: UUID) throws { alarms.removeAll { $0.id == id } }
}

private final class MockSnoozeSettingsRepository: SnoozeSettingsRepository {
    var value: Int = 5
    func getDefaultSnoozeMinutes() -> Int { value }
    func setDefaultSnoozeMinutes(_ value: Int) { self.value = value }
}

private actor MockAlarmScheduler: AlarmScheduler {
    func schedule(alarm: Alarm, triggerDate: Date) async throws {}
    func cancel(alarmID: UUID) async {}
}

private actor MockWatchSession: WatchSessionCoordinator {
    func activate() async {}
    func setEventHandler(_ handler: (@Sendable (WatchSessionEvent) -> Void)?) async {}
    func send(_ message: WatchMessageEnvelope) async throws {}
}

private actor MockPermissionService: PermissionService {
    let status: PermissionStatus
    init(status: PermissionStatus) { self.status = status }
    func currentStatus() async -> PermissionStatus { status }
    func requestAll() async -> PermissionStatus { status }
}

private actor NoopLogger: AlarmEventLogger {
    func log(_ entry: AlarmRuntimeLogEntry) async {}
}

@MainActor
final class AlarmListViewModelTests: XCTestCase {
    func testRequestPermissionsShowsGuideWhenDenied() async {
        let vm = AlarmListViewModel(
            repository: MockAlarmRepository(),
            settingsRepository: MockSnoozeSettingsRepository(),
            scheduler: MockAlarmScheduler(),
            watchSession: MockWatchSession(),
            permissionService: MockPermissionService(status: .init(notificationGranted: false, healthKitGranted: false)),
            logger: NoopLogger()
        )

        vm.requestPermissions()
        try? await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(vm.permissionGuideText, "请在系统设置中同时开启通知与健康权限。")
        XCTAssertNotNil(vm.lastError)
    }

    func testUpdateDefaultSnoozeMinutesPersistsValue() {
        let settings = MockSnoozeSettingsRepository()
        let vm = AlarmListViewModel(
            repository: MockAlarmRepository(),
            settingsRepository: settings,
            scheduler: MockAlarmScheduler(),
            watchSession: MockWatchSession(),
            permissionService: MockPermissionService(status: .init(notificationGranted: true, healthKitGranted: true)),
            logger: NoopLogger()
        )

        vm.updateDefaultSnoozeMinutes(18)
        XCTAssertEqual(settings.value, 18)
    }
}
