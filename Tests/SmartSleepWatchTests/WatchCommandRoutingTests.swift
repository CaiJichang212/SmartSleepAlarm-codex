import XCTest
import SmartSleepDomain
import SmartSleepInfra
import SmartSleepShared
@testable import SmartSleepWatch

private final class MockGestureDetector: GestureSnoozeDetector {
    var onFlipDetected: (@Sendable () -> Void)?
    func start() {}
    func stop() {}
}

private actor MockSignalProvider: SleepSignalProvider {
    func latestReadout() async -> SleepSignalReadout {
        .init(signal: nil, degradeReason: .sensorTimeout)
    }
}

private struct MockAnalyzer: SleepSignalAnalyzer {
    func infer(from signal: SleepSignal) -> SleepInference { .uncertain }
}

private final class MockRuntimeSessionController: RuntimeSessionControlling {
    weak var delegate: ExtendedRuntimeSessionControllerDelegate?
    private(set) var started = false

    func start() {
        started = true
        delegate?.runtimeSessionDidStart()
    }

    func stop() {}
}

private actor MockWatchSession: WatchSessionCoordinator {
    var handler: (@Sendable (WatchSessionEvent) -> Void)?

    func activate() async {}
    func setEventHandler(_ handler: (@Sendable (WatchSessionEvent) -> Void)?) async {
        self.handler = handler
    }

    func send(_ message: WatchMessageEnvelope) async throws {}

    func emit(_ event: WatchSessionEvent) {
        handler?(event)
    }
}

private actor NoopLogger: AlarmEventLogger {
    func log(_ entry: AlarmRuntimeLogEntry) async {}
}

@MainActor
final class WatchCommandRoutingTests: XCTestCase {
    func testPrewarmMessageStartsRuntimeSession() async {
        let session = MockWatchSession()
        let runtime = MockRuntimeSessionController()

        let alarm = Alarm(hour: 7, minute: 0, repeatWeekdays: [.monday], label: "A", soundID: "default", snoozeMinutes: 9)

        let orchestrator = WatchAlarmRuntimeOrchestrator(
            analyzer: MockAnalyzer(),
            signalProvider: MockSignalProvider(),
            gestureDetector: MockGestureDetector(),
            watchSession: session,
            logger: NoopLogger(),
            runtimeSessionController: runtime
        )

        orchestrator.activate()

        await session.emit(.received(.alarmPlanSync(.init(alarms: [alarm]))))
        await session.emit(
            .received(
                .prewarm(
                    .init(
                        alarmID: alarm.id,
                        triggerDate: Date().addingTimeInterval(1800),
                        prewarmDate: Date()
                    )
                )
            )
        )

        XCTAssertTrue(runtime.started)
        XCTAssertEqual(orchestrator.runtimeState, .prewarming)
    }
}
