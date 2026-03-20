//
//  iOSFretboardView.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/19.
//

#if os(iOS)
import UIKit

final class iOSFretboardView: UIView {
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

    override class var layerClass: AnyClass {
        FretboardLayer.self
    }

    override var intrinsicContentSize: CGSize {
        CGSize(
            width: UIView.noIntrinsicMetric,
            height: configuration.preferredHeight
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
        fretboardLayer.configuration = configuration
        fretboardLayer.contentProvider = contentProvider
        updateContentsScale()
        invalidateIntrinsicContentSize()
    }

    private func updateContentsScale() {
        fretboardLayer.contentsScale = window?.screen.scale ?? UIScreen.main.scale
    }
}
#endif
