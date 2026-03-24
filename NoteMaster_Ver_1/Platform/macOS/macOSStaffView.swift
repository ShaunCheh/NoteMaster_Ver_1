//
//  macOSStaffView.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/24.
//

#if os(macOS)
import AppKit

final class macOSStaffView: NSView {
    var configuration: StaffConfiguration {
        didSet {
            guard oldValue != configuration else {
                return
            }

            applyState()
        }
    }

    var sceneProvider: StaffSceneProvider {
        didSet {
            guard oldValue != sceneProvider else {
                return
            }

            applyState()
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
        sceneProvider = .init()
        super.init(frame: frameRect)
        configureView()
    }

    convenience init(
        configuration: StaffConfiguration,
        sceneProvider: StaffSceneProvider
    ) {
        self.init(frame: .zero)
        self.configuration = configuration
        self.sceneProvider = sceneProvider
        applyState()
    }

    required init?(coder: NSCoder) {
        configuration = .init()
        sceneProvider = .init()
        super.init(coder: coder)
        configureView()
    }

    override func makeBackingLayer() -> CALayer {
        StaffRootLayer()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateContentsScale()
        refreshPresentationForResize(displayImmediately: false)
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        refreshPresentationForResize(displayImmediately: inLiveResize)
    }

    override func viewWillStartLiveResize() {
        super.viewWillStartLiveResize()
        refreshPresentationForResize(displayImmediately: true)
    }

    override func viewDidEndLiveResize() {
        super.viewDidEndLiveResize()
        refreshPresentationForResize(displayImmediately: true)
    }

    private var staffRootLayer: StaffRootLayer {
        guard let staffRootLayer = layer as? StaffRootLayer else {
            fatalError("Expected StaffRootLayer backing layer.")
        }

        return staffRootLayer
    }

    private func configureView() {
        wantsLayer = true
        layerContentsRedrawPolicy = .duringViewResize
        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .vertical)
        applyState()
    }

    private func applyState() {
        var resolvedConfiguration = configuration
        resolvedConfiguration.canvasOrientation = .standard

        staffRootLayer.configuration = resolvedConfiguration
        staffRootLayer.sceneProvider = sceneProvider
        staffRootLayer.contextNormalizationMode = .flipYToTopLeft
        staffRootLayer.resourceBundle = .main
        updateContentsScale()
        refreshPresentationForResize(displayImmediately: false)
        invalidateIntrinsicContentSize()
    }

    private func updateContentsScale() {
        staffRootLayer.contentsScale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
    }

    private func refreshPresentationForResize(displayImmediately: Bool) {
        guard let staffRootLayer = layer as? StaffRootLayer else {
            return
        }

        staffRootLayer.refreshForCurrentBounds(displayImmediately: displayImmediately)
    }
}
#endif
