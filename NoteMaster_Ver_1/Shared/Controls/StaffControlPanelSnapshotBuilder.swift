//
//  StaffControlPanelSnapshotBuilder.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/24.
//

import Foundation
import CoreGraphics

enum StaffControlPanelSnapshotBuilder {
    static func makeModel(from displayState: StaffDisplayState) -> StaffControlPanelModel {
        StaffControlPanelModel(
            sections: StaffControlSectionID.allCases.compactMap {
                makeSection(
                    id: $0,
                    displayState: displayState
                )
            }
        )
    }

    private static func makeSection(
        id: StaffControlSectionID,
        displayState: StaffDisplayState
    ) -> StaffControlSection? {
        let rows = makeRows(
            for: id,
            displayState: displayState
        )

        guard !rows.isEmpty else {
            return nil
        }

        return StaffControlSection(
            id: id,
            title: id.title,
            rows: rows
        )
    }

    private static func makeRows(
        for sectionID: StaffControlSectionID,
        displayState: StaffDisplayState
    ) -> [StaffControlRow] {
        let optionRows = StaffOptionControlItem.ID.allCases
            .filter { $0.sectionID == sectionID }
            .map {
                StaffControlRow.option(
                    makeOption(
                        for: $0,
                        displayState: displayState
                    )
                )
            }

        let sliderRows = StaffSliderControlItem.ID.allCases
            .filter { $0.sectionID == sectionID }
            .map {
                StaffControlRow.slider(
                    makeSlider(
                        for: $0,
                        displayState: displayState
                    )
                )
            }

        return optionRows + sliderRows
    }

    private static func makeOption(
        for optionID: StaffOptionControlItem.ID,
        displayState: StaffDisplayState
    ) -> StaffOptionControlItem {
        switch optionID {
        case .clef:
            return StaffOptionControlItem(
                id: optionID,
                title: optionID.title,
                accessibilityLabel: optionID.accessibilityLabel,
                choices: StaffClef.allCases.map {
                    StaffOptionChoice(
                        clef: $0,
                        title: $0.title,
                        isSelected: $0 == displayState.configuration.clef
                    )
                },
                isEnabled: true
            )
        }
    }

    private static func makeSlider(
        for sliderID: StaffSliderControlItem.ID,
        displayState: StaffDisplayState
    ) -> StaffSliderControlItem {
        let range = sliderID.range
        let value = resolvedValue(
            for: sliderID,
            displayState: displayState
        )
        let clampedValue = min(max(value, range.lowerBound), range.upperBound)

        return StaffSliderControlItem(
            id: sliderID,
            title: sliderID.title,
            accessibilityLabel: sliderID.accessibilityLabel,
            value: clampedValue,
            range: range,
            displayValue: displayValue(
                for: sliderID,
                value: clampedValue
            ),
            isEnabled: isEnabled(
                for: sliderID,
                displayState: displayState
            )
        )
    }

    private static func resolvedValue(
        for sliderID: StaffSliderControlItem.ID,
        displayState: StaffDisplayState
    ) -> CGFloat {
        switch sliderID {
        case .clefScale:
            return displayState.configuration.layoutMetrics.clefScale
        case .clefVerticalTrim:
            return displayState.configuration.clefVerticalTrimRatio(
                for: displayState.configuration.clef
            )
        case .clefAnchorYOffset:
            return displayState.configuration.clefAnchorLogicalDownwardShiftRatio(
                for: displayState.configuration.clef
            )
        }
    }

    private static func isEnabled(
        for sliderID: StaffSliderControlItem.ID,
        displayState _: StaffDisplayState
    ) -> Bool {
        switch sliderID {
        case .clefScale, .clefVerticalTrim, .clefAnchorYOffset:
            return true
        }
    }

    private static func displayValue(
        for sliderID: StaffSliderControlItem.ID,
        value: CGFloat
    ) -> String {
        switch sliderID {
        case .clefScale:
            return String(format: "%.2fx", Double(value))
        case .clefVerticalTrim:
            return String(format: "%.0f%%", Double(value * 100))
        case .clefAnchorYOffset:
            // 避免接近 0 的值在 UI 上显示成 -0.00。
            let normalizedValue: CGFloat = abs(value) < 0.005 ? 0 : value
            return String(format: "%+.2f", Double(normalizedValue))
        }
    }
}
