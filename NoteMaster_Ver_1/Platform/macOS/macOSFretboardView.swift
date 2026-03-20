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
        fretboardLayer.configuration = configuration
        fretboardLayer.contentProvider = contentProvider
        updateContentsScale()
        invalidateIntrinsicContentSize()
    }

    private func updateContentsScale() {
        fretboardLayer.contentsScale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
    }
}
#endif
