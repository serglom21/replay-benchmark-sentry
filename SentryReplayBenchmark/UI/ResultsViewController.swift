import UIKit

final class ResultsViewController: UIViewController {
    private let stats: FrameStats
    private let intervalsMs: [Double]

    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private let badge = UILabel()
    private let durationLabel = UILabel()
    private let summaryGrid = UIStackView()
    private let graph = FrameRateGraphView()
    private let runAgainButton = UIButton(type: .system)
    private let doneButton = UIButton(type: .system)

    init(stats: FrameStats, intervalsMs: [Double]) {
        self.stats = stats
        self.intervalsMs = intervalsMs
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Results"
        navigationItem.largeTitleDisplayMode = .always
        navigationItem.hidesBackButton = true

        setupHierarchy()
        renderContent()
    }

    private func setupHierarchy() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        stack.axis = .vertical
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        let buttonRow = UIStackView(arrangedSubviews: [doneButton, runAgainButton])
        buttonRow.axis = .horizontal
        buttonRow.spacing = 12
        buttonRow.distribution = .fillEqually
        buttonRow.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(buttonRow)

        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: safe.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: buttonRow.topAnchor, constant: -12),

            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 8),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -8),
            stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -32),

            buttonRow.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            buttonRow.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            buttonRow.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -16),
            buttonRow.heightAnchor.constraint(equalToConstant: 50)
        ])

        graph.translatesAutoresizingMaskIntoConstraints = false
        graph.heightAnchor.constraint(equalToConstant: 220).isActive = true
    }

    private func renderContent() {
        badge.text = stats.replayWasOn ? "  REPLAY ON  " : "  REPLAY OFF  "
        badge.font = .systemFont(ofSize: 12, weight: .heavy)
        badge.textColor = .white
        badge.backgroundColor = stats.replayWasOn ? .systemRed : .systemGreen
        badge.textAlignment = .center
        badge.layer.cornerRadius = 6
        badge.layer.masksToBounds = true
        badge.setContentHuggingPriority(.required, for: .horizontal)

        let badgeRow = UIStackView(arrangedSubviews: [badge, UIView()])
        badgeRow.axis = .horizontal

        durationLabel.text = String(format: "%.0f-second benchmark · %d frames sampled", stats.durationSec, stats.totalFrames)
        durationLabel.font = .systemFont(ofSize: 13, weight: .regular)
        durationLabel.textColor = .secondaryLabel

        summaryGrid.axis = .vertical
        summaryGrid.spacing = 8
        summaryGrid.addArrangedSubview(makeMetricRow(label: "Average FPS", value: String(format: "%.1f", stats.avgFps)))
        summaryGrid.addArrangedSubview(makeMetricRow(label: "Slow frames", value: String(format: "%.1f%% (%d)", stats.slowFramePercent, stats.slowFrameCount)))
        summaryGrid.addArrangedSubview(makeMetricRow(label: "Frozen frames", value: "\(stats.frozenFrameCount)"))
        summaryGrid.addArrangedSubview(makeMetricRow(label: "p50 / p90 / p99 frame", value: String(format: "%.1f / %.1f / %.1f ms", stats.p50ms, stats.p90ms, stats.p99ms)))
        summaryGrid.addArrangedSubview(makeMetricRow(label: "Max frame", value: String(format: "%.1f ms", stats.maxMs)))

        let summaryCard = UIView()
        summaryCard.backgroundColor = .secondarySystemBackground
        summaryCard.layer.cornerRadius = 14
        summaryGrid.translatesAutoresizingMaskIntoConstraints = false
        summaryCard.addSubview(summaryGrid)
        NSLayoutConstraint.activate([
            summaryGrid.topAnchor.constraint(equalTo: summaryCard.topAnchor, constant: 14),
            summaryGrid.leadingAnchor.constraint(equalTo: summaryCard.leadingAnchor, constant: 16),
            summaryGrid.trailingAnchor.constraint(equalTo: summaryCard.trailingAnchor, constant: -16),
            summaryGrid.bottomAnchor.constraint(equalTo: summaryCard.bottomAnchor, constant: -14)
        ])

        graph.setData(intervalsMs: intervalsMs, durationSec: stats.durationSec)

        stack.addArrangedSubview(badgeRow)
        stack.addArrangedSubview(durationLabel)
        stack.addArrangedSubview(summaryCard)
        stack.addArrangedSubview(graph)

        var doneConfig = UIButton.Configuration.gray()
        doneConfig.cornerStyle = .large
        doneConfig.attributedTitle = AttributedString(
            "Done",
            attributes: AttributeContainer([.font: UIFont.systemFont(ofSize: 16, weight: .semibold)])
        )
        doneButton.configuration = doneConfig
        doneButton.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)

        var againConfig = UIButton.Configuration.filled()
        againConfig.cornerStyle = .large
        againConfig.baseBackgroundColor = .systemBlue
        againConfig.attributedTitle = AttributedString(
            "Run Again",
            attributes: AttributeContainer([.font: UIFont.systemFont(ofSize: 16, weight: .semibold)])
        )
        runAgainButton.configuration = againConfig
        runAgainButton.addTarget(self, action: #selector(runAgainTapped), for: .touchUpInside)
    }

    private func makeMetricRow(label: String, value: String) -> UIView {
        let row = UIStackView()
        row.axis = .horizontal
        let l = UILabel()
        l.text = label
        l.font = .systemFont(ofSize: 14, weight: .regular)
        l.textColor = .secondaryLabel
        let v = UILabel()
        v.text = value
        v.font = .monospacedDigitSystemFont(ofSize: 14, weight: .semibold)
        v.textColor = .label
        v.textAlignment = .right
        row.addArrangedSubview(l)
        row.addArrangedSubview(v)
        return row
    }

    @objc private func doneTapped() {
        navigationController?.popToRootViewController(animated: true)
    }

    @objc private func runAgainTapped() {
        guard let nav = navigationController else { return }
        let setupVC = nav.viewControllers.first
        let runner = RunningBenchmarkViewController(
            config: BenchmarkConfig(durationSec: stats.durationSec, replayEnabled: stats.replayWasOn)
        )
        nav.setViewControllers([setupVC ?? UIViewController(), runner], animated: true)
    }
}
