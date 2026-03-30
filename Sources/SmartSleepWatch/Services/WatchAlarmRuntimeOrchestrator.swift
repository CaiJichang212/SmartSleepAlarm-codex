import Foundation
import Combine
import SmartSleepDomain
import SmartSleepShared
import SmartSleepInfra

@MainActor
public final class WatchAlarmRuntimeOrchestrator: ObservableObject {
    @Published public private(set) var runtimeState: RuntimeState = .idle
    @Published public private(set) var statusNote: String = "待命"

    private var engine = SmartAlarmEngine()
    private let analyzer: any SleepSignalAnalyzer
    private let signalProvider: any SleepSignalProvider
    private let gestureDetector: any GestureSnoozeDetector
    private let watchSession: WatchSessionCoordinator
    private let logger: AlarmEventLogger
    private let runtimeSessionController: any RuntimeSessionControlling
    private let feedbackPlayer: any WatchAlarmFeedbackPlayer
    private let snoozePolicy = SnoozePolicy()

    private var awakeConfirmTask: Task<Void, Never>?
    private var monitorTask: Task<Void, Never>?
    private var snoozeTask: Task<Void, Never>?
    private var currentAlarmID: UUID?
    private var currentSnoozeMinutes: Int = 5
    private var alarmPlan: [UUID: Alarm] = [:]

    public init(
        analyzer: any SleepSignalAnalyzer = HeuristicSleepSignalAnalyzer(),
        signalProvider: any SleepSignalProvider = HealthKitSleepSignalProvider(),
        gestureDetector: any GestureSnoozeDetector = CoreMotionFlipDetector(),
        watchSession: WatchSessionCoordinator = LiveWatchSessionCoordinator(),
        logger: AlarmEventLogger = JSONLineAlarmEventLogger(),
        runtimeSessionController: any RuntimeSessionControlling = ExtendedRuntimeSessionController(),
        feedbackPlayer: any WatchAlarmFeedbackPlayer = LiveWatchAlarmFeedbackPlayer()
    ) {
        self.analyzer = analyzer
        self.signalProvider = signalProvider
        self.gestureDetector = gestureDetector
        self.watchSession = watchSession
        self.logger = logger
        self.runtimeSessionController = runtimeSessionController
        self.feedbackPlayer = feedbackPlayer

        self.gestureDetector.onFlipDetected = { [weak self] in
            Task { @MainActor in
                self?.triggerSnoozeFromGesture()
            }
        }
        self.runtimeSessionController.delegate = self
    }

    public func activate() {
        Task {
            await watchSession.setEventHandler { [weak self] event in
                Task { @MainActor in
                    self?.handleWatchSessionEvent(event)
                }
            }
            await watchSession.activate()
            await logger.log(.init(alarmID: currentAlarmID, state: runtimeState, source: "Watch", event: "watch_activated"))
        }
        gestureDetector.start()
    }

    public func handlePrewarm(_ command: PrewarmCommand, snoozeMinutes: Int) {
        currentAlarmID = command.alarmID
        currentSnoozeMinutes = snoozePolicy.sanitizedMinutes(snoozeMinutes)
        runtimeState = .prewarming
        statusNote = "已预热，等待响铃"
        runtimeSessionController.start()
        Task {
            await logger.log(
                .init(
                    alarmID: command.alarmID,
                    state: .prewarming,
                    source: "Watch",
                    event: "prewarm_received",
                    detail: "trigger=\(command.triggerDate.ISO8601Format())"
                )
            )
        }
    }

    public func startRinging() {
        runtimeSessionController.start()
        let transition = engine.handle(.init(kind: .ringStarted))
        apply(transition)
        pollSleepSignal()
    }

    public func pollSleepSignal() {
        Task {
            let readout = await signalProvider.latestReadout()
            if let reason = readout.degradeReason {
                let transition = engine.handle(.init(kind: .degrade(reason: reason)))
                apply(transition)
                await sendDegrade(reason: reason, detail: readout.detail ?? "sensor_degraded")
                return
            }

            guard let signal = readout.signal else {
                let transition = engine.handle(.init(kind: .degrade(reason: .sensorTimeout)))
                apply(transition)
                await sendDegrade(reason: .sensorTimeout, detail: "signal_nil_without_reason")
                return
            }

            switch analyzer.infer(from: signal) {
            case .awake(let confidence):
                _ = confidence
                if runtimeState == .ringing || runtimeState == .reringing {
                    let transition = engine.handle(.init(kind: .awakeSignal))
                    apply(transition)
                    startAwakeConfirmWindow()
                } else if runtimeState == .silenced {
                    let transition = engine.handle(.init(kind: .awakeSignal))
                    apply(transition)
                    startMonitorWindow()
                }
            case .asleep:
                let transition = engine.handle(.init(kind: .asleepSignal))
                apply(transition)
                if runtimeState == .reringing {
                    sendRingState()
                }
            case .uncertain:
                let transition = engine.handle(.init(kind: .uncertainSignal))
                apply(transition)
            }
        }
    }

    public func triggerSnoozeFromGesture() {
        guard runtimeState == .ringing || runtimeState == .reringing else { return }
        let transition = engine.handle(.init(kind: .snoozeTriggered(minutes: currentSnoozeMinutes)))
        apply(transition)
        statusNote = "已贪睡 \(currentSnoozeMinutes) 分钟，随后重响"
        sendSnoozeEvent()
        startSnoozeCountdown(minutes: currentSnoozeMinutes)
    }

    public func manualDismiss() {
        let transition = engine.handle(.init(kind: .manualDismiss))
        apply(transition)
        cancelAllTasks()
    }

    private func startAwakeConfirmWindow() {
        awakeConfirmTask?.cancel()
        awakeConfirmTask = Task {
            try? await Task.sleep(for: .seconds(engine.config.awakeConfirmSeconds))
            guard !Task.isCancelled else { return }
            let transition = engine.handle(.init(kind: .awakeConfirmTimeout))
            apply(transition)
            sendRingState()
            pollSleepSignal()
        }
    }

    private func startMonitorWindow() {
        monitorTask?.cancel()
        monitorTask = Task {
            let seconds = engine.config.postSilenceMonitorMinutes * 60
            let endDate = Date().addingTimeInterval(TimeInterval(seconds))
            while Date() < endDate {
                pollSleepSignal()
                try? await Task.sleep(for: .seconds(2))
            }
            guard !Task.isCancelled else { return }
            let transition = engine.handle(.init(kind: .postSilenceMonitorTimeout))
            apply(transition)
        }
    }

    private func startSnoozeCountdown(minutes: Int) {
        snoozeTask?.cancel()
        snoozeTask = Task {
            try? await Task.sleep(for: .seconds(Double(minutes * 60)))
            guard !Task.isCancelled else { return }
            let transition = engine.handle(.init(kind: .snoozeTimeout))
            apply(transition)
            sendRingState()
            pollSleepSignal()
        }
    }

    private func apply(_ transition: SmartAlarmTransition) {
        runtimeState = transition.to
        statusNote = transition.note
        feedbackPlayer.playTransition(from: transition.from, to: transition.to)
        Task {
            await logger.log(
                .init(
                    alarmID: currentAlarmID,
                    state: transition.to,
                    source: "Watch",
                    event: "state_transition",
                    detail: "\(transition.from.rawValue)->\(transition.to.rawValue);note=\(transition.note)"
                )
            )
        }
        if transition.shouldRing {
            sendRingState()
        }
    }

    private func sendRingState() {
        guard let alarmID = currentAlarmID else { return }
        Task {
            try? await watchSession.send(.ring(.init(alarmID: alarmID, state: runtimeState)))
            await logger.log(
                .init(
                    alarmID: alarmID,
                    state: runtimeState,
                    source: "Watch",
                    event: "ring_event_sent"
                )
            )
        }
    }

    private func sendSnoozeEvent() {
        guard let alarmID = currentAlarmID else { return }
        Task {
            try? await watchSession.send(.snooze(.init(alarmID: alarmID, snoozeMinutes: currentSnoozeMinutes)))
            await logger.log(
                .init(
                    alarmID: alarmID,
                    state: runtimeState,
                    source: "Watch",
                    event: "snooze_event_sent",
                    detail: "minutes=\(currentSnoozeMinutes)"
                )
            )
        }
    }

    private func sendDegrade(reason: DegradeReason, detail: String) async {
        try? await watchSession.send(.degrade(.init(alarmID: currentAlarmID, reason: reason, detail: detail)))
        await logger.log(
            .init(
                alarmID: currentAlarmID,
                state: .degraded,
                source: "Watch",
                event: "degrade_event_sent",
                detail: "\(reason.rawValue):\(detail)"
            )
        )
    }

    private func cancelAllTasks() {
        awakeConfirmTask?.cancel()
        monitorTask?.cancel()
        snoozeTask?.cancel()
    }

    private func handleWatchSessionEvent(_ event: WatchSessionEvent) {
        switch event {
        case .activated:
            statusNote = "通信已激活"
        case .reachabilityChanged(let isReachable):
            statusNote = isReachable ? "iPhone 在线" : "iPhone 离线"
        case .received(let envelope):
            routeIncomingMessage(envelope)
        case .transportQueued:
            statusNote = "消息已排队"
        case .transportError(let reason):
            statusNote = "通信错误: \(reason)"
        }
    }

    private func routeIncomingMessage(_ envelope: WatchMessageEnvelope) {
        switch envelope {
        case .alarmPlanSync(let payload):
            alarmPlan = Dictionary(uniqueKeysWithValues: payload.alarms.map { ($0.id, $0) })
            Task {
                await logger.log(
                    .init(
                        alarmID: nil,
                        state: runtimeState,
                        source: "Watch",
                        event: "plan_received",
                        detail: "count=\(payload.alarms.count)"
                    )
                )
            }
        case .prewarm(let command):
            let snooze = alarmPlan[command.alarmID]?.snoozeMinutes ?? 5
            handlePrewarm(command, snoozeMinutes: snooze)
        case .ring(let event):
            currentAlarmID = event.alarmID
            startRinging()
        default:
            break
        }
    }
}

extension WatchAlarmRuntimeOrchestrator: @preconcurrency ExtendedRuntimeSessionControllerDelegate {
    public func runtimeSessionDidStart() {
        statusNote = "后台监测会话已启动"
        Task {
            await logger.log(
                .init(alarmID: currentAlarmID, state: .prewarming, source: "Watch", event: "runtime_session_started")
            )
        }
    }

    public func runtimeSessionDidInvalidate(error: Error?) {
        statusNote = "后台监测会话失效"
        Task {
            await logger.log(
                .init(
                    alarmID: currentAlarmID,
                    state: .degraded,
                    source: "Watch",
                    event: "runtime_session_invalidated",
                    detail: error?.localizedDescription
                )
            )
        }
    }
}
