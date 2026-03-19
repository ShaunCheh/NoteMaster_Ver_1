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
    private let helloLabel = NSTextField(labelWithString: "Hello world")

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        configureHelloLabel()
    }

    private func configureHelloLabel() {
        helloLabel.translatesAutoresizingMaskIntoConstraints = false
        helloLabel.font = .systemFont(ofSize: 32, weight: .semibold)
        helloLabel.textColor = .labelColor
        helloLabel.alignment = .center

        view.addSubview(helloLabel)

        NSLayoutConstraint.activate([
            helloLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            helloLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
}

#endif
