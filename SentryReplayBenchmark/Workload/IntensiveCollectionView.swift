import QuartzCore
import UIKit

final class IntensiveCollectionView: UIView {
    private let collectionView: UICollectionView
    private let layout = UICollectionViewFlowLayout()
    private let dataSource = WorkloadDataSource()
    private var displayLink: CADisplayLink?

    fileprivate static let cellCount = 5_000
    private static let scrollPointsPerSecond: CGFloat = 200

    override init(frame: CGRect) {
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 8
        layout.itemSize = CGSize(width: 1, height: 1)
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(frame: frame)
        // Cells don't depend on safe area; opting out short-circuits the
        // `_updateSafeAreaInsets` cascade that ran every time cells moved.
        insetsLayoutMarginsFromSafeArea = false
        collectionView.backgroundColor = .systemBackground
        collectionView.dataSource = dataSource
        collectionView.delegate = dataSource
        collectionView.alwaysBounceVertical = true
        collectionView.showsVerticalScrollIndicator = false
        collectionView.contentInsetAdjustmentBehavior = .never
        collectionView.insetsLayoutMarginsFromSafeArea = false
        collectionView.isPrefetchingEnabled = true
        collectionView.register(WorkloadCell.self, forCellWithReuseIdentifier: WorkloadCell.reuseId)
        addSubview(collectionView)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        collectionView.frame = bounds
        let width = bounds.width - 16
        layout.itemSize = CGSize(width: width, height: 220)
        layout.sectionInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
    }

    func startScrolling() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(advance(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 120, preferred: 0)
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stopScrolling() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func advance(_ link: CADisplayLink) {
        let dt = link.targetTimestamp - link.timestamp
        var offset = collectionView.contentOffset
        offset.y += Self.scrollPointsPerSecond * CGFloat(dt)
        let maxY = max(0, collectionView.contentSize.height - collectionView.bounds.height)
        if offset.y >= maxY, maxY > 0 {
            offset.y = 0
        }
        collectionView.contentOffset = offset
    }
}

// MARK: - Data source

private final class WorkloadDataSource: NSObject, UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        IntensiveCollectionView.cellCount
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: WorkloadCell.reuseId, for: indexPath) as! WorkloadCell
        cell.configure(index: indexPath.item)
        return cell
    }
}

// MARK: - Cell

private final class WorkloadCell: UICollectionViewCell {
    static let reuseId = "WorkloadCell"

    private let gradient = CAGradientLayer()
    private let shape = CAShapeLayer()
    private let title = UILabel()
    private let subtitle = UILabel()
    private let body = UILabel()
    private let metric1 = UILabel()
    private let metric2 = UILabel()
    private let badge = UILabel()
    private let footnote = UILabel()
    private let spinner = UIView()
    private var dots: [UIView] = []
    private var bars: [UIView] = []
    private var pills: [UILabel] = []

    private static var shapePathCache: [Int: CGPath] = [:]
    private static var shadowPathCache: [Int: CGPath] = [:]
    private static var waveFramesCache: [Int: [CGPath]] = [:]
    private static let waveFrameCount = 24

    /// Width the cell was last laid out at. layoutSubviews short-circuits on repeat
    /// reuse so cell dequeue does no layout work — only the varying labels and the
    /// gradient colors change in `configure(index:)`.
    private var laidOutWidth: CGFloat = 0

    override init(frame: CGRect) {
        super.init(frame: frame)

        contentView.layer.cornerRadius = 16
        contentView.layer.masksToBounds = false
        contentView.layer.shadowColor = UIColor.black.cgColor
        contentView.layer.shadowOpacity = 0.18
        contentView.layer.shadowOffset = CGSize(width: 0, height: 4)
        contentView.layer.shadowRadius = 12

        gradient.cornerRadius = 16
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        contentView.layer.insertSublayer(gradient, at: 0)

        shape.lineWidth = 2
        shape.fillColor = UIColor.white.withAlphaComponent(0.15).cgColor
        shape.strokeColor = UIColor.white.withAlphaComponent(0.55).cgColor
        contentView.layer.addSublayer(shape)

        for (label, font) in [
            (title, UIFont.systemFont(ofSize: 22, weight: .bold)),
            (subtitle, UIFont.systemFont(ofSize: 15, weight: .medium)),
            (body, UIFont.systemFont(ofSize: 13, weight: .regular)),
            (metric1, UIFont.monospacedDigitSystemFont(ofSize: 14, weight: .semibold)),
            (metric2, UIFont.monospacedDigitSystemFont(ofSize: 14, weight: .semibold)),
            (badge, UIFont.systemFont(ofSize: 11, weight: .heavy)),
            (footnote, UIFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular))
        ] {
            label.font = font
            label.textColor = .white
            label.numberOfLines = 1
            contentView.addSubview(label)
        }
        // Body and footnote are constant strings set once. Setting them per cell
        // would cost a text-shaping pass on every cell entry; we want that work to
        // run once per cell instance (i.e. once per recycler slot, not once per row).
        body.text = "Lorem ipsum dolor sit amet consectetur adipiscing"
        footnote.text = "shard=00  rev=00  region=eu-west-1  status=ok"

        // Static decoration views — rendered once on first display, then composited
        // as cached layers during steady-state scrolling. Provides realistic visual
        // density for a representative UI benchmark workload.
        for _ in 0..<14 {
            let dot = UIView()
            dot.layer.cornerRadius = 3
            dot.backgroundColor = UIColor.white.withAlphaComponent(0.6)
            dots.append(dot)
            contentView.addSubview(dot)
        }
        for _ in 0..<8 {
            let bar = UIView()
            bar.layer.cornerRadius = 1.5
            bar.backgroundColor = UIColor.white.withAlphaComponent(0.5)
            bars.append(bar)
            contentView.addSubview(bar)
        }
        for text in ["LIVE", "v2", "OK", "PRD", "EU", "α"] {
            let pill = UILabel()
            pill.font = .systemFont(ofSize: 9, weight: .medium)
            pill.textColor = .white
            pill.backgroundColor = UIColor.black.withAlphaComponent(0.25)
            pill.text = " \(text) "
            pill.textAlignment = .center
            pill.layer.cornerRadius = 6
            pill.layer.masksToBounds = true
            pills.append(pill)
            contentView.addSubview(pill)
        }

        spinner.backgroundColor = UIColor.white.withAlphaComponent(0.85)
        spinner.layer.cornerRadius = 8
        contentView.addSubview(spinner)

        // Spinner doesn't depend on bounds, so attach the rotation animation now.
        // (`didMoveToWindow` is a safety net for reuse paths where UIKit detached
        // the layer in the meantime.)
        addSpinAnimationIfNeeded()

        // Cell content is independent of safe-area; skip propagation.
        insetsLayoutMarginsFromSafeArea = false
        contentView.insetsLayoutMarginsFromSafeArea = false
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        // Cells get pulled off the window into UICollectionView's reuse pool, and
        // CAAnimations are stripped from detached layers. Re-attach when the cell
        // becomes visible again. The guards inside each helper make this idempotent.
        guard window != nil else { return }
        addSpinAnimationIfNeeded()
        addWaveAnimationIfNeeded()
    }

    private func addSpinAnimationIfNeeded() {
        guard spinner.layer.animation(forKey: "spin") == nil else { return }
        let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotation.fromValue = 0
        rotation.toValue = Double.pi * 2
        rotation.duration = 1.5
        rotation.repeatCount = .infinity
        rotation.isRemovedOnCompletion = false
        // Random phase offset prevents all cells from completing their cycle
        // simultaneously (which caused synchronised ~1.5s main-thread spikes).
        rotation.timeOffset = Double.random(in: 0..<rotation.duration)
        spinner.layer.add(rotation, forKey: "spin")
    }

    private func addWaveAnimationIfNeeded() {
        guard shape.animation(forKey: "wave") == nil else { return }
        let bounds = contentView.bounds
        guard bounds.width > 32 else { return }
        let key = Int(bounds.width.rounded())
        let frames = Self.cachedWaveFrames(forKey: key, bounds: bounds)
        let anim = CAKeyframeAnimation(keyPath: "path")
        anim.values = frames
        anim.duration = 2.0
        anim.repeatCount = .infinity
        anim.calculationMode = .linear
        anim.isRemovedOnCompletion = false
        anim.timeOffset = Double.random(in: 0..<anim.duration)
        shape.add(anim, forKey: "wave")
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        let bounds = contentView.bounds
        guard bounds.width > 32 else { return }
        // The cell's bounds are determined by the flow layout's itemSize, which is
        // constant during scrolling. After the first real layout pass we never need
        // to do this work again — even on reuse for a different index. This is the
        // bulk of the "cheap dequeue" win: cell reuse becomes a configure() call
        // and nothing else, not a re-layout of 36+ subviews.
        if bounds.width == laidOutWidth { return }
        laidOutWidth = bounds.width

        // Disable implicit CALayer animations for every property assignment in this
        // pass. shadowPath, shape.path, and gradient.frame are all animatable; for a
        // benchmark workload we want these set instantly rather than crossfading.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }

        gradient.frame = bounds
        let key = Int(bounds.width.rounded())
        contentView.layer.shadowPath = Self.cachedShadowPath(forKey: key, bounds: bounds)
        shape.path = Self.cachedShapePath(forKey: key, bounds: bounds)

        title.frame = CGRect(x: 16, y: 14, width: bounds.width - 116, height: 26)
        subtitle.frame = CGRect(x: 16, y: 42, width: bounds.width - 32, height: 18)
        body.frame = CGRect(x: 16, y: 64, width: bounds.width - 80, height: 18)
        metric1.frame = CGRect(x: 16, y: 102, width: bounds.width / 2 - 24, height: 18)
        metric2.frame = CGRect(x: bounds.width / 2 + 8, y: 102, width: bounds.width / 2 - 24, height: 18)
        spinner.frame = CGRect(x: bounds.width - 56, y: 64, width: 32, height: 32)
        badge.frame = CGRect(x: bounds.width - 96, y: 14, width: 80, height: 18)
        footnote.frame = CGRect(x: 16, y: 196, width: bounds.width - 32, height: 14)

        for (i, dot) in dots.enumerated() {
            dot.frame = CGRect(x: 16 + CGFloat(i) * 14, y: 130, width: 6, height: 6)
        }
        for (i, bar) in bars.enumerated() {
            bar.frame = CGRect(x: 16 + CGFloat(i) * 30, y: 148, width: 22, height: 3)
        }
        for (i, pill) in pills.enumerated() {
            pill.frame = CGRect(x: 16 + CGFloat(i) * 50, y: 162, width: 44, height: 16)
        }
    }

    private static func cachedShadowPath(forKey key: Int, bounds: CGRect) -> CGPath {
        if let cached = shadowPathCache[key] { return cached }
        let path = UIBezierPath(roundedRect: bounds, cornerRadius: 16).cgPath
        shadowPathCache[key] = path
        return path
    }

    private static func cachedShapePath(forKey key: Int, bounds: CGRect) -> CGPath {
        if let cached = shapePathCache[key] { return cached }
        let cgPath = wavePath(for: bounds, phase: 0)
        shapePathCache[key] = cgPath
        return cgPath
    }

    /// Pre-computed keyframes of the wave path at evenly-spaced phases. The
    /// `CAKeyframeAnimation` cycles through these on the render server. All paths
    /// share the same point count and topology so CA's interpolator is happy.
    private static func cachedWaveFrames(forKey key: Int, bounds: CGRect) -> [CGPath] {
        if let cached = waveFramesCache[key] { return cached }
        let frames: [CGPath] = (0..<waveFrameCount).map { i in
            let phase = CGFloat(i) / CGFloat(waveFrameCount) * .pi * 2
            return wavePath(for: bounds, phase: phase)
        }
        waveFramesCache[key] = frames
        return frames
    }

    private static func wavePath(for bounds: CGRect, phase: CGFloat) -> CGPath {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 16, y: bounds.height - 24))
        for x in stride(from: CGFloat(16), through: bounds.width - 16, by: 12) {
            let y = bounds.height - 24 - (sin(x * 0.05 + phase) + 1) * 22
            path.addLine(to: CGPoint(x: x, y: y))
        }
        path.addLine(to: CGPoint(x: bounds.width - 16, y: bounds.height - 16))
        path.addLine(to: CGPoint(x: 16, y: bounds.height - 16))
        path.close()
        return path.cgPath
    }

    /// Pool size for pre-formatted strings. Each cell instance picks from this pool
    /// by `index % poolSize`. The strings are computed once at type-init time so
    /// `configure(index:)` does no `String(format:)` allocations and no `CFStringAppendFormatCore`
    /// work on the hot path. UIKit's text-typesetting cache also warms quickly because
    /// the same handful of strings repeat across cells.
    private static let poolSize = 50

    private static let titles: [String] = (0..<poolSize).map { "Item #\($0 * 73)" }
    private static let subtitles: [String] = (0..<poolSize).map { "Lorem ipsum subtitle for row \($0)" }
    private static let metric1s: [String] = (0..<poolSize).map { String(format: "Δ %05.2f", Double($0 % 137) * 0.31) }
    private static let metric2s: [String] = (0..<poolSize).map { String(format: "ψ %05.2f", Double(($0 * 7) % 211) * 0.27) }
    private static let badges: [String] = (0..<poolSize).map { String(format: " #%04d ", $0 % 9999) }

    private static let palettes: [[CGColor]] = [
        [UIColor.systemPurple.cgColor, UIColor.systemPink.cgColor],
        [UIColor.systemBlue.cgColor, UIColor.systemTeal.cgColor],
        [UIColor.systemOrange.cgColor, UIColor.systemRed.cgColor],
        [UIColor.systemIndigo.cgColor, UIColor.systemPurple.cgColor],
        [UIColor.systemGreen.cgColor, UIColor.systemTeal.cgColor]
    ]

    func configure(index: Int) {
        // gradient.colors is animatable — without disabling actions, every cell entry
        // would queue a 0.25s color crossfade animation (and the compositor would pay
        // for the ongoing animation on every frame in flight).
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }

        let i = index % Self.poolSize
        gradient.colors = Self.palettes[index % Self.palettes.count]
        title.text = Self.titles[i]
        subtitle.text = Self.subtitles[i]
        metric1.text = Self.metric1s[i]
        metric2.text = Self.metric2s[i]
        badge.text = Self.badges[i]
        // body and footnote are set once in init and never re-shaped.
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        // Intentionally NOT calling setNeedsLayout — the cell's bounds and frame
        // assignments are still valid for the next reuse. Calling it forced a full
        // layoutSubviews on every dequeue, which was the dominant ~1Hz hitch source.
        //
        // CAAnimations get stripped when UIKit detaches the cell during reuse (the
        // layer is removed from its superlayer, which strips animations). Re-attach
        // them here — `prepareForReuse` is guaranteed to fire on every reuse cycle,
        // unlike `didMoveToWindow` which depends on whether the cell actually leaves
        // the window. The helpers are idempotent via their `animation(forKey:) == nil`
        // guards, so this is a no-op when animations were never stripped.
        addSpinAnimationIfNeeded()
        addWaveAnimationIfNeeded()
    }
}

// MARK: - Lorem

private enum LoremIpsum {
    private static let words: [String] = [
        "Lorem", "ipsum", "dolor", "sit", "amet", "consectetur", "adipiscing", "elit",
        "sed", "do", "eiusmod", "tempor", "incididunt", "ut", "labore", "et", "dolore",
        "magna", "aliqua", "enim", "ad", "minim", "veniam", "quis", "nostrud",
        "exercitation", "ullamco", "laboris", "nisi", "aliquip", "commodo", "consequat"
    ]

    static func body(seed: Int) -> String {
        var rng = SplitMix64(seed: UInt64(bitPattern: Int64(seed)))
        var out: [String] = []
        for _ in 0..<8 {
            out.append(words[Int(rng.next() % UInt64(words.count))])
        }
        return out.joined(separator: " ")
    }
}

private struct SplitMix64 {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed &+ 0x9E37_79B9_7F4A_7C15 }
    mutating func next() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
