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

            applyFretboardDisplayState()
        }
    }

    private var staffDisplayState = StaffDisplayState(
        configuration: StaffConfiguration(
            renderMode: .coreText,
            trebleClefAnchorLogicalDownwardShiftRatio: 0.06,
            debugOptions: .init(
                showsClefBounds: true,
                showsClefAnchor: true
            )
        )
    ) {
        didSet {
            guard isViewLoaded else {
                return
            }

            applyStaffDisplayState()
        }
    }

    private lazy var buttonPanelView: iOSButtonPanelView = {
        let buttonPanelView = iOSButtonPanelView(
            model: ButtonPanelSnapshotBuilder.makeModel(from: displayState)
        )
        buttonPanelView.onAction = { [weak self] actionID in
            self?.handleButtonAction(actionID)
        }
        return buttonPanelView
    }()

    private lazy var staffControlPanelView: iOSStaffControlPanelView = {
        let staffControlPanelView = iOSStaffControlPanelView(
            model: StaffControlPanelSnapshotBuilder.makeModel(from: staffDisplayState)
        )
        staffControlPanelView.onEvent = { [weak self] event in
            self?.handleStaffControlEvent(event)
        }
        return staffControlPanelView
    }()

    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let fretboardHostView = UIView()
    private var horizontalFretboardConstraints: [NSLayoutConstraint] = []
    private var verticalFretboardConstraints: [NSLayoutConstraint] = []
    private var verticalFretboardHostHeightConstraint: NSLayoutConstraint?

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
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        buttonPanelView.translatesAutoresizingMaskIntoConstraints = false
        staffControlPanelView.translatesAutoresizingMaskIntoConstraints = false
        staffView.translatesAutoresizingMaskIntoConstraints = false
        fretboardHostView.translatesAutoresizingMaskIntoConstraints = false
        fretboardView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.alwaysBounceHorizontal = false
        scrollView.showsHorizontalScrollIndicator = false
        // 点击直接透传给指板；一旦用户开始纵向拖动，scroll view 可以取消当前触摸序列并接管滚动。
        scrollView.delaysContentTouches = false
        scrollView.canCancelContentTouches = true
        scrollView.panGestureRecognizer.cancelsTouchesInView = true
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(buttonPanelView)
        contentView.addSubview(staffControlPanelView)
        contentView.addSubview(staffView)
        contentView.addSubview(fretboardHostView)
        fretboardHostView.addSubview(fretboardView)

        let safeArea = view.safeAreaLayoutGuide
        verticalFretboardHostHeightConstraint = fretboardHostView.heightAnchor.constraint(
            equalTo: safeArea.heightAnchor,
            multiplier: Layout.verticalFretboardHostHeightRatio
        )
        horizontalFretboardConstraints = [
            fretboardView.leadingAnchor.constraint(equalTo: fretboardHostView.leadingAnchor),
            fretboardView.trailingAnchor.constraint(equalTo: fretboardHostView.trailingAnchor)
        ]
        verticalFretboardConstraints = [
            fretboardView.centerXAnchor.constraint(equalTo: fretboardHostView.centerXAnchor),
            fretboardView.widthAnchor.constraint(lessThanOrEqualTo: fretboardHostView.widthAnchor)
        ]

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: safeArea.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            buttonPanelView.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor,
                constant: Layout.horizontalInset
            ),
            buttonPanelView.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor,
                constant: -Layout.horizontalInset
            ),
            buttonPanelView.topAnchor.constraint(
                equalTo: contentView.topAnchor,
                constant: Layout.topInset
            ),
            staffControlPanelView.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor,
                constant: Layout.horizontalInset
            ),
            staffControlPanelView.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor,
                constant: -Layout.horizontalInset
            ),
            staffControlPanelView.topAnchor.constraint(
                equalTo: buttonPanelView.bottomAnchor,
                constant: Layout.verticalSpacing
            ),
            staffView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            staffView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            staffView.topAnchor.constraint(
                equalTo: staffControlPanelView.bottomAnchor,
                constant: Layout.verticalSpacing
            ),
            fretboardHostView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            fretboardHostView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            fretboardHostView.topAnchor.constraint(
                equalTo: staffView.bottomAnchor,
                constant: Layout.verticalSpacing
            ),
            fretboardHostView.bottomAnchor.constraint(
                equalTo: contentView.bottomAnchor,
                constant: -Layout.bottomInset
            ),
            fretboardView.topAnchor.constraint(equalTo: fretboardHostView.topAnchor),
            fretboardView.bottomAnchor.constraint(equalTo: fretboardHostView.bottomAnchor)
        ])

        updateFretboardLayoutModeConstraints()
    }

    private func updateFretboardLayoutModeConstraints() {
        let isVertical = displayState.displayMode == .vertical
        verticalFretboardHostHeightConstraint?.isActive = isVertical
        horizontalFretboardConstraints.forEach { $0.isActive = !isVertical }
        verticalFretboardConstraints.forEach { $0.isActive = isVertical }
    }

    private func applyDisplayState() {
        applyFretboardDisplayState()
        applyStaffDisplayState()
    }

    private func applyFretboardDisplayState() {
        buttonPanelView.model = ButtonPanelSnapshotBuilder.makeModel(from: displayState)
        fretboardView.configuration = displayState.configuration
        fretboardView.contentProvider = displayState.contentProvider
        updateFretboardLayoutModeConstraints()
        updateLayoutIfNeeded()
    }

    private func applyStaffDisplayState() {
        staffControlPanelView.model = StaffControlPanelSnapshotBuilder.makeModel(from: staffDisplayState)
        staffView.configuration = staffDisplayState.configuration
        staffView.sceneProvider = staffDisplayState.sceneProvider
        updateLayoutIfNeeded()
    }

    private func updateLayoutIfNeeded() {
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

    private func handleStaffControlEvent(_ event: StaffControlEvent) {
        var nextStaffDisplayState = staffDisplayState
        nextStaffDisplayState.apply(event)

        guard nextStaffDisplayState != staffDisplayState else {
            return
        }

        staffDisplayState = nextStaffDisplayState
    }
}

private enum Layout {
    static let horizontalInset: CGFloat = 16
    static let topInset: CGFloat = 16
    static let verticalSpacing: CGFloat = 20
    static let bottomInset: CGFloat = 16
    // 调整这个比例即可平衡竖向指板与按钮面板/五线谱的可视占比。
    static let verticalFretboardHostHeightRatio: CGFloat = 0.72
}
#endif
