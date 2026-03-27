//
//  PageDisplayState.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/27.
//

enum PageTopContentMode: Equatable, Hashable, Sendable {
    case staff
    case targetPrompt
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

    init(
        topContentMode: PageTopContentMode = .staff,
        mainContentMode: PageMainContentMode = .fretboard
    ) {
        self.topContentMode = topContentMode
        self.mainContentMode = mainContentMode
    }

    mutating func setTopContentMode(_ mode: PageTopContentMode) {
        topContentMode = mode
    }

    mutating func setMainContentMode(_ mode: PageMainContentMode) {
        mainContentMode = mode
    }
}
