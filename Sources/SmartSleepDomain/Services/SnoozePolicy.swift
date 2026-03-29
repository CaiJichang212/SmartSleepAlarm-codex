import Foundation

public struct SnoozePolicy {
    public init() {}

    public func sanitizedMinutes(_ value: Int) -> Int {
        max(1, min(30, value))
    }

    public func nextSnoozeDate(from now: Date = Date(), minutes: Int) -> Date {
        now.addingTimeInterval(TimeInterval(sanitizedMinutes(minutes) * 60))
    }
}
