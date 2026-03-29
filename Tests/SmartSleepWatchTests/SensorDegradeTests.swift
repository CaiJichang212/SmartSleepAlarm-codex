import XCTest
import SmartSleepDomain
import SmartSleepInfra
import SmartSleepShared
@testable import SmartSleepWatch

private actor PermissionMissingProvider: SleepSignalProvider {
    func latestReadout() async -> SleepSignalReadout {
        .init(signal: nil, degradeReason: .healthPermissionMissing, detail: "no_health_permission")
    }
}

private actor SilentSession: WatchSessionCoordinator {
    func activate() async {}
    func setEventHandler(_ handler: (@Sendable (WatchSessionEvent) -> Void)?) async {}
    func send(_ message: WatchMessageEnvelope) async throws {}
}

private struct StaticAnalyzer: SleepSignalAnalyzer {
    func infer(from signal: SleepSignal) -> SleepInference { .uncertain }
}

private final class NoopGesture: GestureSnoozeDetector {
    var onFlipDetected: (@Sendable () -> Void)?
    func start() {}
    func stop() {}
}

private final class NoopRuntimeController: RuntimeSessionControlling {
    weak var delegate: ExtendedRuntimeSessionControllerDelegate?
    func start() {}
    func stop() {}
}

private actor NoopLog: AlarmEventLogger {
    func log(_ entry: AlarmRuntimeLogEntry) async {}
}

@MainActor
final class SensorDegradeTests: XCTestCase {
    func testPermissionMissingTriggersDegradedState() async {
        let orchestrator = WatchAlarmRuntimeOrchestrator(
            analyzer: StaticAnalyzer(),
            signalProvider: PermissionMissingProvider(),
            gestureDetector: NoopGesture(),
            watchSession: SilentSession(),
            logger: NoopLog(),
            runtimeSessionController: NoopRuntimeController()
        )

        orchestrator.startRinging()
        try? await Task.sleep(for: .milliseconds(80))

        XCTAssertEqual(orchestrator.runtimeState, .degraded)
    }
}
