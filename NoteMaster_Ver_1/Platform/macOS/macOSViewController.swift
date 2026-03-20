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
    private var fretboardHeightConstraint: NSLayoutConstraint?

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
        configureFretboardView()
        applyDisplayState()
    }

    private func configureFretboardView() {
        fretboardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(fretboardView)

        let heightConstraint = fretboardView.heightAnchor.constraint(
            equalToConstant: displayState.configuration.preferredHeight
        )
        fretboardHeightConstraint = heightConstraint

        NSLayoutConstraint.activate([
            fretboardView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            fretboardView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            fretboardView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
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
