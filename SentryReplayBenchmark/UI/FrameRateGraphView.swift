import QuartzCore
import UIKit

/// Plots frame interval (ms) over time as a polyline. Renders via `CAShapeLayer`
/// so updates are cheap and the graph composites smoothly. Includes reference
/// lines for the slow-frame threshold (16.67ms = 60fps target) and a soft cap so
/// frozen-frame outliers don't dominate the Y-axis.
final class FrameRateGraphView: UIView {
    private let lineLayer = CAShapeLayer()
    private let fillLayer = CAShapeLayer()
    private let slowLineLayer = CAShapeLayer()
    private let gridLayer = CAShapeLayer()
    private let titleLabel = UILabel()
    private let yMaxLabel = UILabel()
    private let yMinLabel = UILabel()
    private let xStartLabel = UILabel()
    private let xEndLabel = UILabel()
    private let slowLabel = UILabel()

    private static let yMaxMs: CGFloat = 50
    private let plotInsets: UIEdgeInsets
    private let isCompact: Bool

    private var intervalsMs: [Double] = []
    private var benchmarkDurationSec: Double = 0

    init(compact: Bool = false) {
        self.isCompact = compact
        self.plotInsets = compact
            ? UIEdgeInsets(top: 6, left: 6, bottom: 6, right: 6)
            : UIEdgeInsets(top: 36, left: 44, bottom: 24, right: 12)
        super.init(frame: .zero)
        backgroundColor = compact ? .clear : .secondarySystemBackground
        layer.cornerRadius = compact ? 0 : 14
        layer.masksToBounds = true

        gridLayer.strokeColor = UIColor.separator.cgColor
        gridLayer.lineWidth = 0.5
        gridLayer.fillColor = nil
        layer.addSublayer(gridLayer)

        slowLineLayer.strokeColor = UIColor.systemOrange.withAlphaComponent(0.6).cgColor
        slowLineLayer.lineWidth = 1
        slowLineLayer.lineDashPattern = [3, 3]
        slowLineLayer.fillColor = nil
        layer.addSublayer(slowLineLayer)

        fillLayer.fillColor = UIColor.systemBlue.withAlphaComponent(0.18).cgColor
        fillLayer.strokeColor = nil
        layer.addSublayer(fillLayer)

        lineLayer.strokeColor = UIColor.systemBlue.cgColor
        lineLayer.lineWidth = 1.25
        lineLayer.fillColor = nil
        lineLayer.lineJoin = .round
        layer.addSublayer(lineLayer)

        if !compact {
            titleLabel.text = "Frame interval (ms) over time"
            titleLabel.font = .systemFont(ofSize: 12, weight: .semibold)
            titleLabel.textColor = .secondaryLabel
            addSubview(titleLabel)

            for label in [yMaxLabel, yMinLabel, xStartLabel, xEndLabel, slowLabel] {
                label.font = .monospacedDigitSystemFont(ofSize: 10, weight: .regular)
                label.textColor = .tertiaryLabel
                addSubview(label)
            }
            yMaxLabel.text = "\(Int(Self.yMaxMs))ms"
            yMinLabel.text = "0"
            slowLabel.text = "16.7ms"
            slowLabel.textColor = .systemOrange
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    func setData(intervalsMs: [Double], durationSec: Double) {
        self.intervalsMs = intervalsMs
        self.benchmarkDurationSec = durationSec
        if !isCompact {
            xStartLabel.text = "0s"
            xEndLabel.text = String(format: "%.0fs", durationSec)
        }
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let plotRect = bounds.inset(by: plotInsets)
        guard plotRect.width > 0, plotRect.height > 0 else { return }

        if !isCompact {
            titleLabel.frame = CGRect(x: 12, y: 8, width: bounds.width - 24, height: 18)
            yMaxLabel.sizeToFit()
            yMaxLabel.frame.origin = CGPoint(x: 8, y: plotRect.minY - 6)
            yMinLabel.sizeToFit()
            yMinLabel.frame.origin = CGPoint(x: 8, y: plotRect.maxY - 10)
            xStartLabel.sizeToFit()
            xStartLabel.frame.origin = CGPoint(x: plotRect.minX, y: plotRect.maxY + 4)
            xEndLabel.sizeToFit()
            xEndLabel.frame.origin = CGPoint(x: plotRect.maxX - xEndLabel.bounds.width, y: plotRect.maxY + 4)
        }

        // Grid: horizontal lines at 0, 16.67ms (slow), and 33.33ms.
        let gridPath = UIBezierPath()
        for ms: CGFloat in [0, Self.yMaxMs * 0.5, Self.yMaxMs] {
            let y = yPosition(forMs: ms, in: plotRect)
            gridPath.move(to: CGPoint(x: plotRect.minX, y: y))
            gridPath.addLine(to: CGPoint(x: plotRect.maxX, y: y))
        }
        gridLayer.path = gridPath.cgPath

        // Slow-frame threshold dashed line.
        let slowY = yPosition(forMs: 16.67, in: plotRect)
        let slowPath = UIBezierPath()
        slowPath.move(to: CGPoint(x: plotRect.minX, y: slowY))
        slowPath.addLine(to: CGPoint(x: plotRect.maxX, y: slowY))
        slowLineLayer.path = slowPath.cgPath
        if !isCompact {
            slowLabel.sizeToFit()
            slowLabel.frame.origin = CGPoint(x: plotRect.maxX - slowLabel.bounds.width - 2, y: slowY - 12)
        }

        // Polyline of intervals. Downsample to ~plotRect.width data points if denser.
        guard intervalsMs.count > 1 else {
            lineLayer.path = nil
            fillLayer.path = nil
            return
        }
        let targetSamples = min(intervalsMs.count, Int(plotRect.width))
        let step = max(1, intervalsMs.count / max(1, targetSamples))

        let line = UIBezierPath()
        let fill = UIBezierPath()
        var first = true
        var lastPoint: CGPoint = .zero
        var i = 0
        while i < intervalsMs.count {
            let ms = intervalsMs[i]
            let x = plotRect.minX + plotRect.width * CGFloat(i) / CGFloat(intervalsMs.count - 1)
            let y = yPosition(forMs: CGFloat(ms), in: plotRect)
            let point = CGPoint(x: x, y: y)
            if first {
                line.move(to: point)
                fill.move(to: CGPoint(x: x, y: plotRect.maxY))
                fill.addLine(to: point)
                first = false
            } else {
                line.addLine(to: point)
                fill.addLine(to: point)
            }
            lastPoint = point
            i += step
        }
        fill.addLine(to: CGPoint(x: lastPoint.x, y: plotRect.maxY))
        fill.close()
        lineLayer.path = line.cgPath
        fillLayer.path = fill.cgPath
    }

    private func yPosition(forMs ms: CGFloat, in plotRect: CGRect) -> CGFloat {
        let clamped = min(max(ms, 0), Self.yMaxMs)
        let normalized = clamped / Self.yMaxMs
        return plotRect.maxY - plotRect.height * normalized
    }
}
