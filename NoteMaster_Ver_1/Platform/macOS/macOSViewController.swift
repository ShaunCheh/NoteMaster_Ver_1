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
        ),
        score: StaffScoreFixtures.namedKeySignatureDemo(clef: .treble)
    ) {
        didSet {
            guard isViewLoaded else {
                return
            }

            applyStaffDisplayState()
        }
    }
    // 顶部内容模式独立于 staff / fretboard display state；
    // 后续阶段再接 settings 与 topContentHostView。
    private var topContentDisplayState = TopContentDisplayState.default

    private var isSettingsPresented = false
    private var fretboardTrainerState = FretboardNaturalNoteTrainerState()

    private var currentFretboardTrainerPrompt: FretboardNaturalNoteTrainerState.Prompt {
        fretboardTrainerState.prompt
    }

    private lazy var settingsButton: NSButton = {
        let button = NSButton()
        button.isBordered = false
        button.bezelStyle = .regularSquare
        button.imagePosition = .imageOnly
        button.image = NSImage(
            systemSymbolName: "gearshape.fill",
            accessibilityDescription: "Settings"
        )
        button.imageScaling = .scaleProportionallyDown
        button.contentTintColor = .labelColor
        button.identifier = NSUserInterfaceItemIdentifier("floating-settings-button")
        button.target = self
        button.action = #selector(handleSettingsButtonTap)
        button.wantsLayer = true
        button.layer?.cornerRadius = Layout.settingsButtonSize / 2
        button.layer?.shadowColor = NSColor.black.cgColor
        button.layer?.shadowOpacity = 0.12
        button.layer?.shadowRadius = 12
        button.layer?.shadowOffset = CGSize(width: 0, height: -4)
        return button
    }()

    private lazy var settingsContainerView: macOSSettingsContainerView = {
        let settingsContainerView = macOSSettingsContainerView(
            model: SettingsPanelSnapshotBuilder.makeModel(
                fretboardDisplayState: displayState,
                staffDisplayState: staffDisplayState,
                topContentDisplayState: topContentDisplayState
            )
        )
        settingsContainerView.onEvent = { [weak self] event in
            self?.handleSettingsPanelEvent(event)
        }
        settingsContainerView.onDismissRequest = { [weak self] in
            self?.setSettingsPresented(false)
        }
        return settingsContainerView
    }()

    private let scrollView = NSScrollView()
    private let contentView = NSView()
    private let fretboardHostView = NSView()
    private let fretboardViewportScrollView = NSScrollView()
    private let fretboardScrollContentView = NSView()
    private var horizontalFretboardDocumentWidthConstraint: NSLayoutConstraint?
    private var horizontalFretboardContentWidthConstraint: NSLayoutConstraint?
    private var verticalFretboardDocumentWidthConstraint: NSLayoutConstraint?
    private var verticalFretboardContentWidthConstraint: NSLayoutConstraint?
    private var fretboardContentCenterXConstraint: NSLayoutConstraint?
    private var verticalFretboardHostHeightConstraint: NSLayoutConstraint?

    private lazy var fretboardView: macOSFretboardView = {
        let fretboardView = macOSFretboardView(configuration: displayState.configuration)
        fretboardView.onRawEvent = { [weak self] hitResult in
            self?.handleFretboardTrainerHitResult(hitResult)
        }
        return fretboardView
    }()

    private lazy var staffView: macOSStaffView = {
        macOSStaffView(
            configuration: staffDisplayState.configuration,
            sceneProvider: staffDisplayState.sceneProvider
        )
    }()

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        configureLayout()
        applyDisplayState()
        applyFretboardTrainerPrompt(reason: "initial")
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        syncVerticalFretboardContentSizeConstraints()
        updateFretboardViewportPresentation()
    }

    private func configureLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        settingsContainerView.translatesAutoresizingMaskIntoConstraints = false
        staffView.translatesAutoresizingMaskIntoConstraints = false
        fretboardHostView.translatesAutoresizingMaskIntoConstraints = false
        fretboardViewportScrollView.translatesAutoresizingMaskIntoConstraints = false
        fretboardScrollContentView.translatesAutoresizingMaskIntoConstraints = false
        fretboardView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.documentView = contentView
        fretboardViewportScrollView.drawsBackground = false
        fretboardViewportScrollView.borderType = .noBorder
        fretboardViewportScrollView.hasVerticalScroller = false
        fretboardViewportScrollView.hasHorizontalScroller = false
        fretboardViewportScrollView.autohidesScrollers = true
        fretboardViewportScrollView.documentView = fretboardScrollContentView
        view.addSubview(scrollView)
        contentView.addSubview(staffView)
        contentView.addSubview(fretboardHostView)
        fretboardHostView.addSubview(fretboardViewportScrollView)
        fretboardScrollContentView.addSubview(fretboardView)
        view.addSubview(settingsButton)
        view.addSubview(settingsContainerView)

        let safeArea = view.safeAreaLayoutGuide
        rebuildVerticalFretboardHostHeightConstraint()
        horizontalFretboardDocumentWidthConstraint = fretboardScrollContentView.widthAnchor.constraint(
            equalTo: fretboardViewportScrollView.contentView.widthAnchor
        )
        horizontalFretboardContentWidthConstraint = fretboardView.widthAnchor.constraint(
            equalTo: fretboardScrollContentView.widthAnchor
        )
        verticalFretboardDocumentWidthConstraint = fretboardScrollContentView.widthAnchor.constraint(
            equalToConstant: displayState.configuration.verticalContentWidth(
                forViewportHeight: displayState.configuration.preferredHeight
            )
        )
        verticalFretboardDocumentWidthConstraint?.priority = .required
        verticalFretboardContentWidthConstraint = fretboardView.widthAnchor.constraint(
            equalToConstant: displayState.configuration.verticalContentWidth(
                forViewportHeight: displayState.configuration.preferredHeight
            )
        )
        verticalFretboardContentWidthConstraint?.priority = .required
        fretboardContentCenterXConstraint = fretboardView.centerXAnchor.constraint(
            equalTo: fretboardScrollContentView.centerXAnchor
        )

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: safeArea.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
            staffView.topAnchor.constraint(
                equalTo: contentView.topAnchor,
                constant: Layout.contentTopInset
            ),
            staffView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            staffView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
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
            fretboardViewportScrollView.leadingAnchor.constraint(equalTo: fretboardHostView.leadingAnchor),
            fretboardViewportScrollView.trailingAnchor.constraint(equalTo: fretboardHostView.trailingAnchor),
            fretboardViewportScrollView.topAnchor.constraint(equalTo: fretboardHostView.topAnchor),
            fretboardViewportScrollView.bottomAnchor.constraint(equalTo: fretboardHostView.bottomAnchor),
            fretboardScrollContentView.leadingAnchor.constraint(
                equalTo: fretboardViewportScrollView.contentView.leadingAnchor
            ),
            fretboardScrollContentView.topAnchor.constraint(
                equalTo: fretboardViewportScrollView.contentView.topAnchor
            ),
            fretboardScrollContentView.heightAnchor.constraint(
                equalTo: fretboardViewportScrollView.contentView.heightAnchor
            ),
            fretboardView.topAnchor.constraint(equalTo: fretboardScrollContentView.topAnchor),
            fretboardView.bottomAnchor.constraint(equalTo: fretboardScrollContentView.bottomAnchor),
            fretboardContentCenterXConstraint!,
            settingsButton.leadingAnchor.constraint(
                equalTo: safeArea.leadingAnchor,
                constant: Layout.horizontalInset
            ),
            settingsButton.topAnchor.constraint(
                equalTo: safeArea.topAnchor,
                constant: Layout.topInset
            ),
            settingsButton.widthAnchor.constraint(equalToConstant: Layout.settingsButtonSize),
            settingsButton.heightAnchor.constraint(equalToConstant: Layout.settingsButtonSize),
            settingsContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            settingsContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            settingsContainerView.topAnchor.constraint(equalTo: view.topAnchor),
            settingsContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        updateFretboardLayoutModeConstraints()
        applySettingsPresentationState()
    }

    private func updateFretboardLayoutModeConstraints() {
        let isVertical = displayState.displayMode == .vertical
        verticalFretboardHostHeightConstraint?.isActive = isVertical
        horizontalFretboardDocumentWidthConstraint?.isActive = !isVertical
        horizontalFretboardContentWidthConstraint?.isActive = !isVertical
        verticalFretboardDocumentWidthConstraint?.isActive = isVertical
        verticalFretboardContentWidthConstraint?.isActive = isVertical

        if !isVertical {
            fretboardViewportScrollView.hasHorizontalScroller = false
            scrollFretboardViewport(toX: 0)
        }
    }

    private func rebuildVerticalFretboardHostHeightConstraint() {
        verticalFretboardHostHeightConstraint?.isActive = false
        verticalFretboardHostHeightConstraint = fretboardHostView.heightAnchor.constraint(
            equalTo: view.safeAreaLayoutGuide.heightAnchor,
            multiplier: displayState.verticalHostHeightRatio
        )
    }

    private func applyDisplayState() {
        applyFretboardDisplayState()
        applyStaffDisplayState()
    }

    private func applyFretboardDisplayState() {
        fretboardView.configuration = displayState.configuration
        fretboardView.contentProvider = displayState.contentProvider
        fretboardView.showsComponentBoundsOverlay = displayState.showsComponentBoundsOverlay
        rebuildVerticalFretboardHostHeightConstraint()
        applySettingsPanelState()
        updateFretboardLayoutModeConstraints()
        updateLayoutIfNeeded()
        syncVerticalFretboardContentSizeConstraints()
        updateLayoutIfNeeded()
        updateFretboardViewportPresentation()
    }

    private func applyStaffDisplayState() {
        staffView.configuration = staffDisplayState.configuration
        staffView.sceneProvider = staffDisplayState.sceneProvider
        staffView.showsComponentBoundsOverlay = staffDisplayState.showsComponentBoundsOverlay
        applySettingsPanelState()
        updateLayoutIfNeeded()
    }

    private func applySettingsPanelState() {
        settingsContainerView.model = SettingsPanelSnapshotBuilder.makeModel(
            fretboardDisplayState: displayState,
            staffDisplayState: staffDisplayState,
            topContentDisplayState: topContentDisplayState
        )
    }

    private func updateLayoutIfNeeded() {
        view.needsLayout = true
        view.layoutSubtreeIfNeeded()
    }

    private func syncVerticalFretboardContentSizeConstraints() {
        guard
            displayState.displayMode == .vertical,
            let verticalFretboardDocumentWidthConstraint,
            let verticalFretboardContentWidthConstraint
        else {
            return
        }

        let contentWidth = fretboardView.verticalContentSize.width
        let viewportWidth = fretboardViewportScrollView.contentView.bounds.width
        guard contentWidth > 0 else {
            return
        }

        let documentWidth = max(viewportWidth, contentWidth)
        if abs(verticalFretboardDocumentWidthConstraint.constant - documentWidth) > Layout.contentSizeTolerance {
            verticalFretboardDocumentWidthConstraint.constant = documentWidth
        }

        if abs(verticalFretboardContentWidthConstraint.constant - contentWidth) > Layout.contentSizeTolerance {
            verticalFretboardContentWidthConstraint.constant = contentWidth
        }
    }

    private func updateFretboardViewportPresentation() {
        let isVertical = displayState.displayMode == .vertical
        guard isVertical else {
            fretboardViewportScrollView.hasHorizontalScroller = false
            return
        }

        let viewportWidth = fretboardViewportScrollView.contentView.bounds.width
        let contentWidth = verticalFretboardContentWidthConstraint?.constant ?? fretboardView.verticalContentSize.width
        guard viewportWidth > 0, contentWidth > 0 else {
            return
        }

        let needsHorizontalScroll = contentWidth > viewportWidth + Layout.contentSizeTolerance
        fretboardViewportScrollView.hasHorizontalScroller = needsHorizontalScroll

        let maxOffsetX = max(contentWidth - viewportWidth, 0)
        let currentOffsetX = fretboardViewportScrollView.contentView.bounds.origin.x
        let clampedOffsetX = needsHorizontalScroll
            ? min(max(currentOffsetX, 0), maxOffsetX)
            : 0

        if abs(currentOffsetX - clampedOffsetX) > Layout.contentSizeTolerance {
            scrollFretboardViewport(toX: clampedOffsetX)
        }
    }

    private func scrollFretboardViewport(toX x: CGFloat) {
        fretboardViewportScrollView.contentView.scroll(to: CGPoint(x: x, y: 0))
        fretboardViewportScrollView.reflectScrolledClipView(
            fretboardViewportScrollView.contentView
        )
    }

    private func handleFretboardTrainerHitResult(_ hitResult: FretboardHitResult) {
        switch fretboardTrainerState.handle(
            hitResult: hitResult,
            configuration: displayState.configuration
        ) {
        case .ignored(.nonEndedPhase):
            return
        case .ignored(.missingHitCell):
            print(
                "[FretboardTrainer][macOS] target=\(currentFretboardTrainerPrompt.displayText) result=ignored reason=missingHitCell"
            )
        case let .ignored(.unresolvedHitPitch(cell)):
            print(
                "[FretboardTrainer][macOS] target=\(currentFretboardTrainerPrompt.displayText) result=ignored reason=unresolvedHitPitch string=\(cell.stringIndex) fret=\(cell.fret)"
            )
        case let .evaluated(evaluation):
            print("[macOS] \(evaluation.debugSummary())")
            if evaluation.didAdvanceTarget {
                applyFretboardTrainerPrompt(reason: "advanced")
            }
        }
    }

    // 当前阶段只输出控制台；后续如果要显示目标音 UI，只需在这里同步 overlay。
    private func applyFretboardTrainerPrompt(reason: String) {
        let prompt = currentFretboardTrainerPrompt
        print(
            "[FretboardTrainer][macOS] target=\(prompt.displayText) state=\(reason)"
        )
    }

    private func setSettingsPresented(_ presented: Bool) {
        guard isSettingsPresented != presented else {
            return
        }

        isSettingsPresented = presented
        applySettingsPresentationState()
    }

    // 控制器仍然持有 settings 展示状态真相；
    // 后续阶段把页面入口按钮隐藏/恢复接到这里即可，不必分散到多个调用点。
    private func applySettingsPresentationState() {
        settingsContainerView.setPresented(isSettingsPresented)
        settingsButton.isHidden = isSettingsPresented
        updateSettingsButtonAppearance()
    }

    private func updateSettingsButtonAppearance() {
        settingsButton.contentTintColor = isSettingsPresented ? .white : .labelColor
        settingsButton.layer?.backgroundColor = (
            isSettingsPresented
                ? NSColor.controlAccentColor
                : NSColor.controlBackgroundColor
        ).cgColor
        settingsButton.toolTip = isSettingsPresented ? "Hide settings" : "Show settings"
    }

    @objc
    private func handleSettingsButtonTap() {
        setSettingsPresented(!isSettingsPresented)
    }

    private func handleSettingsPanelEvent(_ event: SettingsPanelEvent) {
        var nextDisplayState = displayState
        var nextStaffDisplayState = staffDisplayState
        var nextTopContentDisplayState = topContentDisplayState
        event.apply(
            to: &nextDisplayState,
            and: &nextStaffDisplayState,
            topContentDisplayState: &nextTopContentDisplayState
        )

        let didChangeFretboard = nextDisplayState != displayState
        let didChangeStaff = nextStaffDisplayState != staffDisplayState
        let didChangeTopContent = nextTopContentDisplayState != topContentDisplayState

        guard didChangeFretboard || didChangeStaff || didChangeTopContent else {
            return
        }

        if didChangeTopContent {
            topContentDisplayState = nextTopContentDisplayState
        }

        if didChangeFretboard {
            displayState = nextDisplayState
        }

        if didChangeStaff {
            staffDisplayState = nextStaffDisplayState
        }

        if didChangeTopContent, !didChangeFretboard, !didChangeStaff {
            applySettingsPanelState()
        }
    }
}

private enum Layout {
    static let horizontalInset: CGFloat = 16
    static let topInset: CGFloat = 16
    static let contentTopInset: CGFloat = 68
    static let verticalSpacing: CGFloat = 20
    static let bottomInset: CGFloat = 16
    static let settingsButtonSize: CGFloat = 40
    static let contentSizeTolerance: CGFloat = 0.5
}

#endif
