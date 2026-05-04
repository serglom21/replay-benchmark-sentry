import UIKit

struct BenchmarkConfig {
    let durationSec: Double
    let replayEnabled: Bool
}

final class SetupViewController: UIViewController {
    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private let titleLabel = UILabel()
    private let descLabel = UILabel()

    private let optionsCard = UIView()
    private let replayLabel = UILabel()
    private let replaySwitch = UISwitch()
    private let durationLabel = UILabel()
    private let durationControl = UISegmentedControl(items: ["15s", "30s", "60s"])

    private let recentHeaderRow = UIStackView()
    private let recentTitleLabel = UILabel()
    private let clearButton = UIButton(type: .system)
    private let recentStack = UIStackView()
    private let emptyRecentLabel = UILabel()

    private let startButton = UIButton(type: .system)

    private static let durationOptions: [Double] = [15, 30, 60]

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Replay Benchmark"
        navigationItem.largeTitleDisplayMode = .always
        navigationController?.navigationBar.prefersLargeTitles = true

        setupHierarchy()
        configureContent()
        renderRecent()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        view.isHidden = false
        renderRecent()
    }

    private func setupHierarchy() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        startButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(startButton)

        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: safe.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: startButton.topAnchor, constant: -12),

            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 8),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -8),
            stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -32),

            startButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            startButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            startButton.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -16),
            startButton.heightAnchor.constraint(equalToConstant: 54)
        ])
    }

    private func configureContent() {
        titleLabel.text = "Measure UI frame rate with and without Sentry session replay."
        titleLabel.font = .systemFont(ofSize: 17, weight: .regular)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 0

        descLabel.text = "A representative scrolling workload runs in the background while frame intervals are sampled with CADisplayLink. After each benchmark, review the avg FPS, slow-frame percentage, percentile frame times, and the per-frame graph. Toggle session replay between runs to compare configurations."
        descLabel.font = .systemFont(ofSize: 13, weight: .regular)
        descLabel.textColor = .secondaryLabel
        descLabel.numberOfLines = 0

        configureOptionsCard()
        configureRecentSection()

        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(descLabel)
        stack.setCustomSpacing(20, after: descLabel)
        stack.addArrangedSubview(optionsCard)
        stack.setCustomSpacing(28, after: optionsCard)
        stack.addArrangedSubview(recentHeaderRow)
        stack.addArrangedSubview(recentStack)
        stack.addArrangedSubview(emptyRecentLabel)

        var config = UIButton.Configuration.filled()
        config.cornerStyle = .large
        config.baseBackgroundColor = .systemBlue
        config.attributedTitle = AttributedString(
            "Start Benchmark",
            attributes: AttributeContainer([.font: UIFont.systemFont(ofSize: 18, weight: .semibold)])
        )
        startButton.configuration = config
        startButton.addTarget(self, action: #selector(startTapped), for: .touchUpInside)
    }

    private func configureOptionsCard() {
        optionsCard.backgroundColor = .secondarySystemBackground
        optionsCard.layer.cornerRadius = 14
        optionsCard.translatesAutoresizingMaskIntoConstraints = false

        replayLabel.text = "Sentry session replay"
        replayLabel.font = .systemFont(ofSize: 16, weight: .medium)
        replayLabel.textColor = .label
        replayLabel.translatesAutoresizingMaskIntoConstraints = false

        replaySwitch.translatesAutoresizingMaskIntoConstraints = false

        durationLabel.text = "Benchmark duration"
        durationLabel.font = .systemFont(ofSize: 16, weight: .medium)
        durationLabel.textColor = .label
        durationLabel.translatesAutoresizingMaskIntoConstraints = false

        durationControl.selectedSegmentIndex = 1
        durationControl.translatesAutoresizingMaskIntoConstraints = false

        for v in [replayLabel, replaySwitch, durationLabel, durationControl] {
            optionsCard.addSubview(v)
        }

        NSLayoutConstraint.activate([
            replayLabel.topAnchor.constraint(equalTo: optionsCard.topAnchor, constant: 16),
            replayLabel.leadingAnchor.constraint(equalTo: optionsCard.leadingAnchor, constant: 16),

            replaySwitch.centerYAnchor.constraint(equalTo: replayLabel.centerYAnchor),
            replaySwitch.trailingAnchor.constraint(equalTo: optionsCard.trailingAnchor, constant: -16),

            durationLabel.topAnchor.constraint(equalTo: replayLabel.bottomAnchor, constant: 18),
            durationLabel.leadingAnchor.constraint(equalTo: optionsCard.leadingAnchor, constant: 16),
            durationLabel.trailingAnchor.constraint(equalTo: optionsCard.trailingAnchor, constant: -16),

            durationControl.topAnchor.constraint(equalTo: durationLabel.bottomAnchor, constant: 8),
            durationControl.leadingAnchor.constraint(equalTo: optionsCard.leadingAnchor, constant: 16),
            durationControl.trailingAnchor.constraint(equalTo: optionsCard.trailingAnchor, constant: -16),
            durationControl.bottomAnchor.constraint(equalTo: optionsCard.bottomAnchor, constant: -16)
        ])
    }

    private func configureRecentSection() {
        recentTitleLabel.text = "Recent runs"
        recentTitleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        recentTitleLabel.textColor = .secondaryLabel

        var clearConfig = UIButton.Configuration.plain()
        clearConfig.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
        clearConfig.attributedTitle = AttributedString(
            "Clear",
            attributes: AttributeContainer([.font: UIFont.systemFont(ofSize: 13, weight: .medium)])
        )
        clearButton.configuration = clearConfig
        clearButton.tintColor = .systemRed
        clearButton.addTarget(self, action: #selector(clearTapped), for: .touchUpInside)

        recentHeaderRow.axis = .horizontal
        recentHeaderRow.alignment = .center
        recentHeaderRow.addArrangedSubview(recentTitleLabel)
        recentHeaderRow.addArrangedSubview(UIView())
        recentHeaderRow.addArrangedSubview(clearButton)

        recentStack.axis = .vertical
        recentStack.spacing = 8

        emptyRecentLabel.text = "No runs yet."
        emptyRecentLabel.font = .systemFont(ofSize: 13, weight: .regular)
        emptyRecentLabel.textColor = .tertiaryLabel
    }

    private func renderRecent() {
        recentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let results = ResultsStore.shared.results
        emptyRecentLabel.isHidden = !results.isEmpty
        clearButton.isHidden = results.isEmpty
        for result in results.prefix(8) {
            recentStack.addArrangedSubview(makeRecentRow(result: result))
        }
    }

    @objc private func clearTapped() {
        let alert = UIAlertController(
            title: "Clear all runs?",
            message: "This will remove all benchmark results from this device.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Clear", style: .destructive) { [weak self] _ in
            ResultsStore.shared.clear()
            self?.renderRecent()
        })
        present(alert, animated: true)
    }

    private func makeRecentRow(result: BenchmarkResult) -> UIView {
        let row = RecentRunRow(result: result)
        row.addAction(UIAction { [weak self] _ in
            let vc = ResultsViewController(stats: result.stats, intervalsMs: result.intervalsMs)
            self?.navigationController?.pushViewController(vc, animated: true)
        }, for: .touchUpInside)
        return row
    }

    @objc private func startTapped() {
        let config = BenchmarkConfig(
            durationSec: Self.durationOptions[durationControl.selectedSegmentIndex],
            replayEnabled: replaySwitch.isOn
        )
        view.isHidden = true
        let runner = RunningBenchmarkViewController(config: config)
        navigationController?.pushViewController(runner, animated: false)
    }
}

private final class RecentRunRow: UIControl {
    private let badge = UILabel()
    private let timestamp = UILabel()
    private let primaryMetric = UILabel()
    private let secondaryMetric = UILabel()
    private let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
    private let graph = FrameRateGraphView(compact: true)

    private static let formatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    init(result: BenchmarkResult) {
        super.init(frame: .zero)
        backgroundColor = .secondarySystemBackground
        layer.cornerRadius = 12

        let stats = result.stats

        badge.text = stats.replayWasOn ? " REPLAY ON " : " REPLAY OFF "
        badge.font = .systemFont(ofSize: 10, weight: .heavy)
        badge.textColor = .white
        badge.backgroundColor = stats.replayWasOn ? .systemRed : .systemGreen
        badge.textAlignment = .center
        badge.layer.cornerRadius = 4
        badge.layer.masksToBounds = true
        badge.translatesAutoresizingMaskIntoConstraints = false

        timestamp.text = Self.formatter.localizedString(for: stats.timestamp, relativeTo: Date())
        timestamp.font = .systemFont(ofSize: 11, weight: .regular)
        timestamp.textColor = .tertiaryLabel
        timestamp.translatesAutoresizingMaskIntoConstraints = false

        primaryMetric.text = String(format: "%.1f fps  ·  %.1f%% slow", stats.avgFps, stats.slowFramePercent)
        primaryMetric.font = .monospacedDigitSystemFont(ofSize: 14, weight: .semibold)
        primaryMetric.textColor = .label
        primaryMetric.translatesAutoresizingMaskIntoConstraints = false

        secondaryMetric.text = String(
            format: "p99 %.1fms  ·  %d frozen  ·  %.0fs",
            stats.p99ms, stats.frozenFrameCount, stats.durationSec
        )
        secondaryMetric.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        secondaryMetric.textColor = .secondaryLabel
        secondaryMetric.translatesAutoresizingMaskIntoConstraints = false

        chevron.tintColor = .tertiaryLabel
        chevron.contentMode = .scaleAspectFit
        chevron.translatesAutoresizingMaskIntoConstraints = false

        graph.setData(intervalsMs: result.intervalsMs, durationSec: stats.durationSec)
        graph.translatesAutoresizingMaskIntoConstraints = false
        graph.isUserInteractionEnabled = false

        addSubview(badge)
        addSubview(timestamp)
        addSubview(primaryMetric)
        addSubview(secondaryMetric)
        addSubview(chevron)
        addSubview(graph)

        NSLayoutConstraint.activate([
            badge.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            badge.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            badge.heightAnchor.constraint(equalToConstant: 18),

            timestamp.centerYAnchor.constraint(equalTo: badge.centerYAnchor),
            timestamp.leadingAnchor.constraint(equalTo: badge.trailingAnchor, constant: 8),

            chevron.centerYAnchor.constraint(equalTo: badge.centerYAnchor),
            chevron.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            chevron.widthAnchor.constraint(equalToConstant: 10),
            chevron.heightAnchor.constraint(equalToConstant: 14),

            primaryMetric.topAnchor.constraint(equalTo: badge.bottomAnchor, constant: 8),
            primaryMetric.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            primaryMetric.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),

            secondaryMetric.topAnchor.constraint(equalTo: primaryMetric.bottomAnchor, constant: 2),
            secondaryMetric.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            secondaryMetric.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),

            graph.topAnchor.constraint(equalTo: secondaryMetric.bottomAnchor, constant: 8),
            graph.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            graph.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            graph.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            graph.heightAnchor.constraint(equalToConstant: 56)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.12) {
                self.alpha = self.isHighlighted ? 0.6 : 1.0
            }
        }
    }
}
