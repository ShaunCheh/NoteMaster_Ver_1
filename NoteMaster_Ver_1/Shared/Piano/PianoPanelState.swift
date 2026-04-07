//
//  PianoPanelState.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/30.
//

import CoreGraphics

struct PianoPanelState: Equatable, Sendable {
    static let supportedRowCountRange: ClosedRange<Int> = 1...8

    var isVisible: Bool
    var rowCount: Int
    var movementScope: PianoMovementScope
    var whiteKeyStyle: PianoWhiteKeyStyle
    var snapEnabled: Bool

    init(
        isVisible: Bool = false,
        rowCount: Int = 3,
        movementScope: PianoMovementScope = .cascade,
        whiteKeyStyle: PianoWhiteKeyStyle = .outlined,
        snapEnabled: Bool = true
    ) {
        self.isVisible = isVisible
        self.rowCount = rowCount
        self.movementScope = movementScope
        self.whiteKeyStyle = whiteKeyStyle
        self.snapEnabled = snapEnabled
    }

    var resolvedRowCount: Int {
        min(
            max(rowCount, Self.supportedRowCountRange.lowerBound),
            Self.supportedRowCountRange.upperBound
        )
    }

    static func inferred(
        configuration: PianoConfiguration,
        rows: [PianoRowState]
    ) -> PianoPanelState {
        PianoPanelState(
            isVisible: false,
            rowCount: min(
                max(rows.count, Self.supportedRowCountRange.lowerBound),
                Self.supportedRowCountRange.upperBound
            ),
            movementScope: rows.first?.movementScope ?? .cascade,
            whiteKeyStyle: configuration.whiteKeyStyle,
            snapEnabled: configuration.snapEnabled
        )
    }

    var settingsSlice: PianoPanelSettingsSlice {
        PianoPanelSettingsSlice(
            rowCount: rowCount,
            movementScope: movementScope,
            whiteKeyStyle: whiteKeyStyle,
            snapEnabled: snapEnabled
        )
    }

    func applyingSettingsSlice(
        _ settingsSlice: PianoPanelSettingsSlice
    ) -> PianoPanelState {
        var nextState = self
        nextState.rowCount = settingsSlice.rowCount
        nextState.movementScope = settingsSlice.movementScope
        nextState.whiteKeyStyle = settingsSlice.whiteKeyStyle
        nextState.snapEnabled = settingsSlice.snapEnabled
        return nextState
    }
}

struct PianoPanelSettingsSlice: Equatable, Sendable {
    var rowCount: Int
    var movementScope: PianoMovementScope
    var whiteKeyStyle: PianoWhiteKeyStyle
    var snapEnabled: Bool

    init(
        rowCount: Int = 3,
        movementScope: PianoMovementScope = .cascade,
        whiteKeyStyle: PianoWhiteKeyStyle = .outlined,
        snapEnabled: Bool = true
    ) {
        self.rowCount = rowCount
        self.movementScope = movementScope
        self.whiteKeyStyle = whiteKeyStyle
        self.snapEnabled = snapEnabled
    }

    init(
        panelState: PianoPanelState
    ) {
        self.init(
            rowCount: panelState.rowCount,
            movementScope: panelState.movementScope,
            whiteKeyStyle: panelState.whiteKeyStyle,
            snapEnabled: panelState.snapEnabled
        )
    }
}

enum PianoPanelProjection {
    private static let fallbackStartNote = NotePitch(
        pitchClass: .c,
        octave: 4
    )

    static func resolvedConfiguration(
        from baseConfiguration: PianoConfiguration,
        panelState: PianoPanelState
    ) -> PianoConfiguration {
        var configuration = baseConfiguration
        configuration.snapEnabled = panelState.snapEnabled
        configuration.whiteKeyStyle = panelState.whiteKeyStyle
        return configuration
    }

    static func resolvedRows(
        from baseRows: [PianoRowState],
        panelState: PianoPanelState
    ) -> [PianoRowState] {
        let targetRowCount = panelState.resolvedRowCount
        let scopedRows = rowsApplyingMovementScope(
            to: baseRows,
            movementScope: panelState.movementScope
        )

        guard !scopedRows.isEmpty else {
            return makeFallbackRows(
                rowCount: targetRowCount,
                movementScope: panelState.movementScope
            )
        }

        if scopedRows.count == targetRowCount {
            return scopedRows
        }

        if scopedRows.count > targetRowCount {
            return Array(scopedRows.prefix(targetRowCount))
        }

        var expandedRows = scopedRows
        while expandedRows.count < targetRowCount {
            expandedRows.append(
                appendedRow(
                    after: expandedRows.last,
                    movementScope: panelState.movementScope
                )
            )
        }
        return expandedRows
    }
}

private extension PianoPanelProjection {
    static func rowsApplyingMovementScope(
        to rows: [PianoRowState],
        movementScope: PianoMovementScope
    ) -> [PianoRowState] {
        rows.map { row in
            var nextRow = row
            nextRow.movementScope = movementScope
            return nextRow
        }
    }

    static func makeFallbackRows(
        rowCount: Int,
        movementScope: PianoMovementScope
    ) -> [PianoRowState] {
        guard rowCount > 0 else {
            return []
        }

        var rows: [PianoRowState] = [
            PianoRowState(
                startNote: fallbackStartNote,
                movementScope: movementScope
            )
        ]

        while rows.count < rowCount {
            rows.append(
                appendedRow(
                    after: rows.last,
                    movementScope: movementScope
                )
            )
        }

        return rows
    }

    static func appendedRow(
        after previousRow: PianoRowState?,
        movementScope: PianoMovementScope
    ) -> PianoRowState {
        let referenceRow = previousRow
            ?? PianoRowState(
                startNote: fallbackStartNote,
                movementScope: movementScope
            )
        return PianoRowState(
            startNote: referenceRow.startNote.advanced(by: -12),
            offsetX: referenceRow.offsetX,
            movementScope: movementScope
        )
    }
}
