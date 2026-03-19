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
    private let helloLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        configureHelloLabel()
    }

    private func configureHelloLabel() {
        helloLabel.translatesAutoresizingMaskIntoConstraints = false
        helloLabel.text = "hello world"
        helloLabel.font = .systemFont(ofSize: 32, weight: .semibold)
        helloLabel.textColor = .label
        helloLabel.textAlignment = .center

        view.addSubview(helloLabel)

        NSLayoutConstraint.activate([
            helloLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            helloLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
}
#endif
