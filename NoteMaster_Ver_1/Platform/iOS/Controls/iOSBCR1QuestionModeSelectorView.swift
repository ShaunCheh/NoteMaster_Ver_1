//
//  iOSBCR1QuestionModeSelectorView.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/9/11.
//

#if os(iOS)
import UIKit

final class iOSBCR1QuestionModeSelectorView: UIView {
    static let accessibilityIdentifier = "bcr1-question-mode-selector"
    static let segmentedControlAccessibilityIdentifier =
        "bcr1-question-mode-segmented-control"

    var onEvent: ((BCR1QuestionModeSelectorEvent) -> Void)?

    private let segmentedControl = UISegmentedControl(items: [])
    private var choices: [BCR1QuestionModeSelectorChoice] = []
    private var isApplyingModel = false

    var selectedMode: TrainerBCR1QuestionMode? {
        guard choices.indices.contains(segmentedControl.selectedSegmentIndex) else {
            return nil
        }
        return choices[segmentedControl.selectedSegmentIndex].mode
    }

    var displayedTitles: [String] {
        choices.map(\.title)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureView()
    }

    func apply(model: BCR1QuestionModeSelectorModel) {
        accessibilityLabel = model.accessibilityLabel
        segmentedControl.accessibilityLabel = model.accessibilityLabel
        choices = model.choices

        isApplyingModel = true
        segmentedControl.removeAllSegments()

        var selectedIndex = UISegmentedControl.noSegment
        for (index, choice) in model.choices.enumerated() {
            segmentedControl.insertSegment(
                withTitle: choice.title,
                at: index,
                animated: false
            )
            if choice.isSelected {
                selectedIndex = index
            }
        }

        segmentedControl.selectedSegmentIndex = selectedIndex
        isApplyingModel = false
        invalidateIntrinsicContentSize()
    }

    override var intrinsicContentSize: CGSize {
        CGSize(
            width: UIView.noIntrinsicMetric,
            height: segmentedControl.intrinsicContentSize.height + 16
        )
    }

    private func configureView() {
        accessibilityIdentifier = Self.accessibilityIdentifier
        segmentedControl.accessibilityIdentifier =
            Self.segmentedControlAccessibilityIdentifier
        segmentedControl.apportionsSegmentWidthsByContent = false
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        segmentedControl.addTarget(
            self,
            action: #selector(handleSelectionChanged(_:)),
            for: .valueChanged
        )

        addSubview(segmentedControl)
        NSLayoutConstraint.activate([
            segmentedControl.leadingAnchor.constraint(
                equalTo: leadingAnchor,
                constant: 16
            ),
            segmentedControl.trailingAnchor.constraint(
                equalTo: trailingAnchor,
                constant: -16
            ),
            segmentedControl.topAnchor.constraint(
                equalTo: topAnchor,
                constant: 8
            ),
            segmentedControl.bottomAnchor.constraint(
                equalTo: bottomAnchor,
                constant: -8
            )
        ])
    }

    @objc
    private func handleSelectionChanged(_ sender: UISegmentedControl) {
        guard
            !isApplyingModel,
            sender.selectedSegmentIndex != UISegmentedControl.noSegment,
            choices.indices.contains(sender.selectedSegmentIndex)
        else {
            return
        }

        onEvent?(.select(choices[sender.selectedSegmentIndex].mode))
    }
}
#endif
