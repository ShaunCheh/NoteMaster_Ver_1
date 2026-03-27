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
    var trainerDisplayState: TrainerDisplayState

    static let `default` = SettingsPanelStateContext()

    init(
        fretboardDisplayState: FretboardDisplayState = .default,
        staffDisplayState: StaffDisplayState = .default,
        pageDisplayState: PageDisplayState = .default,
        trainerDisplayState: TrainerDisplayState = .default
    ) {
        self.fretboardDisplayState = fretboardDisplayState
        self.staffDisplayState = staffDisplayState
        self.pageDisplayState = pageDisplayState
        self.trainerDisplayState = trainerDisplayState
    }
}
