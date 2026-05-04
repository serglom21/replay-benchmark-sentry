import Foundation

struct FrameStats {
    let durationSec: Double
    let totalFrames: Int
    let avgFps: Double
    let slowFrameCount: Int
    let slowFramePercent: Double
    let frozenFrameCount: Int
    let p50ms: Double
    let p90ms: Double
    let p99ms: Double
    let maxMs: Double
    let replayWasOn: Bool
    let timestamp: Date

    var oneLineSummary: String {
        let replay = replayWasOn ? "ON " : "OFF"
        return String(
            format: "replay=%@ · %.0fs · %.1ffps · %.1f%% slow · %d frozen · p99=%.1fms",
            replay,
            durationSec,
            avgFps,
            slowFramePercent,
            frozenFrameCount,
            p99ms
        )
    }
}
