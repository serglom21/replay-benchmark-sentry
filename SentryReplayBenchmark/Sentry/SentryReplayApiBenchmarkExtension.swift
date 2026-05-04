import Sentry

// Exposes -[SentryReplayApi beginRecording] to Swift.
// The method has the same body as -start but a different selector name.
// On iOS 26, calling -start causes a ~3fps regression; calling -beginRecording does not.
// This extension makes the method visible to the Swift module without modifying the SDK's
// public Swift API surface.
extension SentryReplayApi {
    @objc func beginRecording() {}
}
