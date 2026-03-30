import Foundation
import Combine
import SmartSleepDomain
import SmartSleepShared
import SmartSleepInfra
#if canImport(UIKit)
import UIKit
#endif

@MainActor
public final class AlarmListViewModel: ObservableObject {
    @Published public private(set) var alarms: [Alarm] = []
    @Published public private(set) var permissionStatus: PermissionStatus = .init(notificationGranted: false, healthKitGranted: false)
    @Published public private(set) var defaultSnoozeMinutes: Int = 5
    @Published public private(set) var watchSessionStatus: String = "未连接"
    @Published public private(set) var lastError: String?

    private let repository: AlarmRepository
    private let settingsRepository: SnoozeSettingsRepository
    private let scheduler: AlarmScheduler
    private let watchSession: WatchSessionCoordinator
    private let permissionService: PermissionService
    private let logger: AlarmEventLogger
    private let calculator = AlarmOccurrenceCalculator()
    private let runtimeConfig = SmartRuntimeConfig()
    private var runtimeDispatchTask: Task<Void, Never>?
    private var lastPrewarmTriggerEpoch: [UUID: TimeInterval] = [:]
    private var lastRingTriggerEpoch: [UUID: TimeInterval] = [:]

    public init(
        repository: AlarmRepository,
        settingsRepository: SnoozeSettingsRepository,
        scheduler: AlarmScheduler,
        watchSession: WatchSessionCoordinator,
        permissionService: PermissionService,
        logger: AlarmEventLogger = JSONLineAlarmEventLogger()
    ) {
        self.repository = repository
        self.settingsRepository = settingsRepository
        self.scheduler = scheduler
        self.watchSession = watchSession
        self.permissionService = permissionService
        self.logger = logger
    }

    public func onAppear() {
        runtimeDispatchTask?.cancel()
        Task {
            await watchSession.setEventHandler { [weak self] event in
                Task { @MainActor in
                    self?.handleWatchSessionEvent(event)
                }
            }
            await logger.log(.init(alarmID: nil, state: .idle, source: "iOS", event: "app_on_appear"))
            await watchSession.activate()
            await refreshPermissions()
            defaultSnoozeMinutes = settingsRepository.getDefaultSnoozeMinutes()
            reloadAlarms()
            await syncPlanToWatch()
            await processRuntimeDispatch(now: Date())
            startRuntimeDispatchLoop()
        }
    }

    public func requestPermissions() {
        Task {
            permissionStatus = await permissionService.requestAll()
            if !permissionStatus.isReadyForSmartMode {
                lastError = permissionGuideText
            }
            await logger.log(
                .init(
                    alarmID: nil,
                    state: .idle,
                    source: "iOS",
                    event: "permission_requested",
                    detail: "notification=\(permissionStatus.notificationGranted),health=\(permissionStatus.healthKitGranted)"
                )
            )
        }
    }

    public func updateDefaultSnoozeMinutes(_ value: Int) {
        let sanitized = max(1, min(30, value))
        defaultSnoozeMinutes = sanitized
        settingsRepository.setDefaultSnoozeMinutes(sanitized)
        Task {
            await logger.log(
                .init(
                    alarmID: nil,
                    state: .idle,
                    source: "iOS",
                    event: "default_snooze_updated",
                    detail: "minutes=\(sanitized)"
                )
            )
        }
    }

    public var permissionGuideText: String {
        if permissionStatus.notificationGranted && permissionStatus.healthKitGranted {
            return "权限已就绪"
        }
        if !permissionStatus.notificationGranted && !permissionStatus.healthKitGranted {
            return "请在系统设置中同时开启通知与健康权限。"
        }
        if !permissionStatus.notificationGranted {
            return "通知权限未开启：将无法可靠触发闹铃提醒。"
        }
        return "健康权限未开启：智能静音与防再睡能力不可用。"
    }

    public func openSystemSettings() {
        #if canImport(UIKit)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
        #endif
    }

    public func reloadAlarms() {
        do {
            alarms = try repository.fetchAlarms()
            pruneDispatchHistory()
            Task {
                await logger.log(
                    .init(
                        alarmID: nil,
                        state: .idle,
                        source: "iOS",
                        event: "alarms_reloaded",
                        detail: "count=\(alarms.count)"
                    )
                )
            }
        } catch {
            lastError = "加载闹铃失败: \(error.localizedDescription)"
        }
    }

    public func save(alarm: Alarm) {
        do {
            try repository.upsert(alarm)
            Task {
                await logger.log(
                    .init(
                        alarmID: alarm.id,
                        state: .idle,
                        source: "iOS",
                        event: "alarm_saved",
                        detail: "time=\(alarm.hour):\(alarm.minute),enabled=\(alarm.enabled)"
                    )
                )
            }
            reloadAlarms()
            Task {
                await scheduleIfNeeded(alarm)
                await syncPlanToWatch()
                await processRuntimeDispatch(now: Date())
            }
        } catch {
            lastError = "保存闹铃失败: \(error.localizedDescription)"
        }
    }

    public func delete(alarmID: UUID) {
        do {
            try repository.delete(id: alarmID)
            Task {
                await logger.log(
                    .init(alarmID: alarmID, state: .idle, source: "iOS", event: "alarm_deleted")
                )
            }
            reloadAlarms()
            Task {
                await scheduler.cancel(alarmID: alarmID)
                await syncPlanToWatch()
            }
        } catch {
            lastError = "删除闹铃失败: \(error.localizedDescription)"
        }
    }

    deinit {
        runtimeDispatchTask?.cancel()
    }

    private func refreshPermissions() async {
        permissionStatus = await permissionService.currentStatus()
    }

    private func scheduleIfNeeded(_ alarm: Alarm) async {
        guard let triggerDate = calculator.nextTriggerDate(for: alarm) else { return }

        do {
            try await scheduler.schedule(alarm: alarm, triggerDate: triggerDate)
            await logger.log(
                .init(
                    alarmID: alarm.id,
                    state: .prewarming,
                    source: "iOS",
                    event: "notification_scheduled",
                    detail: "trigger=\(triggerDate.ISO8601Format())"
                )
            )
        } catch {
            lastError = "调度失败: \(error.localizedDescription)"
        }
    }

    func processRuntimeDispatch(now: Date = Date()) async {
        let dispatchReferenceTime = now.addingTimeInterval(-30)
        for alarm in alarms where alarm.enabled && alarm.smartModeEnabled {
            guard let triggerDate = calculator.nextTriggerDate(for: alarm, from: dispatchReferenceTime) else { continue }
            let triggerEpoch = triggerDate.timeIntervalSince1970
            let prewarmDate = calculator.prewarmDate(for: triggerDate, config: runtimeConfig)

            if now >= prewarmDate && now < triggerDate,
               shouldDispatchPrewarm(alarmID: alarm.id, triggerEpoch: triggerEpoch) {
                do {
                    let prewarm = PrewarmCommand(
                        alarmID: alarm.id,
                        triggerDate: triggerDate,
                        prewarmDate: prewarmDate
                    )
                    try await watchSession.send(.prewarm(prewarm))
                    lastPrewarmTriggerEpoch[alarm.id] = triggerEpoch
                    await logger.log(
                        .init(
                            alarmID: alarm.id,
                            state: .prewarming,
                            source: "iOS",
                            event: "prewarm_sent",
                            detail: "trigger=\(triggerDate.ISO8601Format())"
                        )
                    )
                } catch {
                    lastError = "预热下发失败: \(error.localizedDescription)"
                }
            }

            if now >= triggerDate,
               now.timeIntervalSince(triggerDate) <= 30,
               shouldDispatchRing(alarmID: alarm.id, triggerEpoch: triggerEpoch) {
                do {
                    try await watchSession.send(.ring(.init(alarmID: alarm.id, state: .ringing, at: now)))
                    lastRingTriggerEpoch[alarm.id] = triggerEpoch
                    await logger.log(
                        .init(
                            alarmID: alarm.id,
                            state: .ringing,
                            source: "iOS",
                            event: "ring_sent",
                            detail: "trigger=\(triggerDate.ISO8601Format())"
                        )
                    )
                } catch {
                    lastError = "响铃下发失败: \(error.localizedDescription)"
                }
            }
        }
    }

    private func syncPlanToWatch() async {
        do {
            try await watchSession.send(.alarmPlanSync(.init(alarms: alarms)))
            await logger.log(
                .init(
                    alarmID: nil,
                    state: .idle,
                    source: "iOS",
                    event: "plan_synced",
                    detail: "count=\(alarms.count)"
                )
            )
        } catch {
            lastError = "手表同步失败: \(error.localizedDescription)"
        }
    }

    private func handleWatchSessionEvent(_ event: WatchSessionEvent) {
        switch event {
        case .activated:
            watchSessionStatus = "会话已激活"
        case .reachabilityChanged(let isReachable):
            watchSessionStatus = isReachable ? "手表在线" : "手表离线（已启用排队重试）"
            if isReachable {
                Task { await syncPlanToWatch() }
            }
        case .received:
            watchSessionStatus = "已收到手表状态回传"
        case .transportQueued:
            watchSessionStatus = "消息已排队，等待手表恢复连接"
            Task { await retrySyncPlan() }
        case .transportError(let message):
            watchSessionStatus = "通信异常：\(message)"
        }
    }

    private func retrySyncPlan() async {
        for attempt in 1...3 {
            try? await Task.sleep(for: .seconds(Double(attempt)))
            do {
                try await watchSession.send(.alarmPlanSync(.init(alarms: alarms)))
                await logger.log(
                    .init(
                        alarmID: nil,
                        state: .idle,
                        source: "iOS",
                        event: "plan_retry_succeeded",
                        detail: "attempt=\(attempt)"
                    )
                )
                return
            } catch {
                continue
            }
        }
        await logger.log(
            .init(
                alarmID: nil,
                state: .idle,
                source: "iOS",
                event: "plan_retry_failed"
            )
        )
    }

    private func startRuntimeDispatchLoop() {
        runtimeDispatchTask?.cancel()
        runtimeDispatchTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.processRuntimeDispatch(now: Date())
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func shouldDispatchPrewarm(alarmID: UUID, triggerEpoch: TimeInterval) -> Bool {
        lastPrewarmTriggerEpoch[alarmID] != triggerEpoch
    }

    private func shouldDispatchRing(alarmID: UUID, triggerEpoch: TimeInterval) -> Bool {
        lastRingTriggerEpoch[alarmID] != triggerEpoch
    }

    private func pruneDispatchHistory() {
        let existing = Set(alarms.map(\.id))
        lastPrewarmTriggerEpoch = lastPrewarmTriggerEpoch.filter { existing.contains($0.key) }
        lastRingTriggerEpoch = lastRingTriggerEpoch.filter { existing.contains($0.key) }
    }
}
