import XCTest
@testable import SmartSleepDomain

final class SmartAlarmEngineTests: XCTestCase {
    func testAwakeWithinConfirmWindowSilencesAlarm() {
        var engine = SmartAlarmEngine()

        _ = engine.handle(.init(kind: .ringStarted))
        _ = engine.handle(.init(kind: .awakeSignal))
        let transition = engine.handle(.init(kind: .awakeConfirmTimeout))

        XCTAssertEqual(engine.state, .silenced)
        XCTAssertFalse(transition.shouldRing)
    }

    func testAsleepDuringMonitoringTriggersRering() {
        var engine = SmartAlarmEngine()

        _ = engine.handle(.init(kind: .ringStarted))
        _ = engine.handle(.init(kind: .awakeSignal))
        _ = engine.handle(.init(kind: .awakeConfirmTimeout))
        _ = engine.handle(.init(kind: .awakeSignal))

        let transition = engine.handle(.init(kind: .asleepSignal))
        XCTAssertEqual(engine.state, .reringing)
        XCTAssertTrue(transition.shouldRing)
    }

    func testDegradeAlwaysKeepsRingingFallback() {
        var engine = SmartAlarmEngine()

        let transition = engine.handle(.init(kind: .degrade(reason: .sensorTimeout)))
        XCTAssertEqual(engine.state, .degraded)
        XCTAssertTrue(transition.shouldRing)
    }
}
