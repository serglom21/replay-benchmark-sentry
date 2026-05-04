import UIKit

final class RunningBenchmarkViewController: UIViewController, FrameTrackerObserver {
    private let config: BenchmarkConfig
    private let workload = IntensiveCollectionView()
    private let tracker = FrameTracker()

    private let overlayCard = UIView()
    private let stateLabel = UILabel()
    private let liveFps = UILabel()
    private let liveSlow = UILabel()
    private let liveFrozen = UILabel()
    private let progressBar = UIProgressView(progressViewStyle: .bar)
    private let countdown = UILabel()

    private var benchmarkStart: Date?
    private var displayUpdateCounter = 0
    private var didFinish = false

    init(config: BenchmarkConfig) {
        self.config = config
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Running"
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.hidesBackButton = true

        setupHierarchy()
        configureOverlay()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if config.replayEnabled {
            SentryReplayController.shared.startReplay()
        } else {
            SentryReplayController.shared.stopReplay()
        }
        // Wait 2 vsync frames so the display link registers at a stable phase,
        // eliminating any timing difference left by the navigation transition.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self else { return }
            self.tracker.setObserver(self)
            self.tracker.reset()
            self.tracker.start()
            self.workload.startScrolling()
            self.benchmarkStart = Date()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        workload.stopScrolling()
        tracker.stop()
        SentryReplayController.shared.stopReplay()
    }

    private func setupHierarchy() {
        workload.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(workload)
        overlayCard.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(overlayCard)

        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            workload.topAnchor.constraint(equalTo: view.topAnchor),
            workload.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            workload.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            workload.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            overlayCard.topAnchor.constraint(equalTo: safe.topAnchor, constant: 8),
            overlayCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            overlayCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12)
        ])
    }

    private func configureOverlay() {
        overlayCard.backgroundColor = UIColor.black.withAlphaComponent(0.78)
        overlayCard.layer.cornerRadius = 14

        stateLabel.text = config.replayEnabled ? "REPLAY ON" : "REPLAY OFF"
        stateLabel.textColor = config.replayEnabled ? .systemRed : .systemGreen
        stateLabel.font = .systemFont(ofSize: 11, weight: .heavy)

        liveFps.font = .monospacedDigitSystemFont(ofSize: 14, weight: .semibold)
        liveSlow.font = .monospacedDigitSystemFont(ofSize: 14, weight: .semibold)
        liveFrozen.font = .monospacedDigitSystemFont(ofSize: 14, weight: .semibold)
        countdown.font = .monospacedDigitSystemFont(ofSize: 14, weight: .semibold)
        for label in [liveFps, liveSlow, liveFrozen, countdown] {
            label.textColor = .white
            label.translatesAutoresizingMaskIntoConstraints = false
        }
        countdown.textColor = .systemYellow
        stateLabel.translatesAutoresizingMaskIntoConstraints = false

        progressBar.translatesAutoresizingMaskIntoConstraints = false
        progressBar.progressTintColor = .systemBlue
        progressBar.trackTintColor = UIColor.white.withAlphaComponent(0.15)

        overlayCard.addSubview(stateLabel)
        overlayCard.addSubview(liveFps)
        overlayCard.addSubview(liveSlow)
        overlayCard.addSubview(liveFrozen)
        overlayCard.addSubview(countdown)
        overlayCard.addSubview(progressBar)

        NSLayoutConstraint.activate([
            stateLabel.topAnchor.constraint(equalTo: overlayCard.topAnchor, constant: 10),
            stateLabel.leadingAnchor.constraint(equalTo: overlayCard.leadingAnchor, constant: 12),

            countdown.centerYAnchor.constraint(equalTo: stateLabel.centerYAnchor),
            countdown.trailingAnchor.constraint(equalTo: overlayCard.trailingAnchor, constant: -12),

            liveFps.topAnchor.constraint(equalTo: stateLabel.bottomAnchor, constant: 8),
            liveFps.leadingAnchor.constraint(equalTo: overlayCard.leadingAnchor, constant: 12),

            liveSlow.topAnchor.constraint(equalTo: liveFps.topAnchor),
            liveSlow.leadingAnchor.constraint(equalTo: liveFps.trailingAnchor, constant: 14),

            liveFrozen.topAnchor.constraint(equalTo: liveFps.topAnchor),
            liveFrozen.leadingAnchor.constraint(equalTo: liveSlow.trailingAnchor, constant: 14),

            progressBar.topAnchor.constraint(equalTo: liveFps.bottomAnchor, constant: 10),
            progressBar.leadingAnchor.constraint(equalTo: overlayCard.leadingAnchor, constant: 12),
            progressBar.trailingAnchor.constraint(equalTo: overlayCard.trailingAnchor, constant: -12),
            progressBar.bottomAnchor.constraint(equalTo: overlayCard.bottomAnchor, constant: -12),
            progressBar.heightAnchor.constraint(equalToConstant: 4)
        ])
    }

    // MARK: - FrameTrackerObserver

    func frameTrackerDidTick(_ tracker: FrameTracker) {
        guard !didFinish, let start = benchmarkStart else { return }
        let elapsed = -start.timeIntervalSinceNow
        if elapsed >= config.durationSec {
            finish()
            return
        }
        displayUpdateCounter += 1
        guard displayUpdateCounter % 15 == 0 else { return }
        let remaining = max(0, config.durationSec - elapsed)
        liveFps.text = String(format: "%.1f fps", tracker.avgFps)
        liveSlow.text = String(format: "%.1f%% slow", tracker.slowFramePercent)
        liveFrozen.text = String(format: "%d frozen", tracker.frozenFrameCount)
        countdown.text = String(format: "%.0fs", remaining)
        progressBar.progress = Float(elapsed / config.durationSec)
    }

    private func finish() {
        didFinish = true
        let elapsed = -(benchmarkStart?.timeIntervalSinceNow ?? 0)
        let stats = tracker.snapshot(durationSec: elapsed, replayWasOn: config.replayEnabled)
        let intervals = tracker.intervalsMs
        ResultsStore.shared.append(BenchmarkResult(stats: stats, intervalsMs: intervals))

        let resultsVC = ResultsViewController(stats: stats, intervalsMs: intervals)
        navigationController?.setViewControllers(
            [navigationController?.viewControllers.first ?? UIViewController(), resultsVC],
            animated: true
        )
    }
}
