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
    private let fretboardConfiguration = FretboardConfiguration(
        instrument: .guitar6,
        maxFret: 12,
        preferredHeight: 180
    )
    private lazy var fretboardView = iOSFretboardView(configuration: fretboardConfiguration)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        configureFretboardView()
    }

    private func configureFretboardView() {
        fretboardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(fretboardView)

        let safeArea = view.safeAreaLayoutGuide
        let heightConstraint = fretboardView.heightAnchor.constraint(
            equalToConstant: fretboardConfiguration.preferredHeight
        )

        NSLayoutConstraint.activate([
            fretboardView.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor),
            fretboardView.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor),
            fretboardView.centerYAnchor.constraint(equalTo: safeArea.centerYAnchor),
            heightConstraint
        ])
    }
}
#endif
