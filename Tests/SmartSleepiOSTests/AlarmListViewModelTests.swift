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
    private(set) var sentMessages: [WatchMessageEnvelope] = []

    func activate() async {}
    func setEventHandler(_ handler: (@Sendable (WatchSessionEvent) -> Void)?) async {}
    func send(_ message: WatchMessageEnvelope) async throws {
        sentMessages.append(message)
    }

    func sentMessageTypes() -> [String] {
        sentMessages.map {
            switch $0 {
            case .alarmPlanSync: return "plan"
            case .prewarm: return "prewarm"
            case .ring: return "ring"
            case .awake: return "awake"
            case .snooze: return "snooze"
            case .degrade: return "degrade"
            }
        }
    }
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
    func testSaveAndDeleteAlarmCRUDFlow() async throws {
        let repository = MockAlarmRepository()
        let vm = AlarmListViewModel(
            repository: repository,
            settingsRepository: MockSnoozeSettingsRepository(),
            scheduler: MockAlarmScheduler(),
            watchSession: MockWatchSession(),
            permissionService: MockPermissionService(status: .init(notificationGranted: true, healthKitGranted: true)),
            logger: NoopLogger()
        )

        let alarm = Alarm(
            hour: 6,
            minute: 45,
            repeatWeekdays: [.monday, .friday],
            label: "起床",
            soundID: "radar",
            enabled: true,
            smartModeEnabled: true,
            snoozeMinutes: 8
        )

        vm.save(alarm: alarm)
        try await Task.sleep(for: .milliseconds(60))
        XCTAssertEqual(repository.alarms.count, 1)

        vm.delete(alarmID: alarm.id)
        try await Task.sleep(for: .milliseconds(60))
        XCTAssertEqual(repository.alarms.count, 0)
    }

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

    func testPermissionGuideShowsReadyWhenGranted() async {
        let vm = AlarmListViewModel(
            repository: MockAlarmRepository(),
            settingsRepository: MockSnoozeSettingsRepository(),
            scheduler: MockAlarmScheduler(),
            watchSession: MockWatchSession(),
            permissionService: MockPermissionService(status: .init(notificationGranted: true, healthKitGranted: true)),
            logger: NoopLogger()
        )

        vm.requestPermissions()
        try? await Task.sleep(for: .milliseconds(80))
        XCTAssertEqual(vm.permissionGuideText, "权限已就绪")
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

    func testRuntimeDispatchSendsPrewarmAndRingAtExpectedWindows() async {
        let repository = MockAlarmRepository()
        let watchSession = MockWatchSession()
        let cal = Calendar.current
        let now = cal.date(
            from: DateComponents(
                year: 2026,
                month: 3,
                day: 30,
                hour: 7,
                minute: 0,
                second: 0
            )
        )!
        let trigger = cal.date(byAdding: .minute, value: 20, to: now)!
        let hour = cal.component(.hour, from: trigger)
        let minute = cal.component(.minute, from: trigger)
        repository.alarms = [
            Alarm(
                hour: hour,
                minute: minute,
                repeatWeekdays: [],
                label: "test",
                soundID: "default",
                enabled: true,
                smartModeEnabled: true,
                snoozeMinutes: 5
            )
        ]

        let vm = AlarmListViewModel(
            repository: repository,
            settingsRepository: MockSnoozeSettingsRepository(),
            scheduler: MockAlarmScheduler(),
            watchSession: watchSession,
            permissionService: MockPermissionService(status: .init(notificationGranted: true, healthKitGranted: true)),
            logger: NoopLogger()
        )

        vm.reloadAlarms()
        await vm.processRuntimeDispatch(now: now)
        let messageTypesAfterPrewarm = await watchSession.sentMessageTypes()
        XCTAssertTrue(messageTypesAfterPrewarm.contains("prewarm"))

        await vm.processRuntimeDispatch(now: trigger.addingTimeInterval(2))
        let finalTypes = await watchSession.sentMessageTypes()
        XCTAssertTrue(finalTypes.contains("ring"))
    }

    func testRuntimeDispatchSendsOnlyPrewarmAtMinusThirtyMinutes() async {
        let repository = MockAlarmRepository()
        let watchSession = MockWatchSession()
        let cal = Calendar.current
        let now = cal.date(
            from: DateComponents(
                year: 2026,
                month: 4,
                day: 1,
                hour: 6,
                minute: 30,
                second: 0
            )
        )!
        let trigger = cal.date(byAdding: .minute, value: 30, to: now)!
        repository.alarms = [
            Alarm(
                hour: cal.component(.hour, from: trigger),
                minute: cal.component(.minute, from: trigger),
                repeatWeekdays: [],
                label: "prewarm-check",
                soundID: "default",
                enabled: true,
                smartModeEnabled: true,
                snoozeMinutes: 5
            )
        ]

        let vm = AlarmListViewModel(
            repository: repository,
            settingsRepository: MockSnoozeSettingsRepository(),
            scheduler: MockAlarmScheduler(),
            watchSession: watchSession,
            permissionService: MockPermissionService(status: .init(notificationGranted: true, healthKitGranted: true)),
            logger: NoopLogger()
        )

        vm.reloadAlarms()
        await vm.processRuntimeDispatch(now: now)
        let sentTypes = await watchSession.sentMessageTypes()
        XCTAssertTrue(sentTypes.contains("prewarm"))
        XCTAssertFalse(sentTypes.contains("ring"))
    }

    func testSaveAlarmPersistsSmartModeAndSnoozeSettings() async throws {
        let repository = MockAlarmRepository()
        let vm = AlarmListViewModel(
            repository: repository,
            settingsRepository: MockSnoozeSettingsRepository(),
            scheduler: MockAlarmScheduler(),
            watchSession: MockWatchSession(),
            permissionService: MockPermissionService(status: .init(notificationGranted: true, healthKitGranted: true)),
            logger: NoopLogger()
        )

        let alarm = Alarm(
            hour: 8,
            minute: 10,
            repeatWeekdays: [.wednesday],
            label: "会议",
            soundID: "beacon",
            enabled: true,
            smartModeEnabled: false,
            snoozeMinutes: 12
        )
        vm.save(alarm: alarm)
        try await Task.sleep(for: .milliseconds(80))

        XCTAssertEqual(repository.alarms.first?.smartModeEnabled, false)
        XCTAssertEqual(repository.alarms.first?.snoozeMinutes, 12)
    }
}
