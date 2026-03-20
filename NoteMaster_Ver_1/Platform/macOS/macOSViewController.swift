//
//  macOSViewController.swift
//  NoteMaster_Ver_1
//
//  Created by Shaun on 2026/3/19.
//

#if os(macOS)
import Foundation
import AppKit

final class macOSViewController: NSViewController {
    private var displayState = FretboardDisplayState.default {
        didSet {
            guard isViewLoaded else {
                return
            }

            applyDisplayState()
        }
    }

    private lazy var buttonPanelView: macOSButtonPanelView = {
        let buttonPanelView = macOSButtonPanelView(
            model: ButtonPanelSnapshotBuilder.makeModel(from: displayState)
        )
        buttonPanelView.onAction = { [weak self] actionID in
            self?.handleButtonAction(actionID)
        }
        return buttonPanelView
    }()

    private lazy var fretboardView: macOSFretboardView = {
        let fretboardView = macOSFretboardView(configuration: displayState.configuration)
        fretboardView.onRawEvent = { hitResult in
            print(hitResult.debugSummary(platform: "macOS"))
        }
        return fretboardView
    }()

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        configureLayout()
        applyDisplayState()
    }

    private func configureLayout() {
        buttonPanelView.translatesAutoresizingMaskIntoConstraints = false
        fretboardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(buttonPanelView)
        view.addSubview(fretboardView)

        let safeArea = view.safeAreaLayoutGuide

        NSLayoutConstraint.activate([
            buttonPanelView.leadingAnchor.constraint(
                equalTo: safeArea.leadingAnchor,
                constant: Layout.horizontalInset
            ),
            buttonPanelView.trailingAnchor.constraint(
                equalTo: safeArea.trailingAnchor,
                constant: -Layout.horizontalInset
            ),
            buttonPanelView.topAnchor.constraint(
                equalTo: safeArea.topAnchor,
                constant: Layout.topInset
            ),
            fretboardView.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor),
            fretboardView.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor),
            fretboardView.topAnchor.constraint(
                equalTo: buttonPanelView.bottomAnchor,
                constant: Layout.verticalSpacing
            ),
            fretboardView.bottomAnchor.constraint(
                lessThanOrEqualTo: safeArea.bottomAnchor,
                constant: -Layout.bottomInset
            )
        ])
    }

    private func applyDisplayState() {
        buttonPanelView.model = ButtonPanelSnapshotBuilder.makeModel(from: displayState)
        fretboardView.configuration = displayState.configuration
        fretboardView.contentProvider = displayState.contentProvider
        view.needsLayout = true
        view.layoutSubtreeIfNeeded()
    }

    private func handleButtonAction(_ actionID: ButtonPanelActionID) {
        var nextDisplayState = displayState
        nextDisplayState.apply(actionID)

        guard nextDisplayState != displayState else {
            return
        }

        displayState = nextDisplayState
    }
}

private enum Layout {
    static let horizontalInset: CGFloat = 16
    static let topInset: CGFloat = 16
    static let verticalSpacing: CGFloat = 20
    static let bottomInset: CGFloat = 16
}

#endif
