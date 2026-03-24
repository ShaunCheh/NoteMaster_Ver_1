//
//  iOSStaffView.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/24.
//

#if os(iOS)
import UIKit

final class iOSStaffView: UIView {
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

    override class var layerClass: AnyClass {
        StaffRootLayer.self
    }

    override var intrinsicContentSize: CGSize {
        CGSize(
            width: UIView.noIntrinsicMetric,
            height: configuration.preferredHeight
        )
    }

    override init(frame: CGRect) {
        configuration = .init()
        sceneProvider = .init()
        super.init(frame: frame)
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

    override func didMoveToWindow() {
        super.didMoveToWindow()
        updateContentsScale()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateContentsScale()
    }

    private var staffRootLayer: StaffRootLayer {
        guard let staffRootLayer = layer as? StaffRootLayer else {
            fatalError("Expected StaffRootLayer backing layer.")
        }

        return staffRootLayer
    }

    private func configureView() {
        backgroundColor = .clear
        isOpaque = false
        contentMode = .redraw
        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .vertical)
        applyState()
    }

    private func applyState() {
        var resolvedConfiguration = configuration
        resolvedConfiguration.canvasOrientation = .standard

        staffRootLayer.configuration = resolvedConfiguration
        staffRootLayer.sceneProvider = sceneProvider
        staffRootLayer.contextNormalizationMode = .none
        staffRootLayer.resourceBundle = .main
        updateContentsScale()
        invalidateIntrinsicContentSize()
    }

    private func updateContentsScale() {
        staffRootLayer.contentsScale = window?.screen.scale ?? UIScreen.main.scale
    }
}
#endif
