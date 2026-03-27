//
//  macOSFretboardView.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/19.
//

#if os(macOS)
import AppKit

final class macOSFretboardView: NSView {
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

    var showsComponentBoundsOverlay = false {
        didSet {
            guard oldValue != showsComponentBoundsOverlay else {
                return
            }

            updateComponentBoundsOverlay()
        }
    }

    // 阶段 4 只负责把 raw mouse 事件转换成共享命中结果并向外抛出。
    var onRawEvent: ((FretboardHitResult) -> Void)?

    override var intrinsicContentSize: NSSize {
        switch configuration.displayMode {
        case .horizontal:
            return NSSize(
                width: NSView.noIntrinsicMetric,
                height: resolvedIntrinsicHeight
            )
        case .vertical:
            return NSSize(
                width: verticalContentSize.width,
                height: NSView.noIntrinsicMetric
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

    override init(frame frameRect: NSRect) {
        configuration = .init()
        super.init(frame: frameRect)
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

    override func makeBackingLayer() -> CALayer {
        FretboardLayer()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateContentsScale()
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        invalidateIntrinsicSizeForCurrentPrimaryDimensionIfNeeded()
    }

    override func mouseDown(with event: NSEvent) {
        handleRawMouseEvent(event, phase: .began)
    }

    override func mouseDragged(with event: NSEvent) {
        handleRawMouseEvent(event, phase: .moved)
    }

    override func mouseUp(with event: NSEvent) {
        handleRawMouseEvent(event, phase: .ended)
    }

    private var fretboardLayer: FretboardLayer {
        guard let fretboardLayer = layer as? FretboardLayer else {
            fatalError("Expected FretboardLayer backing layer.")
        }

        return fretboardLayer
    }

    private func configureView() {
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        applyConfiguration()
    }

    private func applyConfiguration() {
        lastMeasuredPrimaryDimension = nil
        fretboardLayer.configuration = configuration
        fretboardLayer.contextNormalizationMode = resolvedContextNormalizationMode
        fretboardLayer.contentProvider = contentProvider
        updateContentsScale()
        updateContentPriorities()
        invalidateIntrinsicContentSize()
    }

    private func updateContentsScale() {
        fretboardLayer.contentsScale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
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

    // macOS 默认 view/layer 坐标是 bottom-left；shared vertical scene 使用 top-left 语义。
    private var resolvedContextNormalizationMode: FretboardContextNormalizationMode {
        switch configuration.displayMode {
        case .horizontal:
            return .none
        case .vertical:
            return .flipYToTopLeft
        }
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
        fretboardLayer.borderColor = NSColor.systemGreen.cgColor
        fretboardLayer.borderWidth = showsComponentBoundsOverlay
            ? resolvedComponentBoundsOverlayLineWidth
            : 0
    }

    private var resolvedComponentBoundsOverlayLineWidth: CGFloat {
        max(1 / max(fretboardLayer.contentsScale, 1), 0.5)
    }

    private func handleRawMouseEvent(
        _ event: NSEvent,
        phase: FretboardEventPhase
    ) {
        let location = convert(event.locationInWindow, from: nil)
        let geometryLocation = resolvedContextNormalizationMode.normalizedPoint(
            location,
            in: bounds
        )
        let geometry = FretboardGeometry(configuration: configuration, bounds: bounds)
        let hitResult = geometry.hitTest(geometryLocation, phase: phase)
        onRawEvent?(hitResult)
    }
}
#endif
