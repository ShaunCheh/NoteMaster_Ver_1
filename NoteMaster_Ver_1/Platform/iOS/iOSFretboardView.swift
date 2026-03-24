//
//  iOSFretboardView.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/19.
//

#if os(iOS)
import UIKit

final class iOSFretboardView: UIView {
    private var lastMeasuredLayoutWidth: CGFloat?

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

    // 阶段 3 只负责把 raw touch 事件转换成共享命中结果并向外抛出。
    var onRawEvent: ((FretboardHitResult) -> Void)?

    override class var layerClass: AnyClass {
        FretboardLayer.self
    }

    override var intrinsicContentSize: CGSize {
        CGSize(
            width: UIView.noIntrinsicMetric,
            height: resolvedIntrinsicHeight
        )
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
        invalidateIntrinsicSizeForCurrentWidthIfNeeded()
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
        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .vertical)
        applyConfiguration()
    }

    private func applyConfiguration() {
        fretboardLayer.configuration = configuration
        fretboardLayer.contentProvider = contentProvider
        updateContentsScale()
        invalidateIntrinsicContentSize()
    }

    private func updateContentsScale() {
        fretboardLayer.contentsScale = window?.screen.scale ?? UIScreen.main.scale
    }

    private var resolvedIntrinsicHeight: CGFloat {
        guard bounds.width > 0 else {
            return configuration.preferredHeight
        }

        return configuration.resolvedHeight(forAvailableWidth: bounds.width)
    }

    private func invalidateIntrinsicSizeForCurrentWidthIfNeeded() {
        let currentWidth = bounds.width
        guard lastMeasuredLayoutWidth != currentWidth else {
            return
        }

        lastMeasuredLayoutWidth = currentWidth
        invalidateIntrinsicContentSize()
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
