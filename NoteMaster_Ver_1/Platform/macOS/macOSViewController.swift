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
        )
    ) {
        didSet {
            guard isViewLoaded else {
                return
            }

            applyStaffDisplayState()
        }
    }

    private var isSettingsPresented = false

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
                staffDisplayState: staffDisplayState
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
    private var horizontalFretboardConstraints: [NSLayoutConstraint] = []
    private var verticalFretboardConstraints: [NSLayoutConstraint] = []
    private var verticalFretboardHostHeightConstraint: NSLayoutConstraint?

    private lazy var fretboardView: macOSFretboardView = {
        let fretboardView = macOSFretboardView(configuration: displayState.configuration)
        fretboardView.onRawEvent = { hitResult in
            print(hitResult.debugSummary(platform: "macOS"))
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
    }

    private func configureLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        settingsContainerView.translatesAutoresizingMaskIntoConstraints = false
        staffView.translatesAutoresizingMaskIntoConstraints = false
        fretboardHostView.translatesAutoresizingMaskIntoConstraints = false
        fretboardView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.documentView = contentView
        view.addSubview(scrollView)
        contentView.addSubview(staffView)
        contentView.addSubview(fretboardHostView)
        fretboardHostView.addSubview(fretboardView)
        view.addSubview(settingsButton)
        view.addSubview(settingsContainerView)

        let safeArea = view.safeAreaLayoutGuide
        rebuildVerticalFretboardHostHeightConstraint()
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
            fretboardView.topAnchor.constraint(equalTo: fretboardHostView.topAnchor),
            fretboardView.bottomAnchor.constraint(equalTo: fretboardHostView.bottomAnchor),
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
        updateSettingsButtonAppearance()
        settingsContainerView.setPresented(false)
    }

    private func updateFretboardLayoutModeConstraints() {
        let isVertical = displayState.displayMode == .vertical
        verticalFretboardHostHeightConstraint?.isActive = isVertical
        horizontalFretboardConstraints.forEach { $0.isActive = !isVertical }
        verticalFretboardConstraints.forEach { $0.isActive = isVertical }
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
        rebuildVerticalFretboardHostHeightConstraint()
        applySettingsPanelState()
        updateFretboardLayoutModeConstraints()
        updateLayoutIfNeeded()
    }

    private func applyStaffDisplayState() {
        staffView.configuration = staffDisplayState.configuration
        staffView.sceneProvider = staffDisplayState.sceneProvider
        applySettingsPanelState()
        updateLayoutIfNeeded()
    }

    private func applySettingsPanelState() {
        settingsContainerView.model = SettingsPanelSnapshotBuilder.makeModel(
            fretboardDisplayState: displayState,
            staffDisplayState: staffDisplayState
        )
    }

    private func updateLayoutIfNeeded() {
        view.needsLayout = true
        view.layoutSubtreeIfNeeded()
    }

    private func setSettingsPresented(_ presented: Bool) {
        guard isSettingsPresented != presented else {
            return
        }

        isSettingsPresented = presented
        settingsContainerView.setPresented(presented)
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
        event.apply(
            to: &nextDisplayState,
            and: &nextStaffDisplayState
        )

        let didChangeFretboard = nextDisplayState != displayState
        let didChangeStaff = nextStaffDisplayState != staffDisplayState

        guard didChangeFretboard || didChangeStaff else {
            return
        }

        if didChangeFretboard {
            displayState = nextDisplayState
        }

        if didChangeStaff {
            staffDisplayState = nextStaffDisplayState
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
}

#endif
