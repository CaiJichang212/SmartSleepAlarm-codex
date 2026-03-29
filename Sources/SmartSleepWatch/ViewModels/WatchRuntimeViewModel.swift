import Foundation
import Combine
import SmartSleepShared

@MainActor
public final class WatchRuntimeViewModel: ObservableObject {
    @Published public private(set) var stateText: String = "Idle"
    @Published public private(set) var detailText: String = "等待闹铃"

    private let orchestrator: WatchAlarmRuntimeOrchestrator
    private var timerTask: Task<Void, Never>?

    public init(orchestrator: WatchAlarmRuntimeOrchestrator = .init()) {
        self.orchestrator = orchestrator
    }

    public func onAppear() {
        orchestrator.activate()
        bind()
        timerTask?.cancel()
        timerTask = Task { @MainActor in
            while !Task.isCancelled {
                bind()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    public func simulatePrewarmAndRing() {
        let now = Date()
        let cmd = PrewarmCommand(alarmID: UUID(), triggerDate: now.addingTimeInterval(30), prewarmDate: now)
        orchestrator.handlePrewarm(cmd, snoozeMinutes: 5)
        orchestrator.startRinging()
    }

    public func triggerSnooze() {
        orchestrator.triggerSnoozeFromGesture()
    }

    public func dismiss() {
        orchestrator.manualDismiss()
        bind()
    }

    private func bind() {
        stateText = orchestrator.runtimeState.rawValue
        detailText = orchestrator.statusNote
    }
}
