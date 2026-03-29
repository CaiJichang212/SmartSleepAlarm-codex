import XCTest
@testable import SmartSleepiOS

final class SnoozeSettingsRepositoryTests: XCTestCase {
    func testDefaultValueIsFiveWhenUnset() {
        let defaults = UserDefaults(suiteName: "SmartSleepiOSTests.default")!
        defaults.removePersistentDomain(forName: "SmartSleepiOSTests.default")

        let repository = UserDefaultsSnoozeSettingsRepository(defaults: defaults)
        XCTAssertEqual(repository.getDefaultSnoozeMinutes(), 5)
    }

    func testSnoozeMinutesAreClamped() {
        let defaults = UserDefaults(suiteName: "SmartSleepiOSTests.clamp")!
        defaults.removePersistentDomain(forName: "SmartSleepiOSTests.clamp")

        let repository = UserDefaultsSnoozeSettingsRepository(defaults: defaults)
        repository.setDefaultSnoozeMinutes(0)
        XCTAssertEqual(repository.getDefaultSnoozeMinutes(), 1)

        repository.setDefaultSnoozeMinutes(35)
        XCTAssertEqual(repository.getDefaultSnoozeMinutes(), 30)
    }
}
