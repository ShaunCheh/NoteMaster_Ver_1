//
//  iOSViewController.swift
//  NoteMaster_Ver_1
//
//  Created by Shaun on 2026/3/19.
//

#if os(iOS)
import Foundation
import UIKit

final class iOSViewController: UIViewController {
    private var displayState = FretboardDisplayState.default {
        didSet {
            guard isViewLoaded else {
                return
            }

            applyDisplayState()
        }
    }

    private let staffDisplayState = StaffDisplayState(
        configuration: StaffConfiguration(
            renderMode: .coreText,
            debugOptions: .init(
                showsClefBounds: true,
                showsClefAnchor: true
            )
        )
    )

    private lazy var buttonPanelView: iOSButtonPanelView = {
        let buttonPanelView = iOSButtonPanelView(
            model: ButtonPanelSnapshotBuilder.makeModel(from: displayState)
        )
        buttonPanelView.onAction = { [weak self] actionID in
            self?.handleButtonAction(actionID)
        }
        return buttonPanelView
    }()

    private lazy var fretboardView: iOSFretboardView = {
        let fretboardView = iOSFretboardView(configuration: displayState.configuration)
        fretboardView.onRawEvent = { hitResult in
            print(hitResult.debugSummary(platform: "iOS"))
        }
        return fretboardView
    }()

    private lazy var staffView: iOSStaffView = {
        iOSStaffView(
            configuration: staffDisplayState.configuration,
            sceneProvider: staffDisplayState.sceneProvider
        )
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        configureLayout()
        applyDisplayState()
    }

    private func configureLayout() {
        buttonPanelView.translatesAutoresizingMaskIntoConstraints = false
        staffView.translatesAutoresizingMaskIntoConstraints = false
        fretboardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(buttonPanelView)
        view.addSubview(staffView)
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
            staffView.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor),
            staffView.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor),
            staffView.topAnchor.constraint(
                equalTo: buttonPanelView.bottomAnchor,
                constant: Layout.verticalSpacing
            ),
            fretboardView.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor),
            fretboardView.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor),
            fretboardView.topAnchor.constraint(
                equalTo: staffView.bottomAnchor,
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
        staffView.configuration = staffDisplayState.configuration
        staffView.sceneProvider = staffDisplayState.sceneProvider
        fretboardView.configuration = displayState.configuration
        fretboardView.contentProvider = displayState.contentProvider
        view.setNeedsLayout()
        view.layoutIfNeeded()
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
