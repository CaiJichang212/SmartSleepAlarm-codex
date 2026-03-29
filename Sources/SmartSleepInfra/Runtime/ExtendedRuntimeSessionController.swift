import Foundation

public protocol RuntimeSessionControlling: AnyObject {
    var delegate: ExtendedRuntimeSessionControllerDelegate? { get set }
    func start()
    func stop()
}

#if os(watchOS)
import WatchKit

public protocol ExtendedRuntimeSessionControllerDelegate: AnyObject {
    func runtimeSessionDidStart()
    func runtimeSessionDidInvalidate(error: Error?)
}

public final class ExtendedRuntimeSessionController: NSObject, WKExtendedRuntimeSessionDelegate, RuntimeSessionControlling {
    private var session: WKExtendedRuntimeSession?
    public weak var delegate: ExtendedRuntimeSessionControllerDelegate?

    public override init() {
        super.init()
    }

    public func start() {
        guard session == nil else { return }
        let runtimeSession = WKExtendedRuntimeSession()
        runtimeSession.delegate = self
        session = runtimeSession
        runtimeSession.start()
    }

    public func stop() {
        session?.invalidate()
        session = nil
    }

    public func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        delegate?.runtimeSessionDidStart()
    }

    public func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {}

    public func extendedRuntimeSession(_ extendedRuntimeSession: WKExtendedRuntimeSession, didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason, error: Error?) {
        delegate?.runtimeSessionDidInvalidate(error: error)
        session = nil
    }
}
#else
public protocol ExtendedRuntimeSessionControllerDelegate: AnyObject {
    func runtimeSessionDidStart()
    func runtimeSessionDidInvalidate(error: Error?)
}

public final class ExtendedRuntimeSessionController: RuntimeSessionControlling {
    public weak var delegate: ExtendedRuntimeSessionControllerDelegate?

    public init() {}
    public func start() { delegate?.runtimeSessionDidStart() }
    public func stop() {}
}
#endif
