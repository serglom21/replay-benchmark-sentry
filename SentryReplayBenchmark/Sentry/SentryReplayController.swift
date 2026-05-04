import Foundation
import Sentry

final class SentryReplayController {
    static let shared = SentryReplayController()

    private static let dsn = "https://3c3bd1fe451157ae740c0962d7b88e02@o4508236363464704.ingest.us.sentry.io/4510156232065024"

    // When true, startReplay() calls -[SentryReplayApi start] (reproduces the regression).
    // When false, startReplay() calls -[SentryReplayApi beginRecording] (same body, renamed selector — no regression).
    static let useStartSelectorKey = "sentry.bench.useStartSelector"

    private(set) var isRecording = false

    func configureAtLaunch() {
        SentrySDK.start { options in
            options.dsn = Self.dsn
            options.environment = "benchmark"
            options.debug = true
            options.tracesSampleRate = 0
            options.enableAutoPerformanceTracing = false
            options.enableAppHangTracking = false
            options.enableUserInteractionTracing = false
            options.enableUIViewControllerTracing = false
            options.enableNetworkTracking = false
            options.enableNetworkBreadcrumbs = false
            options.enableAutoSessionTracking = false
            options.enableMetricKit = false
            options.enableSwizzling = false
            options.attachScreenshot = false
            options.attachViewHierarchy = false

            options.sessionReplay.sessionSampleRate = 0
            options.sessionReplay.onErrorSampleRate = 0
            options.sessionReplay.maskAllText = false
            options.sessionReplay.maskAllImages = false

            // Allows session replay to run under the debugger and on Simulator.
            // Sentry's environment check otherwise gates replay to production-like
            // configurations to protect real user data; this app uses dummy data,
            // so it's appropriate to opt in for development environments.
            options.experimental.enableSessionReplayInUnreliableEnvironment = true
        }
    }

    func startReplay() {
        if UserDefaults.standard.bool(forKey: Self.useStartSelectorKey) {
            SentrySDK.replay.start()
        } else {
            SentrySDK.replay.beginRecording()
        }
        isRecording = true
    }

    func stopReplay() {
        SentrySDK.replay.stop()
        isRecording = false
    }
}
