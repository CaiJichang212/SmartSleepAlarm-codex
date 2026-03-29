import XCTest
import SmartSleepDomain
@testable import SmartSleepShared

final class WatchMessageCodecTests: XCTestCase {
    func testRoundTripEnvelope() throws {
        let codec = WatchMessageCodec()
        let alarm = Alarm(hour: 7, minute: 30, repeatWeekdays: [.monday], label: "Morning", soundID: "default")
        let original = WatchMessageEnvelope.alarmPlanSync(.init(alarms: [alarm]))

        let data = try codec.encode(original)
        let decoded = try codec.decode(data)

        guard case .alarmPlanSync(let payload) = decoded else {
            XCTFail("Expected alarmPlanSync envelope")
            return
        }
        XCTAssertEqual(payload.alarms, [alarm])
    }
}
