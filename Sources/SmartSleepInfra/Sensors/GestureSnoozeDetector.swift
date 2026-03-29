import Foundation

#if canImport(CoreMotion) && (os(iOS) || os(watchOS))
import CoreMotion
#endif

public protocol GestureSnoozeDetector: AnyObject {
    var onFlipDetected: (@Sendable () -> Void)? { get set }
    func start()
    func stop()
}

public final class CoreMotionFlipDetector: GestureSnoozeDetector {
    public var onFlipDetected: (@Sendable () -> Void)?

    #if canImport(CoreMotion) && (os(iOS) || os(watchOS))
    private let motionManager = CMMotionManager()
    #endif

    private let detectionThreshold = 3.2

    public init() {}

    public func start() {
        #if canImport(CoreMotion) && (os(iOS) || os(watchOS))
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = 0.1
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let motion else { return }
            let rotationMagnitude = abs(motion.rotationRate.x) + abs(motion.rotationRate.y) + abs(motion.rotationRate.z)
            if rotationMagnitude > self?.detectionThreshold ?? 1000 {
                self?.onFlipDetected?()
            }
        }
        #endif
    }

    public func stop() {
        #if canImport(CoreMotion) && (os(iOS) || os(watchOS))
        motionManager.stopDeviceMotionUpdates()
        #endif
    }
}
