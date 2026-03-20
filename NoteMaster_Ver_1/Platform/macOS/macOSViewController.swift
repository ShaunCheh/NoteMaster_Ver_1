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
    private let fretboardConfiguration = FretboardConfiguration(
        tuning: .standard(for: .guitar6),
        maxFret: 12,
        preferredHeight: 180
    )
    private let noteContentProvider = NoteNameContentProvider(
        visibility: .all,
        spelling: .sharp,
        showsOctave: true
    )
    private lazy var fretboardView: macOSFretboardView = {
        let fretboardView = macOSFretboardView(configuration: fretboardConfiguration)
        fretboardView.contentProvider = noteContentProvider
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
    }

    private func configureFretboardView() {
        fretboardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(fretboardView)

        let heightConstraint = fretboardView.heightAnchor.constraint(
            equalToConstant: fretboardConfiguration.preferredHeight
        )

        NSLayoutConstraint.activate([
            fretboardView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            fretboardView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            fretboardView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            heightConstraint
        ])
    }
}

#endif
