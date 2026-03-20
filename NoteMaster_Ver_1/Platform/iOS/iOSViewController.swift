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
    private var fretboardHeightConstraint: NSLayoutConstraint?

    private lazy var fretboardView: iOSFretboardView = {
        let fretboardView = iOSFretboardView(configuration: displayState.configuration)
        fretboardView.onRawEvent = { hitResult in
            print(hitResult.debugSummary(platform: "iOS"))
        }
        return fretboardView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        configureFretboardView()
        applyDisplayState()
    }

    private func configureFretboardView() {
        fretboardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(fretboardView)

        let safeArea = view.safeAreaLayoutGuide
        let heightConstraint = fretboardView.heightAnchor.constraint(
            equalToConstant: displayState.configuration.preferredHeight
        )
        fretboardHeightConstraint = heightConstraint

        NSLayoutConstraint.activate([
            fretboardView.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor),
            fretboardView.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor),
            fretboardView.centerYAnchor.constraint(equalTo: safeArea.centerYAnchor),
            heightConstraint
        ])
    }

    private func applyDisplayState() {
        fretboardView.configuration = displayState.configuration
        fretboardView.contentProvider = displayState.contentProvider
        fretboardHeightConstraint?.constant = displayState.configuration.preferredHeight
    }
}
#endif
