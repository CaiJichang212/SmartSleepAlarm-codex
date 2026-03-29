import Foundation
import SmartSleepShared

#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

public enum WatchSessionEvent: Sendable {
    case activated
    case reachabilityChanged(isReachable: Bool)
    case received(WatchMessageEnvelope)
    case transportQueued
    case transportError(String)
}

public protocol WatchSessionCoordinator: Sendable {
    func activate() async
    func setEventHandler(_ handler: (@Sendable (WatchSessionEvent) -> Void)?) async
    func send(_ message: WatchMessageEnvelope) async throws
}

public actor LiveWatchSessionCoordinator: WatchSessionCoordinator {
    private let codec = WatchMessageCodec()
    private var eventHandler: (@Sendable (WatchSessionEvent) -> Void)?

    #if canImport(WatchConnectivity)
    private let proxy = WCSessionDelegateProxy()
    #endif

    public init() {
        #if canImport(WatchConnectivity)
        proxy.owner = self
        #endif
    }

    public func setEventHandler(_ handler: (@Sendable (WatchSessionEvent) -> Void)?) async {
        eventHandler = handler
    }

    public func activate() async {
        #if canImport(WatchConnectivity)
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = proxy
        session.activate()
        #endif
    }

    public func send(_ message: WatchMessageEnvelope) async throws {
        #if canImport(WatchConnectivity)
        guard WCSession.isSupported() else { return }
        let data = try codec.encode(message)
        let session = WCSession.default

        if !session.isReachable {
            session.transferUserInfo(["payload": data])
            eventHandler?(.transportQueued)
            return
        }

        do {
            try await withCheckedThrowingContinuation { continuation in
                session.sendMessageData(data) { _ in
                    continuation.resume(returning: ())
                } errorHandler: { error in
                    continuation.resume(throwing: error)
                }
            }
        } catch {
            session.transferUserInfo(["payload": data])
            eventHandler?(.transportQueued)
        }
        #else
        _ = message
        #endif
    }

    #if canImport(WatchConnectivity)
    nonisolated fileprivate func didReceive(data: Data) {
        Task {
            await handleReceivedData(data)
        }
    }

    nonisolated fileprivate func didChangeReachability(_ isReachable: Bool) {
        Task {
            await eventHandler?(.reachabilityChanged(isReachable: isReachable))
        }
    }

    nonisolated fileprivate func didActivate() {
        Task {
            await eventHandler?(.activated)
        }
    }

    nonisolated fileprivate func didError(_ error: Error) {
        Task {
            await eventHandler?(.transportError(error.localizedDescription))
        }
    }

    private func handleReceivedData(_ data: Data) async {
        do {
            let message = try codec.decode(data)
            eventHandler?(.received(message))
        } catch {
            eventHandler?(.transportError("decode_failed: \(error.localizedDescription)"))
        }
    }
    #endif
}

#if canImport(WatchConnectivity)
private final class WCSessionDelegateProxy: NSObject, WCSessionDelegate {
    weak var owner: LiveWatchSessionCoordinator?

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error {
            owner?.didError(error)
            return
        }
        owner?.didActivate()
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        owner?.didChangeReachability(session.isReachable)
    }

    func session(_ session: WCSession, didReceiveMessageData messageData: Data) {
        owner?.didReceive(data: messageData)
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        guard let data = userInfo["payload"] as? Data else { return }
        owner?.didReceive(data: data)
    }

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif
}
#endif
