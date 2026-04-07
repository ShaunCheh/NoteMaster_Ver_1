//
//  PianoInteractionReducer.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/30.
//

import CoreGraphics

struct PianoReduction: Equatable, Sendable {
    var nextState: PianoComponentState
    var semanticEvents: [PianoSemanticEvent]
    var presentationCommand: PianoPresentationCommand?
    var needsDisplay: Bool

    init(
        previousState: PianoComponentState,
        nextState: PianoComponentState,
        semanticEvents: [PianoSemanticEvent],
        presentationCommand: PianoPresentationCommand? = nil
    ) {
        self.nextState = nextState
        self.semanticEvents = semanticEvents
        self.presentationCommand = presentationCommand
        self.needsDisplay = nextState != previousState
            || !semanticEvents.isEmpty
            || presentationCommand != nil
    }

    static func unchanged(
        _ state: PianoComponentState
    ) -> PianoReduction {
        PianoReduction(
            previousState: state,
            nextState: state,
            semanticEvents: []
        )
    }
}

enum PianoInteractionReducer {
    static func reduce(
        state: PianoComponentState,
        rawEvent: PianoRawEvent,
        hitResult: PianoHitResult,
        configuration: PianoConfiguration
    ) -> PianoReduction {
        let hitResult = synchronizedHitResult(
            rawEvent: rawEvent,
            hitResult: hitResult
        )

        switch state.activeInteraction {
        case nil:
            return reduceWithoutActiveInteraction(
                state: state,
                rawEvent: rawEvent,
                hitResult: hitResult
            )
        case let .buttonPressed(interaction):
            return reduceButtonPress(
                interaction,
                state: state,
                hitResult: hitResult,
                configuration: configuration
            )
        case let .scaleDrag(interaction):
            return reduceScaleDrag(
                interaction,
                state: state,
                rawEvent: rawEvent,
                hitResult: hitResult,
                configuration: configuration
            )
        case let .keyGlissando(interaction):
            return reduceKeyGlissando(
                interaction,
                state: state,
                hitResult: hitResult
            )
        }
    }
}

private extension PianoInteractionReducer {
    static func synchronizedHitResult(
        rawEvent: PianoRawEvent,
        hitResult: PianoHitResult
    ) -> PianoHitResult {
        PianoHitResult(
            pointerID: rawEvent.pointerID,
            phase: rawEvent.phase,
            locationInView: rawEvent.locationInView,
            rowIndex: hitResult.rowIndex,
            zone: hitResult.zone,
            note: hitResult.note,
            isInsideActiveZone: hitResult.isInsideActiveZone
        )
    }

    static func reduceWithoutActiveInteraction(
        state: PianoComponentState,
        rawEvent: PianoRawEvent,
        hitResult: PianoHitResult
    ) -> PianoReduction {
        guard rawEvent.phase == .began else {
            return .unchanged(state)
        }

        guard let rowIndex = hitResult.rowIndex,
              let rowState = state.rowState(at: rowIndex) else {
            return .unchanged(state)
        }

        switch hitResult.zone {
        case .buttonLeft, .buttonRight:
            guard let direction = hitResult.buttonDirection else {
                return .unchanged(state)
            }

            var nextState = state
            nextState.activeInteraction = .buttonPressed(
                PianoButtonPressInteraction(
                    pointerID: rawEvent.pointerID,
                    rowIndex: rowIndex,
                    direction: direction,
                    movementScope: rowState.movementScope
                )
            )

            return PianoReduction(
                previousState: state,
                nextState: nextState,
                semanticEvents: []
            )
        case .scale:
            let affectedRowIndices = resolvedAffectedRowIndices(
                rowIndex: rowIndex,
                movementScope: rowState.movementScope,
                rowCount: state.rowCount
            )
            let initialOffsetsX = affectedRowIndices.compactMap {
                state.rowState(at: $0)?.offsetX
            }

            guard affectedRowIndices.count == initialOffsetsX.count else {
                return .unchanged(state)
            }

            var nextState = state
            nextState.activeInteraction = .scaleDrag(
                PianoScaleDragInteraction(
                    pointerID: rawEvent.pointerID,
                    rowIndex: rowIndex,
                    movementScope: rowState.movementScope,
                    beganLocationInView: rawEvent.locationInView,
                    affectedRowIndices: affectedRowIndices,
                    initialOffsetsX: initialOffsetsX
                )
            )

            return PianoReduction(
                previousState: state,
                nextState: nextState,
                semanticEvents: []
            )
        case .keys:
            guard let note = hitResult.note else {
                return .unchanged(state)
            }

            let preview = PianoPreviewState(
                previewID: rawEvent.pointerID.previewID,
                rowIndex: rowIndex,
                note: note
            )

            var nextState = state
            nextState.preview = preview
            nextState.activeInteraction = .keyGlissando(
                PianoKeyGlissandoInteraction(
                    pointerID: rawEvent.pointerID,
                    rowIndex: rowIndex,
                    currentPreview: preview
                )
            )

            return PianoReduction(
                previousState: state,
                nextState: nextState,
                semanticEvents: [.previewStarted(preview)]
            )
        case .outside:
            return .unchanged(state)
        }
    }

    static func reduceButtonPress(
        _ interaction: PianoButtonPressInteraction,
        state: PianoComponentState,
        hitResult: PianoHitResult,
        configuration: PianoConfiguration
    ) -> PianoReduction {
        switch hitResult.phase {
        case .began:
            return .unchanged(state)
        case .moved:
            let isTrackingInsideButton = hitResult.rowIndex == interaction.rowIndex
                && hitResult.buttonDirection == interaction.direction
            guard isTrackingInsideButton != interaction.isTrackingInsideButton else {
                return .unchanged(state)
            }

            var nextState = state
            nextState.activeInteraction = .buttonPressed(
                PianoButtonPressInteraction(
                    pointerID: interaction.pointerID,
                    rowIndex: interaction.rowIndex,
                    direction: interaction.direction,
                    movementScope: interaction.movementScope,
                    isTrackingInsideButton: isTrackingInsideButton
                )
            )

            return PianoReduction(
                previousState: state,
                nextState: nextState,
                semanticEvents: []
            )
        case .ended:
            return finalizeButtonPress(
                interaction,
                state: state,
                endedInsideSameButton: hitResult.rowIndex == interaction.rowIndex
                    && hitResult.buttonDirection == interaction.direction,
                configuration: configuration
            )
        case .cancelled:
            var nextState = state
            nextState.activeInteraction = nil
            return PianoReduction(
                previousState: state,
                nextState: nextState,
                semanticEvents: []
            )
        }
    }

    static func finalizeButtonPress(
        _ interaction: PianoButtonPressInteraction,
        state: PianoComponentState,
        endedInsideSameButton: Bool,
        configuration: PianoConfiguration
    ) -> PianoReduction {
        let presentationCommand: PianoPresentationCommand?
        if endedInsideSameButton {
            let fromRows = state.rows
            let toRows = applyButtonStep(
                fromRows,
                triggerRowIndex: interaction.rowIndex,
                direction: interaction.direction,
                movementScope: interaction.movementScope,
                configuration: configuration
            )

            if toRows != fromRows {
                presentationCommand = .animateRowsTransition(
                    PianoRowsTransitionPlan(
                        fromRows: fromRows,
                        toRows: toRows,
                        affectedRowIndices: resolvedAffectedRowIndices(
                            rowIndex: interaction.rowIndex,
                            movementScope: interaction.movementScope,
                            rowCount: state.rowCount
                        )
                    )
                )
            } else {
                presentationCommand = nil
            }
        } else {
            presentationCommand = nil
        }

        var nextState = state
        nextState.activeInteraction = nil
        return PianoReduction(
            previousState: state,
            nextState: nextState,
            semanticEvents: [],
            presentationCommand: presentationCommand
        )
    }

    static func reduceScaleDrag(
        _ interaction: PianoScaleDragInteraction,
        state: PianoComponentState,
        rawEvent: PianoRawEvent,
        hitResult: PianoHitResult,
        configuration: PianoConfiguration
    ) -> PianoReduction {
        switch hitResult.phase {
        case .began:
            return .unchanged(state)
        case .moved:
            if hitResult.rowIndex == interaction.rowIndex,
               hitResult.zone == .scale {
                let nextRows = applyScaleDrag(
                    rows: state.rows,
                    interaction: interaction,
                    currentLocationInView: rawEvent.locationInView
                )

                guard nextRows != state.rows else {
                    return .unchanged(state)
                }

                var nextState = state
                nextState.rows = nextRows
                return PianoReduction(
                    previousState: state,
                    nextState: nextState,
                    semanticEvents: [.rowsChanged(nextRows)]
                )
            }

            return finalizeScaleDrag(
                interaction,
                state: state,
                configuration: configuration,
                finalRows: state.rows
            )
        case .ended:
            let finalRows: [PianoRowState]
            if hitResult.rowIndex == interaction.rowIndex,
               hitResult.zone == .scale {
                finalRows = applyScaleDrag(
                    rows: state.rows,
                    interaction: interaction,
                    currentLocationInView: rawEvent.locationInView
                )
            } else {
                finalRows = state.rows
            }

            return finalizeScaleDrag(
                interaction,
                state: state,
                configuration: configuration,
                finalRows: finalRows
            )
        case .cancelled:
            return finalizeScaleDrag(
                interaction,
                state: state,
                configuration: configuration,
                finalRows: state.rows
            )
        }
    }

    static func reduceKeyGlissando(
        _ interaction: PianoKeyGlissandoInteraction,
        state: PianoComponentState,
        hitResult: PianoHitResult
    ) -> PianoReduction {
        switch hitResult.phase {
        case .began:
            return .unchanged(state)
        case .moved:
            if hitResult.rowIndex == interaction.rowIndex,
               hitResult.zone == .keys,
               let note = hitResult.note {
                let nextPreview = PianoPreviewState(
                    previewID: interaction.currentPreview.previewID,
                    rowIndex: interaction.rowIndex,
                    note: note
                )
                guard nextPreview != interaction.currentPreview else {
                    return .unchanged(state)
                }

                var nextState = state
                nextState.preview = nextPreview
                nextState.activeInteraction = .keyGlissando(
                    PianoKeyGlissandoInteraction(
                        pointerID: interaction.pointerID,
                        rowIndex: interaction.rowIndex,
                        currentPreview: nextPreview
                    )
                )

                return PianoReduction(
                    previousState: state,
                    nextState: nextState,
                    semanticEvents: [.previewChanged(nextPreview)]
                )
            }

            return endPreview(
                state: state,
                preview: interaction.currentPreview
            )
        case .ended:
            if hitResult.rowIndex == interaction.rowIndex,
               hitResult.zone == .keys,
               let note = hitResult.note,
               note != interaction.currentPreview.note {
                let finalPreview = PianoPreviewState(
                    previewID: interaction.currentPreview.previewID,
                    rowIndex: interaction.rowIndex,
                    note: note
                )

                var nextState = state
                nextState.preview = nil
                nextState.activeInteraction = nil

                return PianoReduction(
                    previousState: state,
                    nextState: nextState,
                    semanticEvents: [
                        .previewChanged(finalPreview),
                        .previewEnded(finalPreview)
                    ]
                )
            }

            return endPreview(
                state: state,
                preview: interaction.currentPreview
            )
        case .cancelled:
            return endPreview(
                state: state,
                preview: interaction.currentPreview
            )
        }
    }

    static func endPreview(
        state: PianoComponentState,
        preview: PianoPreviewState
    ) -> PianoReduction {
        var nextState = state
        nextState.preview = nil
        nextState.activeInteraction = nil

        return PianoReduction(
            previousState: state,
            nextState: nextState,
            semanticEvents: [.previewEnded(preview)]
        )
    }

    static func finalizeScaleDrag(
        _ interaction: PianoScaleDragInteraction,
        state: PianoComponentState,
        configuration: PianoConfiguration,
        finalRows: [PianoRowState]
    ) -> PianoReduction {
        let resolvedRows: [PianoRowState]
        let presentationCommand: PianoPresentationCommand?
        if configuration.snapEnabled {
            let snappedRows = normalizeRowsAfterScaleDrag(
                finalRows,
                interaction: interaction,
                configuration: configuration
            )
            resolvedRows = finalRows
            if snappedRows != finalRows {
                presentationCommand = .animateRowsTransition(
                    PianoRowsTransitionPlan(
                        fromRows: finalRows,
                        toRows: snappedRows,
                        affectedRowIndices: interaction.affectedRowIndices
                    )
                )
            } else {
                presentationCommand = nil
            }
        } else {
            resolvedRows = finalRows
            presentationCommand = nil
        }

        var nextState = state
        nextState.rows = resolvedRows
        nextState.activeInteraction = nil

        var semanticEvents: [PianoSemanticEvent] = []
        if resolvedRows != state.rows {
            semanticEvents.append(.rowsChanged(resolvedRows))
        }

        return PianoReduction(
            previousState: state,
            nextState: nextState,
            semanticEvents: semanticEvents,
            presentationCommand: presentationCommand
        )
    }

    static func applyButtonStep(
        _ rows: [PianoRowState],
        triggerRowIndex: Int,
        direction: PianoStepDirection,
        movementScope: PianoMovementScope,
        configuration: PianoConfiguration
    ) -> [PianoRowState] {
        let affectedRowIndices = resolvedAffectedRowIndices(
            rowIndex: triggerRowIndex,
            movementScope: movementScope,
            rowCount: rows.count
        )
        guard !affectedRowIndices.isEmpty else {
            return rows
        }

        var nextRows = rows
        for rowIndex in affectedRowIndices {
            guard nextRows.indices.contains(rowIndex) else {
                continue
            }

            let normalizedRow = normalizedRowStateForSnap(
                nextRows[rowIndex],
                configuration: configuration
            )
            nextRows[rowIndex] = normalizedRow.shiftedStartNote(
                by: direction.semitoneDelta
            )
        }

        return nextRows
    }

    static func applyScaleDrag(
        rows: [PianoRowState],
        interaction: PianoScaleDragInteraction,
        currentLocationInView: CGPoint
    ) -> [PianoRowState] {
        let deltaX = currentLocationInView.x - interaction.beganLocationInView.x
        var nextRows = rows

        for (offsetIndex, rowIndex) in interaction.affectedRowIndices.enumerated() {
            guard nextRows.indices.contains(rowIndex),
                  interaction.initialOffsetsX.indices.contains(offsetIndex) else {
                continue
            }

            // Pointer drag uses direct-manipulation semantics: dragging right moves the
            // keyboard content right, which means the internal left-edge offset decreases.
            nextRows[rowIndex].offsetX = interaction.initialOffsetsX[offsetIndex] - deltaX
        }

        return nextRows
    }

    static func normalizeRowsAfterScaleDrag(
        _ rows: [PianoRowState],
        interaction: PianoScaleDragInteraction,
        configuration: PianoConfiguration
    ) -> [PianoRowState] {
        var nextRows = rows

        for rowIndex in interaction.affectedRowIndices {
            guard nextRows.indices.contains(rowIndex) else {
                continue
            }

            nextRows[rowIndex] = normalizedRowStateForSnap(
                nextRows[rowIndex],
                configuration: configuration
            )
        }

        return nextRows
    }

    static func normalizedRowStateForSnap(
        _ rowState: PianoRowState,
        configuration: PianoConfiguration
    ) -> PianoRowState {
        let snapTarget = PianoLayoutMath.nearestSnapTarget(
            for: rowState,
            configuration: configuration
        )

        return PianoRowState(
            startNote: snapTarget.note,
            offsetX: 0,
            movementScope: rowState.movementScope
        )
    }

    static func resolvedAffectedRowIndices(
        rowIndex: Int,
        movementScope: PianoMovementScope,
        rowCount: Int
    ) -> [Int] {
        guard rowCount > 0 else {
            return []
        }

        switch movementScope {
        case .rowOnly:
            guard (0..<rowCount).contains(rowIndex) else {
                return []
            }
            return [rowIndex]
        case .cascade:
            return Array(0..<rowCount)
        }
    }
}
