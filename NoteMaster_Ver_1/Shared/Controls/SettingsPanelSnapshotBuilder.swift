//
//  SettingsPanelSnapshotBuilder.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/25.
//

import Foundation
import CoreGraphics

enum SettingsPanelSnapshotBuilder {
    static func makeModel(
        fretboardDisplayState: FretboardDisplayState,
        staffDisplayState: StaffDisplayState
    ) -> SettingsPanelModel {
        SettingsPanelModel(
            sections: SettingsSectionID.allCases.compactMap {
                makeSection(
                    id: $0,
                    fretboardDisplayState: fretboardDisplayState,
                    staffDisplayState: staffDisplayState
                )
            }
        )
    }

    private static func makeSection(
        id: SettingsSectionID,
        fretboardDisplayState: FretboardDisplayState,
        staffDisplayState: StaffDisplayState
    ) -> SettingsSection? {
        let rows = id.rowIDs.compactMap {
            makeRow(
                id: $0,
                fretboardDisplayState: fretboardDisplayState,
                staffDisplayState: staffDisplayState
            )
        }

        guard !rows.isEmpty else {
            return nil
        }

        return SettingsSection(
            id: id,
            title: id.title,
            rows: rows
        )
    }

    private static func makeRow(
        id: SettingsRowID,
        fretboardDisplayState: FretboardDisplayState,
        staffDisplayState: StaffDisplayState
    ) -> SettingsRow? {
        switch id {
        case let .choice(choiceRowID):
            return .choice(
                makeChoiceRow(
                    id: choiceRowID,
                    fretboardDisplayState: fretboardDisplayState,
                    staffDisplayState: staffDisplayState
                )
            )
        case let .slider(sliderID):
            guard shouldInclude(
                sliderID: sliderID,
                fretboardDisplayState: fretboardDisplayState,
                staffDisplayState: staffDisplayState
            ) else {
                return nil
            }

            return .slider(
                makeSliderRow(
                    id: sliderID,
                    fretboardDisplayState: fretboardDisplayState,
                    staffDisplayState: staffDisplayState
                )
            )
        }
    }

    private static func makeChoiceRow(
        id: SettingsChoiceRowID,
        fretboardDisplayState: FretboardDisplayState,
        staffDisplayState: StaffDisplayState
    ) -> SettingsChoiceRow {
        SettingsChoiceRow(
            id: id,
            title: id.title,
            accessibilityLabel: id.accessibilityLabel,
            selectionStyle: id.selectionStyle,
            presentationStyle: id.presentationStyle,
            choices: id.actionIDs.map {
                makeChoiceItem(
                    id: $0,
                    fretboardDisplayState: fretboardDisplayState,
                    staffDisplayState: staffDisplayState
                )
            }
        )
    }

    private static func makeChoiceItem(
        id: SettingsActionID,
        fretboardDisplayState: FretboardDisplayState,
        staffDisplayState: StaffDisplayState
    ) -> SettingsChoiceItem {
        SettingsChoiceItem(
            id: id,
            title: id.title,
            accessibilityLabel: id.accessibilityLabel,
            isSelected: id.isSelected(
                fretboardDisplayState: fretboardDisplayState,
                staffDisplayState: staffDisplayState
            ),
            isEnabled: id.isEnabled(
                fretboardDisplayState: fretboardDisplayState,
                staffDisplayState: staffDisplayState
            )
        )
    }

    private static func makeSliderRow(
        id: SettingsSliderID,
        fretboardDisplayState: FretboardDisplayState,
        staffDisplayState: StaffDisplayState
    ) -> SettingsSliderRow {
        let range = id.range
        let value = id.resolvedValue(
            fretboardDisplayState: fretboardDisplayState,
            staffDisplayState: staffDisplayState
        )
        let clampedValue = min(max(value, range.lowerBound), range.upperBound)

        return SettingsSliderRow(
            id: id,
            title: id.title,
            accessibilityLabel: id.accessibilityLabel,
            value: clampedValue,
            range: range,
            displayValue: id.displayValue(for: clampedValue),
            isEnabled: id.isEnabled(
                fretboardDisplayState: fretboardDisplayState,
                staffDisplayState: staffDisplayState
            )
        )
    }

    private static func shouldInclude(
        sliderID: SettingsSliderID,
        fretboardDisplayState: FretboardDisplayState,
        staffDisplayState _: StaffDisplayState
    ) -> Bool {
        switch sliderID {
        case .verticalHostHeightRatio:
            return fretboardDisplayState.displayMode == .vertical
        case .clefScale, .clefVerticalTrim, .clefAnchorYOffset:
            return true
        }
    }
}
