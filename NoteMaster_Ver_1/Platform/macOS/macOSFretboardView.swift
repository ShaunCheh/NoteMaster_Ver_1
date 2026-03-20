//
//  macOSFretboardView.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/19.
//

#if os(macOS)
import AppKit

final class macOSFretboardView: NSView {
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

    // 阶段 4 只负责把 raw mouse 事件转换成共享命中结果并向外抛出。
    var onRawEvent: ((FretboardHitResult) -> Void)?

    override var intrinsicContentSize: NSSize {
        NSSize(
            width: NSView.noIntrinsicMetric,
            height: configuration.preferredHeight
        )
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
        fretboardLayer.contentsScale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
    }

    private func handleRawMouseEvent(
        _ event: NSEvent,
        phase: FretboardEventPhase
    ) {
        let location = convert(event.locationInWindow, from: nil)
        let geometry = FretboardGeometry(configuration: configuration, bounds: bounds)
        let hitResult = geometry.hitTest(location, phase: phase)
        onRawEvent?(hitResult)
    }
}
#endif
