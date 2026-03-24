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
        let sliders = StaffSliderControlItem.ID.allCases
            .filter { $0.sectionID == id }
            .map {
                makeSlider(
                    for: $0,
                    displayState: displayState
                )
            }

        guard !sliders.isEmpty else {
            return nil
        }

        return StaffControlSection(
            id: id,
            title: id.title,
            sliders: sliders
        )
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
            displayValue: displayValue(for: clampedValue),
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
        case .trebleClefAnchorYOffset:
            return displayState.configuration.trebleClefAnchorLogicalDownwardShiftRatio
        }
    }

    private static func isEnabled(
        for sliderID: StaffSliderControlItem.ID,
        displayState _: StaffDisplayState
    ) -> Bool {
        switch sliderID {
        case .trebleClefAnchorYOffset:
            return true
        }
    }

    private static func displayValue(for value: CGFloat) -> String {
        // 避免接近 0 的值在 UI 上显示成 -0.00。
        let normalizedValue: CGFloat = abs(value) < 0.005 ? 0 : value
        return String(format: "%+.2f", Double(normalizedValue))
    }
}
