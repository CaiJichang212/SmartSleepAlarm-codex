import XCTest
import SmartSleepDomain
import SmartSleepInfra
import SmartSleepShared
@testable import SmartSleepWatch

private actor StableSignalProvider: SleepSignalProvider {
    func latestReadout() async -> SleepSignalReadout {
        .init(signal: SleepSignal(heartRateBPM: 78, accelerationMagnitude: 0.2), degradeReason: nil)
    }
}

private struct UncertainAnalyzer: SleepSignalAnalyzer {
    func infer(from signal: SleepSignal) -> SleepInference { .uncertain }
}

private struct AlwaysAwakeAnalyzer: SleepSignalAnalyzer {
    func infer(from signal: SleepSignal) -> SleepInference { .awake(confidence: 0.95) }
}

private actor SilentWatchSession: WatchSessionCoordinator {
    func activate() async {}
    func setEventHandler(_ handler: (@Sendable (WatchSessionEvent) -> Void)?) async {}
    func send(_ message: WatchMessageEnvelope) async throws {}
}

private final class NoopGestureDetector: GestureSnoozeDetector {
    var onFlipDetected: (@Sendable () -> Void)?
    func start() {}
    func stop() {}
}

private final class StartedRuntimeController: RuntimeSessionControlling {
    weak var delegate: ExtendedRuntimeSessionControllerDelegate?
    func start() { delegate?.runtimeSessionDidStart() }
    func stop() {}
}

private final class RecordingFeedback: WatchAlarmFeedbackPlayer {
    private(set) var transitions: [(RuntimeState, RuntimeState)] = []
    func playTransition(from: RuntimeState, to: RuntimeState) {
        transitions.append((from, to))
    }
}

private actor SilentLogger: AlarmEventLogger {
    func log(_ entry: AlarmRuntimeLogEntry) async {}
}

@MainActor
final class WatchSnoozeFeedbackTests: XCTestCase {
    func testAwakeSignalStopsRingingWithinFiveSeconds() async {
        let orchestrator = WatchAlarmRuntimeOrchestrator(
            analyzer: AlwaysAwakeAnalyzer(),
            signalProvider: StableSignalProvider(),
            gestureDetector: NoopGestureDetector(),
            watchSession: SilentWatchSession(),
            logger: SilentLogger(),
            runtimeSessionController: StartedRuntimeController(),
            feedbackPlayer: RecordingFeedback()
        )

        orchestrator.handlePrewarm(
            .init(alarmID: UUID(), triggerDate: Date().addingTimeInterval(60), prewarmDate: Date()),
            snoozeMinutes: 5
        )

        let start = Date()
        orchestrator.startRinging()

        var reachedNonRinging = false
        for _ in 0..<45 {
            if orchestrator.runtimeState != .ringing && orchestrator.runtimeState != .reringing {
                reachedNonRinging = true
                break
            }
            try? await Task.sleep(for: .milliseconds(100))
        }

        XCTAssertTrue(reachedNonRinging)
        XCTAssertLessThan(Date().timeIntervalSince(start), 5.0)
    }

    func testGestureSnoozeUpdatesStatusAndPlaysFeedback() async {
        let feedback = RecordingFeedback()
        let orchestrator = WatchAlarmRuntimeOrchestrator(
            analyzer: UncertainAnalyzer(),
            signalProvider: StableSignalProvider(),
            gestureDetector: NoopGestureDetector(),
            watchSession: SilentWatchSession(),
            logger: SilentLogger(),
            runtimeSessionController: StartedRuntimeController(),
            feedbackPlayer: feedback
        )

        orchestrator.handlePrewarm(
            .init(alarmID: UUID(), triggerDate: Date().addingTimeInterval(60), prewarmDate: Date()),
            snoozeMinutes: 7
        )
        orchestrator.startRinging()
        orchestrator.triggerSnoozeFromGesture()

        XCTAssertEqual(orchestrator.runtimeState, .silenced)
        XCTAssertTrue(orchestrator.statusNote.contains("已贪睡 7 分钟"))
        XCTAssertTrue(feedback.transitions.contains(where: { $0.0 == .ringing && $0.1 == .silenced }))
    }
}
