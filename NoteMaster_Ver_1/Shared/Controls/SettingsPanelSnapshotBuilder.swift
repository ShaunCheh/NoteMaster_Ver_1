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
        from stateContext: SettingsPanelStateContext
    ) -> SettingsPanelModel {
        var normalizedStateContext = stateContext
        LegacyPageLayoutAdapter.reconcile(&normalizedStateContext)

        return SettingsPanelModel(
            sections: SettingsSectionID.allCases.compactMap {
                makeSection(
                    id: $0,
                    stateContext: normalizedStateContext
                )
            }
        )
    }

    private static func makeSection(
        id: SettingsSectionID,
        stateContext: SettingsPanelStateContext
    ) -> SettingsSection? {
        let rows = id.rowIDs.compactMap {
            makeRow(
                id: $0,
                stateContext: stateContext
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
        stateContext: SettingsPanelStateContext
    ) -> SettingsRow? {
        switch id {
        case let .choice(choiceRowID):
            guard shouldInclude(
                choiceRowID: choiceRowID,
                stateContext: stateContext
            ) else {
                return nil
            }

            return .choice(
                makeChoiceRow(
                    id: choiceRowID,
                    stateContext: stateContext
                )
            )
        case let .positionFilter(positionFilterRowID):
            guard shouldInclude(
                positionFilterRowID: positionFilterRowID,
                stateContext: stateContext
            ) else {
                return nil
            }

            return .positionFilter(
                makePositionFilterRow(
                    id: positionFilterRowID,
                    stateContext: stateContext
                )
            )
        case let .slider(sliderID):
            guard shouldInclude(
                sliderID: sliderID,
                stateContext: stateContext
            ) else {
                return nil
            }

            return .slider(
                makeSliderRow(
                    id: sliderID,
                    stateContext: stateContext
                )
            )
        case let .toggle(toggleID):
            return .toggle(
                makeToggleRow(
                    id: toggleID,
                    stateContext: stateContext
                )
            )
        }
    }

    private static func makeChoiceRow(
        id: SettingsChoiceRowID,
        stateContext: SettingsPanelStateContext
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
                    stateContext: stateContext
                )
            }
        )
    }

    private static func makeChoiceItem(
        id: SettingsActionID,
        stateContext: SettingsPanelStateContext
    ) -> SettingsChoiceItem {
        SettingsChoiceItem(
            id: id,
            title: id.title,
            accessibilityLabel: id.accessibilityLabel,
            isSelected: id.isSelected(in: stateContext),
            isEnabled: id.isEnabled(in: stateContext)
        )
    }

    private static func makeSliderRow(
        id: SettingsSliderID,
        stateContext: SettingsPanelStateContext
    ) -> SettingsSliderRow {
        let range = id.range
        let value = id.resolvedValue(in: stateContext)
        let clampedValue = min(max(value, range.lowerBound), range.upperBound)

        return SettingsSliderRow(
            id: id,
            title: id.title,
            accessibilityLabel: id.accessibilityLabel,
            value: clampedValue,
            range: range,
            displayValue: id.displayValue(for: clampedValue),
            isEnabled: id.isEnabled(in: stateContext)
        )
    }

    private static func makeToggleRow(
        id: SettingsToggleID,
        stateContext: SettingsPanelStateContext
    ) -> SettingsToggleRow {
        SettingsToggleRow(
            id: id,
            title: id.title,
            accessibilityLabel: id.accessibilityLabel,
            isOn: id.resolvedValue(in: stateContext),
            isEnabled: id.isEnabled(in: stateContext)
        )
    }

    private static func makePositionFilterRow(
        id: SettingsPositionFilterRowID,
        stateContext: SettingsPanelStateContext
    ) -> SettingsPositionFilterRow {
        switch id {
        case .positionQuestionPitchClasses:
            let configuration = stateContext.trainerDisplayState
                .positionQuestionConfiguration
            return SettingsPositionFilterRow(
                id: id,
                title: "Note Names",
                accessibilityLabel: "Select the note names used when generating position questions",
                options: id.supportedPitchClasses.map { pitchClass in
                    let title = pitchClass.displayText()
                    let isSelected = configuration.contains(pitchClass)
                    return SettingsPositionFilterItem(
                        id: .pitchClass(pitchClass),
                        title: title,
                        accessibilityLabel: "Toggle note name \(title) for position questions",
                        isSelected: isSelected,
                        isEnabled: !isSelected || configuration.canDeselect(pitchClass)
                    )
                }
            )
        case .positionPromptFilterOptions:
            let configuration = stateContext.trainerDisplayState
                .positionPromptConfiguration
            switch configuration.filterMode {
            case .noteName:
                return SettingsPositionFilterRow(
                    id: id,
                    title: "Note Names",
                    accessibilityLabel: "Select the note names used when generating position prompt questions",
                    options: id.supportedPitchClasses.map { pitchClass in
                        let title = pitchClass.displayText()
                        let isSelected = configuration.contains(pitchClass)
                        return SettingsPositionFilterItem(
                            id: .pitchClass(pitchClass),
                            title: title,
                            accessibilityLabel: "Toggle note name \(title) for position prompt questions",
                            isSelected: isSelected,
                            isEnabled: !isSelected || configuration.canDeselect(pitchClass)
                        )
                    }
                )
            case .fret:
            return SettingsPositionFilterRow(
                id: id,
                title: "Frets",
                accessibilityLabel: "Select the frets used when generating position prompt questions",
                options: id.supportedFrets.map { fret in
                    let isSelected = configuration.contains(fret)
                    return SettingsPositionFilterItem(
                        id: .fret(fret),
                        title: "\(fret)",
                        accessibilityLabel: "Toggle fret \(fret) for position prompt questions",
                        isSelected: isSelected,
                        isEnabled: !isSelected || configuration.canDeselect(fret)
                    )
                }
            )
            }
        }
    }

    private static func shouldInclude(
        choiceRowID: SettingsChoiceRowID,
        stateContext: SettingsPanelStateContext
    ) -> Bool {
        switch choiceRowID {
        case .positionPromptFilterMode:
            return stateContext.trainerDisplayState.isPositionPromptMode
        default:
            return true
        }
    }

    private static func shouldInclude(
        sliderID: SettingsSliderID,
        stateContext: SettingsPanelStateContext
    ) -> Bool {
        switch sliderID {
        case .verticalHostHeightRatio:
            return stateContext.showsVerticalViewportHeightControl
        case .pianoRowCount:
            return true
        case .clefScale, .clefVerticalTrim, .clefAnchorYOffset:
            return true
        }
    }

    private static func shouldInclude(
        positionFilterRowID: SettingsPositionFilterRowID,
        stateContext: SettingsPanelStateContext
    ) -> Bool {
        switch positionFilterRowID {
        case .positionQuestionPitchClasses:
            return stateContext.trainerDisplayState.isPositionPromptMode
        case .positionPromptFilterOptions:
            return false
        }
    }
}
