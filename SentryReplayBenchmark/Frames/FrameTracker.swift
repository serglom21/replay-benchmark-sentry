import QuartzCore
import UIKit

protocol FrameTrackerObserver: AnyObject {
    func frameTrackerDidTick(_ tracker: FrameTracker)
}

final class FrameTracker {
    // Mirrors Sentry's own slow-frame definition: > 16.67ms regardless of refresh rate,
    // OR longer than the device's expected frame interval (whichever is larger).
    static let baseSlowFrameThresholdMs: Double = 1000.0 / 60.0   // 16.67ms
    static let frozenFrameThresholdMs: Double = 700.0

    private static let baseSlowFrameThresholdSec: CFTimeInterval = 1.0 / 60.0
    private static let frozenFrameThresholdSec: CFTimeInterval = 0.7
    private static let maxIntervalSamples = 16_384

    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0
    private weak var observer: FrameTrackerObserver?

    private(set) var totalFrames = 0
    private(set) var slowFrameCount = 0
    private(set) var frozenFrameCount = 0
    private(set) var totalElapsedSec: Double = 0
    private(set) var maxFrameMs: Double = 0
    private(set) var lastFrameMs: Double = 0
    private(set) var lastExpectedFrameMs: Double = 0

    /// Chronologically ordered frame intervals in milliseconds. Used for both
    /// percentile computation and the post-benchmark FPS-over-time graph.
    private(set) var intervalsMs: [Double] = []

    var avgFps: Double {
        guard totalElapsedSec > 0 else { return 0 }
        return Double(totalFrames) / totalElapsedSec
    }

    var slowFramePercent: Double {
        guard totalFrames > 0 else { return 0 }
        return 100.0 * Double(slowFrameCount) / Double(totalFrames)
    }

    func setObserver(_ observer: FrameTrackerObserver) {
        self.observer = observer
    }

    func start() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 120, preferred: 0)
        link.add(to: .main, forMode: .common)
        lastTimestamp = 0
        displayLink = link
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
    }

    func reset() {
        totalFrames = 0
        slowFrameCount = 0
        frozenFrameCount = 0
        totalElapsedSec = 0
        maxFrameMs = 0
        lastFrameMs = 0
        lastExpectedFrameMs = 0
        intervalsMs.removeAll(keepingCapacity: true)
        lastTimestamp = 0
    }

    @objc private func tick(_ link: CADisplayLink) {
        defer { observer?.frameTrackerDidTick(self) }

        guard lastTimestamp != 0 else {
            lastTimestamp = link.timestamp
            return
        }

        let actual = link.timestamp - lastTimestamp
        lastTimestamp = link.timestamp

        let expected = max(link.targetTimestamp - link.timestamp, 1.0 / 120.0)
        let slowThreshold = max(Self.baseSlowFrameThresholdSec, expected + 0.001)

        totalFrames += 1
        totalElapsedSec += actual
        lastFrameMs = actual * 1000
        lastExpectedFrameMs = expected * 1000

        if actual > maxFrameMs / 1000 {
            maxFrameMs = actual * 1000
        }
        if actual > slowThreshold {
            slowFrameCount += 1
        }
        if actual > Self.frozenFrameThresholdSec {
            frozenFrameCount += 1
        }

        if intervalsMs.count < Self.maxIntervalSamples {
            intervalsMs.append(actual * 1000)
        }
    }

    func snapshot(durationSec: Double, replayWasOn: Bool) -> FrameStats {
        let sorted = intervalsMs.sorted()
        func percentile(_ p: Double) -> Double {
            guard !sorted.isEmpty else { return 0 }
            let idx = min(max(Int(Double(sorted.count - 1) * p), 0), sorted.count - 1)
            return sorted[idx]
        }
        return FrameStats(
            durationSec: durationSec,
            totalFrames: totalFrames,
            avgFps: avgFps,
            slowFrameCount: slowFrameCount,
            slowFramePercent: slowFramePercent,
            frozenFrameCount: frozenFrameCount,
            p50ms: percentile(0.50),
            p90ms: percentile(0.90),
            p99ms: percentile(0.99),
            maxMs: maxFrameMs,
            replayWasOn: replayWasOn,
            timestamp: Date()
        )
    }
}
