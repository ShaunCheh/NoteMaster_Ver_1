//
//  macOSBCR1QuestionModeSelectorView.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/9/11.
//

#if os(macOS)
import AppKit

final class macOSBCR1QuestionModeSelectorView: NSView {
    static let accessibilityIdentifier =
        NSUserInterfaceItemIdentifier("bcr1-question-mode-selector")
    static let segmentedControlAccessibilityIdentifier =
        NSUserInterfaceItemIdentifier(
            "bcr1-question-mode-segmented-control"
        )

    var onEvent: ((BCR1QuestionModeSelectorEvent) -> Void)?

    private let segmentedControl = NSSegmentedControl()
    private var choices: [BCR1QuestionModeSelectorChoice] = []
    private var isApplyingModel = false

    var selectedMode: TrainerBCR1QuestionMode? {
        guard choices.indices.contains(segmentedControl.selectedSegment) else {
            return nil
        }
        return choices[segmentedControl.selectedSegment].mode
    }

    var displayedTitles: [String] {
        choices.map(\.title)
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureView()
    }

    func apply(model: BCR1QuestionModeSelectorModel) {
        setAccessibilityLabel(model.accessibilityLabel)
        segmentedControl.setAccessibilityLabel(model.accessibilityLabel)
        choices = model.choices

        isApplyingModel = true
        segmentedControl.segmentCount = model.choices.count

        var selectedSegment = -1
        for (index, choice) in model.choices.enumerated() {
            segmentedControl.setLabel(choice.title, forSegment: index)
            segmentedControl.setEnabled(true, forSegment: index)
            if choice.isSelected {
                selectedSegment = index
            }
        }

        segmentedControl.selectedSegment = selectedSegment
        isApplyingModel = false
        invalidateIntrinsicContentSize()
    }

    override var intrinsicContentSize: NSSize {
        NSSize(
            width: NSView.noIntrinsicMetric,
            height: segmentedControl.intrinsicContentSize.height + 16
        )
    }

    private func configureView() {
        identifier = Self.accessibilityIdentifier
        segmentedControl.identifier =
            Self.segmentedControlAccessibilityIdentifier
        segmentedControl.trackingMode = .selectOne
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        segmentedControl.target = self
        segmentedControl.action = #selector(handleSelectionChanged(_:))

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
    private func handleSelectionChanged(_ sender: NSSegmentedControl) {
        guard
            !isApplyingModel,
            choices.indices.contains(sender.selectedSegment)
        else {
            return
        }

        onEvent?(.select(choices[sender.selectedSegment].mode))
    }
}
#endif
