//
//  FretboardFeedbackLayer.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/28.
//

import CoreGraphics
import QuartzCore

final class FretboardFeedbackLayer: CALayer {
    var scene: FretboardScene = .empty {
        didSet {
            guard oldValue != scene else {
                return
            }

            setNeedsDisplay()
        }
    }

    var contextNormalizationMode: FretboardContextNormalizationMode = .none {
        didSet {
            guard oldValue != contextNormalizationMode else {
                return
            }

            setNeedsDisplay()
        }
    }

    var feedbackOverlayState: FretboardFeedbackOverlayState = .empty {
        didSet {
            guard oldValue != feedbackOverlayState else {
                return
            }

            setNeedsDisplay()
        }
    }

    override init() {
        super.init()
        configureLayer()
    }

    override init(layer: Any) {
        super.init(layer: layer)

        if let otherLayer = layer as? FretboardFeedbackLayer {
            scene = otherLayer.scene
            contextNormalizationMode = otherLayer.contextNormalizationMode
            feedbackOverlayState = otherLayer.feedbackOverlayState
        }

        configureLayer()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureLayer()
    }

    override func draw(in context: CGContext) {
        context.clear(bounds)
        guard
            !scene.drawingRect.isNull,
            !feedbackOverlayState.isEmpty
        else {
            return
        }

        applyContextNormalizationIfNeeded(in: context)

        context.saveGState()
        context.addPath(displayPath())
        context.clip()

        switch feedbackOverlayState {
        case .empty:
            break
        case let .singleCoverage(correctCells, wrongCell):
            drawSingleCoverageFeedback(
                correctCells: correctCells,
                wrongCell: wrongCell,
                in: context
            )
        case let .positionPrompt(promptCell, phase):
            drawPositionPromptIndicator(
                for: promptCell,
                phase: phase,
                in: context
            )
        }

        context.restoreGState()
    }

    private func configureLayer() {
        isOpaque = false
        drawsAsynchronously = false
        needsDisplayOnBoundsChange = true
    }

    private func applyContextNormalizationIfNeeded(in context: CGContext) {
        contextNormalizationMode.applyIfNeeded(
            to: context,
            in: bounds
        )
    }

    private func drawSingleCoverageFeedback(
        correctCells: Set<FretboardCell>,
        wrongCell: FretboardCell?,
        in context: CGContext
    ) {
        let orderedCorrectCells = correctCells.sorted {
            if $0.stringIndex == $1.stringIndex {
                return $0.fret < $1.fret
            }
            return $0.stringIndex < $1.stringIndex
        }
        for cell in orderedCorrectCells {
            drawFeedback(
                for: cell,
                fillColor: FretboardPalette.feedbackCorrectFill,
                strokeColor: FretboardPalette.feedbackCorrectStroke,
                in: context
            )
        }

        if let wrongCell {
            drawFeedback(
                for: wrongCell,
                fillColor: FretboardPalette.feedbackWrongFill,
                strokeColor: FretboardPalette.feedbackWrongStroke,
                in: context
            )
        }
    }

    private func drawFeedback(
        for cell: FretboardCell,
        fillColor: CGColor,
        strokeColor: CGColor,
        in context: CGContext
    ) {
        guard
            let cellFrame = scene.cellFrame(for: cell),
            !cellFrame.isNull,
            !cellFrame.isEmpty
        else {
            return
        }

        let highlightRect = insetFeedbackRect(for: cellFrame)
        guard !highlightRect.isEmpty else {
            return
        }

        let highlightPath = CGPath(
            roundedRect: highlightRect,
            cornerWidth: resolvedCornerRadius(for: highlightRect),
            cornerHeight: resolvedCornerRadius(for: highlightRect),
            transform: nil
        )

        context.saveGState()
        context.addPath(highlightPath)
        context.setFillColor(fillColor)
        context.fillPath()
        context.addPath(highlightPath)
        context.setStrokeColor(strokeColor)
        context.setLineWidth(resolvedStrokeWidth)
        context.strokePath()
        context.restoreGState()
    }

    private func drawPositionPromptIndicator(
        for cell: FretboardCell,
        phase: FretboardFeedbackOverlayState.PositionPromptPhase,
        in context: CGContext
    ) {
        guard
            let cellFrame = scene.cellFrame(for: cell),
            !cellFrame.isNull,
            !cellFrame.isEmpty
        else {
            return
        }

        let indicatorRect = positionPromptRect(for: cellFrame)
        guard !indicatorRect.isEmpty else {
            return
        }

        let indicatorPath = CGPath(
            ellipseIn: indicatorRect,
            transform: nil
        )
        let colors = colors(for: phase)

        context.saveGState()
        context.addPath(indicatorPath)
        context.setFillColor(colors.fillColor)
        context.fillPath()
        context.addPath(indicatorPath)
        context.setStrokeColor(colors.strokeColor)
        context.setLineWidth(resolvedPositionPromptStrokeWidth)
        context.strokePath()
        context.restoreGState()
    }

    private func insetFeedbackRect(for cellFrame: CGRect) -> CGRect {
        let horizontalInset = max(
            cellFrame.width * Style.horizontalInsetRatio,
            Style.minimumInset
        )
        let verticalInset = max(
            cellFrame.height * Style.verticalInsetRatio,
            Style.minimumInset
        )
        return cellFrame.insetBy(
            dx: horizontalInset,
            dy: verticalInset
        )
    }

    private func positionPromptRect(for cellFrame: CGRect) -> CGRect {
        let minDimension = min(cellFrame.width, cellFrame.height)
        let maxDiameter = max(
            minDimension - (Style.positionPromptMinimumInset * 2),
            0
        )
        let preferredDiameter = minDimension * Style.positionPromptDiameterRatio
        let diameter = min(
            max(preferredDiameter, Style.positionPromptMinimumDiameter),
            maxDiameter
        )

        guard diameter > 0 else {
            return .zero
        }

        return CGRect(
            x: cellFrame.midX - (diameter / 2),
            y: cellFrame.midY - (diameter / 2),
            width: diameter,
            height: diameter
        )
    }

    private func resolvedCornerRadius(for rect: CGRect) -> CGFloat {
        min(rect.width, rect.height) * Style.cornerRadiusRatio
    }

    private var resolvedStrokeWidth: CGFloat {
        max(1 / max(contentsScale, 1), Style.minimumStrokeWidth)
    }

    private var resolvedPositionPromptStrokeWidth: CGFloat {
        max(
            resolvedStrokeWidth * Style.positionPromptStrokeWidthMultiplier,
            Style.minimumStrokeWidth
        )
    }

    private func colors(
        for phase: FretboardFeedbackOverlayState.PositionPromptPhase
    ) -> (fillColor: CGColor, strokeColor: CGColor) {
        switch phase {
        case .neutralWhite:
            return (
                fillColor: FretboardPalette.positionPromptNeutralFill,
                strokeColor: FretboardPalette.positionPromptNeutralStroke
            )
        case .wrongFlash:
            return (
                fillColor: FretboardPalette.positionPromptWrongFill,
                strokeColor: FretboardPalette.positionPromptWrongStroke
            )
        case .correctHold:
            return (
                fillColor: FretboardPalette.positionPromptCorrectFill,
                strokeColor: FretboardPalette.positionPromptCorrectStroke
            )
        }
    }

    private func displayPath() -> CGPath {
        let slotReference = max(
            min(scene.openStringRect.width, scene.openStringRect.height),
            0
        )
        let cornerRadiusReference = slotReference > 0
            ? slotReference
            : min(scene.drawingRect.width, scene.drawingRect.height)
        let cornerRadius = cornerRadiusReference * 0.12

        return CGPath(
            roundedRect: scene.drawingRect,
            cornerWidth: cornerRadius,
            cornerHeight: cornerRadius,
            transform: nil
        )
    }
}

private enum Style {
    static let horizontalInsetRatio: CGFloat = 0.08
    static let verticalInsetRatio: CGFloat = 0.10
    static let cornerRadiusRatio: CGFloat = 0.22
    static let minimumInset: CGFloat = 2
    static let minimumStrokeWidth: CGFloat = 0.75
    static let positionPromptDiameterRatio: CGFloat = 0.62
    static let positionPromptMinimumInset: CGFloat = 3
    static let positionPromptMinimumDiameter: CGFloat = 10
    static let positionPromptStrokeWidthMultiplier: CGFloat = 1.25
}
