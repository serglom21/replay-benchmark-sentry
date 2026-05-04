# Sentry Session Replay — Frame Rate Benchmark

A minimal iOS app that drives a representative scrolling workload and measures
frame rate, slow frames, and frozen frames. Session replay can be toggled
on or off per benchmark run to compare configurations side-by-side.

The app's only dependency is **Sentry 9.5+** (Swift Package Manager).

## What it measures

- A scrolling `UICollectionView` with 5,000 cells. Each cell renders a
  `CAGradientLayer`, a `CAShapeLayer` with an animated wave path, a shadow
  path, multiple labels, decoration views, and a rotating spinner. Both
  spinner rotation and the wave path are driven by render-server-side
  `CAAnimation`s for predictable steady-state behavior.
- A `CADisplayLink`-based `FrameTracker` records every frame's actual
  interval. It classifies slow frames (> 16.67 ms) and frozen frames (> 700
  ms) using the same definitions Sentry's own SDK does.
- A configurable benchmark window (15s / 30s / 60s) captures a `FrameStats`
  summary (avg FPS, slow %, frozen count, p50/p90/p99 frame interval, max
  frame) plus the chronological list of frame intervals for plotting.
- The Setup screen lists past runs, including a compact frame-interval
  graph for each, so multiple runs can be visually compared at a glance.

## Running

1. Open `SentryReplayBenchmark.xcodeproj` in Xcode 15 or later.
2. Wait for SPM to resolve the Sentry package on first launch.
3. Set your development team in the target's *Signing & Capabilities* tab.
4. Open `SentryReplayBenchmark/Sentry/SentryReplayController.swift` and
   replace the `dsn` placeholder with your project's DSN.
5. **Build the Release configuration on a physical device.** Simulator
   timings are not representative.
6. On the Setup screen, leave the replay toggle OFF and tap **Start
   Benchmark** with your chosen duration. Note the result.
7. Return to Setup, flip the replay toggle ON, and start another run.
8. Repeat 3× for stable numbers; the Recent Runs list shows summaries and
   per-run graphs side by side.

## How session replay is enabled

The SDK is initialized with both `sessionSampleRate` and `onErrorSampleRate`
set to 0, which means the session replay integration is not auto-installed
at startup. The toggle uses `SentrySDK.replay.start()` /
`SentrySDK.replay.stop()`, which the SDK supports for manual control — it
lazy-installs the integration on the first `start()` call and removes
recording state on `stop()`.

`options.experimental.enableSessionReplayInUnreliableEnvironment = true` is
set so replay can also run under the debugger and on Simulator. This option
is normally gated to production-like environments to protect real user
data; this app uses dummy data, so opting in for development is
appropriate.

## Project layout

| Path | Purpose |
|---|---|
| `App/AppDelegate.swift` | Boots Sentry on launch. |
| `App/SceneDelegate.swift` | Installs the navigation stack. |
| `Sentry/SentryReplayController.swift` | Sentry SDK initialization and replay start/stop wrappers. |
| `Frames/FrameTracker.swift` | `CADisplayLink` per-frame measurement and classification. |
| `Frames/FrameStats.swift` | Aggregate / percentile result type. |
| `Workload/IntensiveCollectionView.swift` | Scrolling collection view, cells, animations. |
| `UI/SetupViewController.swift` | Setup screen — toggle, duration picker, recent runs. |
| `UI/RunningBenchmarkViewController.swift` | Running screen — workload + live readouts + progress. |
| `UI/ResultsViewController.swift` | Results screen — summary card and full graph. |
| `UI/FrameRateGraphView.swift` | `CAShapeLayer`-backed frame-interval graph. |
| `UI/ResultsStore.swift` | Persists past runs (summary + intervals) in `UserDefaults`. |

## Verifying the toggle

`options.debug = true` is enabled, so `[Session Replay] Starting session` /
`[Session Replay] Stopping session` log lines appear in the Xcode console
when the toggle is flipped — useful as a confirmation that the replay
recorder is starting and stopping as expected.
