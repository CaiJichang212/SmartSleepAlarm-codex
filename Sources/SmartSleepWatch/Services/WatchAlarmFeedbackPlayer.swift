import Foundation
import SmartSleepDomain

#if canImport(WatchKit) && os(watchOS)
import WatchKit
#endif

public protocol WatchAlarmFeedbackPlayer: AnyObject {
    func playTransition(from: RuntimeState, to: RuntimeState)
}

public final class LiveWatchAlarmFeedbackPlayer: WatchAlarmFeedbackPlayer {
    public init() {}

    public func playTransition(from: RuntimeState, to: RuntimeState) {
        guard from != to else { return }
        #if canImport(WatchKit) && os(watchOS)
        let haptic: WKHapticType?
        switch to {
        case .ringing, .reringing:
            haptic = .notification
        case .silenced:
            haptic = .click
        case .degraded:
            haptic = .failure
        case .dismissed:
            haptic = .success
        default:
            haptic = nil
        }
        if let haptic {
            WKInterfaceDevice.current().play(haptic)
        }
        #endif
    }
}

