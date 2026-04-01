//
//  PageDisplayState.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/27.
//

enum PageTopContentMode: Equatable, Hashable, Sendable {
    case staff
    case targetPrompt
    case fretboard
}

enum PageMainContentMode: Equatable, Hashable, Sendable {
    case fretboard
    case naturalNoteStrip
}

struct PageDisplayState: Equatable, Sendable {
    // 页面级编排状态独立于 fretboard / staff 内部 display state。
    var topContentMode: PageTopContentMode
    var mainContentMode: PageMainContentMode

    static let `default` = PageDisplayState(
        topContentMode: .staff,
        mainContentMode: .fretboard
    )
    static let positionPrompt = PageDisplayState(
        topContentMode: .fretboard,
        mainContentMode: .naturalNoteStrip
    )

    init(
        topContentMode: PageTopContentMode = .staff,
        mainContentMode: PageMainContentMode = .fretboard
    ) {
        self.topContentMode = topContentMode
        self.mainContentMode = mainContentMode
        self = ExerciseSceneValidator.normalizedLegacyPageDisplayState(
            from: self,
            prioritizingTopContent: true
        )
    }

    var showsFretboardInTopContent: Bool {
        topContentMode == .fretboard
    }

    var showsFretboardInMainContent: Bool {
        mainContentMode == .fretboard
    }

    var showsFretboard: Bool {
        showsFretboardInTopContent || showsFretboardInMainContent
    }

    var hasValidFretboardPlacement: Bool {
        !(showsFretboardInTopContent && showsFretboardInMainContent)
    }

    mutating func setTopContentMode(_ mode: PageTopContentMode) {
        topContentMode = mode
        normalizeFretboardPlacement(prioritizingTopContent: true)
    }

    mutating func setMainContentMode(_ mode: PageMainContentMode) {
        mainContentMode = mode
        normalizeFretboardPlacement(prioritizingTopContent: false)
    }

    private mutating func normalizeFretboardPlacement(
        prioritizingTopContent: Bool
    ) {
        self = ExerciseSceneValidator.normalizedLegacyPageDisplayState(
            from: self,
            prioritizingTopContent: prioritizingTopContent
        )
    }
}
