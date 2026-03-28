//
//  iOSFretboardView.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/19.
//

#if os(iOS)
import UIKit

final class iOSFretboardView: UIView {
    private var lastMeasuredPrimaryDimension: CGFloat?

    var configuration: FretboardConfiguration {
        didSet {
            guard oldValue != configuration else {
                return
            }

            applyConfiguration()
        }
    }

    var contentProvider: (any FretboardContentProviding)? {
        didSet {
            fretboardLayer.contentProvider = contentProvider
        }
    }

    var feedbackOverlayState: FretboardFeedbackOverlayState = .empty {
        didSet {
            guard oldValue != feedbackOverlayState else {
                return
            }

            fretboardLayer.feedbackOverlayState = feedbackOverlayState
        }
    }

    var showsComponentBoundsOverlay = false {
        didSet {
            guard oldValue != showsComponentBoundsOverlay else {
                return
            }

            updateComponentBoundsOverlay()
        }
    }

    // 阶段 3 只负责把 raw touch 事件转换成共享命中结果并向外抛出。
    var onRawEvent: ((FretboardHitResult) -> Void)?

    override class var layerClass: AnyClass {
        FretboardLayer.self
    }

    override var intrinsicContentSize: CGSize {
        switch configuration.displayMode {
        case .horizontal:
            return CGSize(
                width: UIView.noIntrinsicMetric,
                height: resolvedIntrinsicHeight
            )
        case .vertical:
            return CGSize(
                width: verticalContentSize.width,
                height: UIView.noIntrinsicMetric
            )
        }
    }

    // 阶段 2 显式暴露“当前竖向视口高度 -> 内容宽度”的平台出口，供后续局部横向滚动直接消费。
    var verticalContentLayout: FretboardConfiguration.VerticalContentLayout {
        guard configuration.displayMode == .vertical else {
            return .init(
                viewportHeight: 0,
                contentWidth: 0
            )
        }

        return configuration.verticalContentLayout(
            forViewportHeight: resolvedVerticalViewportHeight
        )
    }

    var verticalContentSize: CGSize {
        verticalContentLayout.contentSize
    }

    override init(frame: CGRect) {
        configuration = .init()
        super.init(frame: frame)
        configureView()
    }

    convenience init(configuration: FretboardConfiguration) {
        self.init(frame: .zero)
        self.configuration = configuration
        applyConfiguration()
    }

    required init?(coder: NSCoder) {
        configuration = .init()
        super.init(coder: coder)
        configureView()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        updateContentsScale()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateContentsScale()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        invalidateIntrinsicSizeForCurrentPrimaryDimensionIfNeeded()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        handleRawTouchEvent(from: touches, phase: .began)
        super.touchesBegan(touches, with: event)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        handleRawTouchEvent(from: touches, phase: .moved)
        super.touchesMoved(touches, with: event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        handleRawTouchEvent(from: touches, phase: .ended)
        super.touchesEnded(touches, with: event)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        handleRawTouchEvent(from: touches, phase: .cancelled)
        super.touchesCancelled(touches, with: event)
    }

    private var fretboardLayer: FretboardLayer {
        guard let fretboardLayer = layer as? FretboardLayer else {
            fatalError("Expected FretboardLayer backing layer.")
        }

        return fretboardLayer
    }

    private func configureView() {
        backgroundColor = .clear
        isOpaque = false
        contentMode = .redraw
        applyConfiguration()
    }

    private func applyConfiguration() {
        lastMeasuredPrimaryDimension = nil
        fretboardLayer.configuration = configuration
        fretboardLayer.contentProvider = contentProvider
        fretboardLayer.feedbackOverlayState = feedbackOverlayState
        updateContentsScale()
        updateContentPriorities()
        invalidateIntrinsicContentSize()
    }

    private func updateContentsScale() {
        fretboardLayer.contentsScale = window?.screen.scale ?? UIScreen.main.scale
        updateComponentBoundsOverlay()
    }

    private var resolvedIntrinsicHeight: CGFloat {
        guard bounds.width > 0 else {
            return configuration.preferredHeight
        }

        return configuration.resolvedHeight(forAvailableWidth: bounds.width)
    }

    private var resolvedVerticalViewportHeight: CGFloat {
        guard bounds.height > 0 else {
            return configuration.preferredHeight
        }

        return bounds.height
    }

    private func updateContentPriorities() {
        switch configuration.displayMode {
        case .horizontal:
            setContentHuggingPriority(.defaultLow, for: .horizontal)
            setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            setContentHuggingPriority(.required, for: .vertical)
            setContentCompressionResistancePriority(.required, for: .vertical)
        case .vertical:
            setContentHuggingPriority(.required, for: .horizontal)
            setContentCompressionResistancePriority(.required, for: .horizontal)
            setContentHuggingPriority(.defaultLow, for: .vertical)
            setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        }
    }

    private func invalidateIntrinsicSizeForCurrentPrimaryDimensionIfNeeded() {
        let currentPrimaryDimension: CGFloat
        switch configuration.displayMode {
        case .horizontal:
            currentPrimaryDimension = bounds.width
        case .vertical:
            currentPrimaryDimension = bounds.height
        }

        guard lastMeasuredPrimaryDimension != currentPrimaryDimension else {
            return
        }

        lastMeasuredPrimaryDimension = currentPrimaryDimension
        invalidateIntrinsicContentSize()
    }

    private func updateComponentBoundsOverlay() {
        fretboardLayer.borderColor = UIColor.systemGreen.cgColor
        fretboardLayer.borderWidth = showsComponentBoundsOverlay
            ? resolvedComponentBoundsOverlayLineWidth
            : 0
    }

    private var resolvedComponentBoundsOverlayLineWidth: CGFloat {
        max(1 / max(fretboardLayer.contentsScale, 1), 0.5)
    }

    private func handleRawTouchEvent(
        from touches: Set<UITouch>,
        phase: FretboardEventPhase
    ) {
        guard let touch = touches.first else {
            return
        }

        let location = touch.location(in: self)
        let geometry = FretboardGeometry(configuration: configuration, bounds: bounds)
        let hitResult = geometry.hitTest(location, phase: phase)
        onRawEvent?(hitResult)
    }
}
#endif
