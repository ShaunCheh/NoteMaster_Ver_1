//
//  SettingsPanelStateContext.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/27.
//

struct SettingsPanelStateContext: Equatable, Sendable {
    var fretboardDisplayState: FretboardDisplayState
    var staffDisplayState: StaffDisplayState
    var pageDisplayState: PageDisplayState

    static let `default` = SettingsPanelStateContext(
        fretboardDisplayState: .default,
        staffDisplayState: .default,
        pageDisplayState: .default
    )
}
