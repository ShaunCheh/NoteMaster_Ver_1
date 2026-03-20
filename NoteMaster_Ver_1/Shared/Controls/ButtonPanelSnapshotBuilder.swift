//
//  ButtonPanelSnapshotBuilder.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/20.
//

enum ButtonPanelSnapshotBuilder {
    static func makeModel(from displayState: FretboardDisplayState) -> ButtonPanelModel {
        ButtonPanelModel(
            sections: ButtonPanelSectionID.allCases.map {
                makeSection(
                    id: $0,
                    displayState: displayState
                )
            }
        )
    }

    private static func makeSection(
        id: ButtonPanelSectionID,
        displayState: FretboardDisplayState
    ) -> ButtonPanelSection {
        let actions = ButtonPanelActionID.allCases.filter { $0.sectionID == id }

        return ButtonPanelSection(
            id: id,
            title: id.title,
            selectionStyle: id.selectionStyle,
            items: actions.map {
                makeItem(
                    for: $0,
                    displayState: displayState
                )
            }
        )
    }

    private static func makeItem(
        for actionID: ButtonPanelActionID,
        displayState: FretboardDisplayState
    ) -> ButtonPanelItem {
        ButtonPanelItem(
            id: actionID,
            title: actionID.title,
            accessibilityLabel: actionID.accessibilityLabel,
            isSelected: actionID.isSelected(in: displayState),
            isEnabled: actionID.isEnabled(in: displayState)
        )
    }
}
