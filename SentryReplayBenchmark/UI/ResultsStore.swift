import Foundation

/// Pairing of summary stats with the chronological per-frame interval samples.
/// Persisted together so the setup screen's recent-runs list can render the
/// per-run frame-rate graph without re-running the benchmark.
struct BenchmarkResult {
    let stats: FrameStats
    let intervalsMs: [Double]
}

final class ResultsStore {
    static let shared = ResultsStore()

    private static let key = "SentryReplayBenchmark.results.v2"
    private static let maxResults = 20
    /// Cap intervals stored per run to keep UserDefaults sane. 8K samples is
    /// enough for ~67s @ 120fps; longer runs get truncated head, which is fine
    /// because the graph downsamples anyway.
    private static let maxIntervalsPerResult = 8_192

    private let defaults = UserDefaults.standard

    private(set) var results: [BenchmarkResult] = []

    init() { results = load() }

    func append(_ result: BenchmarkResult) {
        let trimmed: BenchmarkResult
        if result.intervalsMs.count > Self.maxIntervalsPerResult {
            trimmed = BenchmarkResult(
                stats: result.stats,
                intervalsMs: Array(result.intervalsMs.suffix(Self.maxIntervalsPerResult))
            )
        } else {
            trimmed = result
        }
        results.insert(trimmed, at: 0)
        if results.count > Self.maxResults {
            results = Array(results.prefix(Self.maxResults))
        }
        save()
    }

    func clear() {
        results.removeAll()
        defaults.removeObject(forKey: Self.key)
    }

    private func save() {
        let encoded = results.map { result -> [String: Any] in
            let stats = result.stats
            return [
                "durationSec": stats.durationSec,
                "totalFrames": stats.totalFrames,
                "avgFps": stats.avgFps,
                "slowFrameCount": stats.slowFrameCount,
                "slowFramePercent": stats.slowFramePercent,
                "frozenFrameCount": stats.frozenFrameCount,
                "p50ms": stats.p50ms,
                "p90ms": stats.p90ms,
                "p99ms": stats.p99ms,
                "maxMs": stats.maxMs,
                "replayWasOn": stats.replayWasOn,
                "timestamp": stats.timestamp.timeIntervalSince1970,
                "intervalsMs": result.intervalsMs
            ]
        }
        defaults.set(encoded, forKey: Self.key)
    }

    private func load() -> [BenchmarkResult] {
        guard let raw = defaults.array(forKey: Self.key) as? [[String: Any]] else { return [] }
        return raw.compactMap { dict in
            guard
                let durationSec = dict["durationSec"] as? Double,
                let totalFrames = dict["totalFrames"] as? Int,
                let avgFps = dict["avgFps"] as? Double,
                let slowFrameCount = dict["slowFrameCount"] as? Int,
                let slowFramePercent = dict["slowFramePercent"] as? Double,
                let frozenFrameCount = dict["frozenFrameCount"] as? Int,
                let p50ms = dict["p50ms"] as? Double,
                let p90ms = dict["p90ms"] as? Double,
                let p99ms = dict["p99ms"] as? Double,
                let maxMs = dict["maxMs"] as? Double,
                let replayWasOn = dict["replayWasOn"] as? Bool,
                let timestamp = dict["timestamp"] as? Double
            else { return nil }
            let stats = FrameStats(
                durationSec: durationSec,
                totalFrames: totalFrames,
                avgFps: avgFps,
                slowFrameCount: slowFrameCount,
                slowFramePercent: slowFramePercent,
                frozenFrameCount: frozenFrameCount,
                p50ms: p50ms,
                p90ms: p90ms,
                p99ms: p99ms,
                maxMs: maxMs,
                replayWasOn: replayWasOn,
                timestamp: Date(timeIntervalSince1970: timestamp)
            )
            let intervalsMs = (dict["intervalsMs"] as? [Double]) ?? []
            return BenchmarkResult(stats: stats, intervalsMs: intervalsMs)
        }
    }
}
