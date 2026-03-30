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

    private let rotationThreshold: Double
    private let gravityDeltaThreshold: Double
    private let requiredHits: Int
    private let cooldownSeconds: TimeInterval
    private var consecutiveHits: Int = 0
    private var lastGravityZ: Double?
    private var lastTriggerTime: Date = .distantPast

    public init(
        rotationThreshold: Double = 3.8,
        gravityDeltaThreshold: Double = 0.45,
        requiredHits: Int = 2,
        cooldownSeconds: TimeInterval = 1.5
    ) {
        self.rotationThreshold = rotationThreshold
        self.gravityDeltaThreshold = gravityDeltaThreshold
        self.requiredHits = max(1, requiredHits)
        self.cooldownSeconds = max(0.5, cooldownSeconds)
    }

    public func start() {
        #if canImport(CoreMotion) && (os(iOS) || os(watchOS))
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = 0.1
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }

            let now = Date()
            if now.timeIntervalSince(self.lastTriggerTime) < self.cooldownSeconds {
                return
            }

            let rotationMagnitude = abs(motion.rotationRate.x) + abs(motion.rotationRate.y) + abs(motion.rotationRate.z)
            let deltaZ = abs(motion.gravity.z - (self.lastGravityZ ?? motion.gravity.z))
            self.lastGravityZ = motion.gravity.z

            if rotationMagnitude > self.rotationThreshold && deltaZ > self.gravityDeltaThreshold {
                self.consecutiveHits += 1
            } else {
                self.consecutiveHits = 0
            }

            guard self.consecutiveHits >= self.requiredHits else { return }
            self.consecutiveHits = 0
            self.lastTriggerTime = now
            self.onFlipDetected?()
        }
        #endif
    }

    public func stop() {
        #if canImport(CoreMotion) && (os(iOS) || os(watchOS))
        motionManager.stopDeviceMotionUpdates()
        consecutiveHits = 0
        lastGravityZ = nil
        #endif
    }
}
