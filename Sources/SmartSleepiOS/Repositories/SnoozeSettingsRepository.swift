import Foundation

public protocol SnoozeSettingsRepository {
    func getDefaultSnoozeMinutes() -> Int
    func setDefaultSnoozeMinutes(_ value: Int)
}

public final class UserDefaultsSnoozeSettingsRepository: SnoozeSettingsRepository {
    private let defaults: UserDefaults
    private let key = "smartsleep.defaultSnoozeMinutes"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func getDefaultSnoozeMinutes() -> Int {
        let value = defaults.integer(forKey: key)
        if value == 0 {
            return 5
        }
        return max(1, min(30, value))
    }

    public func setDefaultSnoozeMinutes(_ value: Int) {
        defaults.set(max(1, min(30, value)), forKey: key)
    }
}
