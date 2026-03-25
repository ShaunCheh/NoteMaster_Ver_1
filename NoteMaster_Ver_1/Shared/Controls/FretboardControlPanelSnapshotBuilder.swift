//
//  FretboardControlPanelSnapshotBuilder.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/25.
//

import Foundation
import CoreGraphics

enum FretboardControlPanelSnapshotBuilder {
    static func makeModel(from displayState: FretboardDisplayState) -> FretboardControlPanelModel {
        guard displayState.displayMode == .vertical else {
            return .empty
        }

        return FretboardControlPanelModel(
            sections: FretboardControlSectionID.allCases.compactMap {
                makeSection(
                    id: $0,
                    displayState: displayState
                )
            }
        )
    }

    private static func makeSection(
        id: FretboardControlSectionID,
        displayState: FretboardDisplayState
    ) -> FretboardControlSection? {
        let rows = makeRows(
            for: id,
            displayState: displayState
        )

        guard !rows.isEmpty else {
            return nil
        }

        return FretboardControlSection(
            id: id,
            title: id.title,
            rows: rows
        )
    }

    private static func makeRows(
        for sectionID: FretboardControlSectionID,
        displayState: FretboardDisplayState
    ) -> [FretboardControlRow] {
        FretboardSliderControlItem.ID.allCases
            .filter { $0.sectionID == sectionID }
            .map {
                FretboardControlRow.slider(
                    makeSlider(
                        for: $0,
                        displayState: displayState
                    )
                )
            }
    }

    private static func makeSlider(
        for sliderID: FretboardSliderControlItem.ID,
        displayState: FretboardDisplayState
    ) -> FretboardSliderControlItem {
        let range = sliderID.range
        let value = resolvedValue(
            for: sliderID,
            displayState: displayState
        )
        let clampedValue = min(max(value, range.lowerBound), range.upperBound)

        return FretboardSliderControlItem(
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
        for sliderID: FretboardSliderControlItem.ID,
        displayState: FretboardDisplayState
    ) -> CGFloat {
        switch sliderID {
        case .verticalHostHeightRatio:
            return displayState.verticalHostHeightRatio
        }
    }

    private static func isEnabled(
        for sliderID: FretboardSliderControlItem.ID,
        displayState: FretboardDisplayState
    ) -> Bool {
        switch sliderID {
        case .verticalHostHeightRatio:
            return displayState.displayMode == .vertical
        }
    }

    private static func displayValue(
        for sliderID: FretboardSliderControlItem.ID,
        value: CGFloat
    ) -> String {
        switch sliderID {
        case .verticalHostHeightRatio:
            return String(format: "%.0f%%", Double(value * 100))
        }
    }
}
