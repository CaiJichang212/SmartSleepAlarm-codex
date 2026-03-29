import XCTest
@testable import SmartSleepDomain

final class SnoozePolicyTests: XCTestCase {
    func testSnoozeMinutesAreClamped() {
        let policy = SnoozePolicy()
        XCTAssertEqual(policy.sanitizedMinutes(0), 1)
        XCTAssertEqual(policy.sanitizedMinutes(31), 30)
        XCTAssertEqual(policy.sanitizedMinutes(8), 8)
    }
}
