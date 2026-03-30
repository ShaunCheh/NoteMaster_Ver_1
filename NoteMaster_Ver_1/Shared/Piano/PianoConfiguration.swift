//
//  PianoConfiguration.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/30.
//

import CoreGraphics

enum PianoWhiteKeyStyle: Equatable, Sendable {
    case outlined
    case borderlessSeparatedByGaps
    case skeuomorphicHighlight

    var debugName: String {
        switch self {
        case .outlined:
            return "outlined"
        case .borderlessSeparatedByGaps:
            return "gapOnly"
        case .skeuomorphicHighlight:
            return "gloss"
        }
    }
}

struct PianoConfiguration: Equatable, Sendable {
    static let blackKeyWidthRatioRange: ClosedRange<CGFloat> = 0.2...0.95
    static let blackKeyHeightRatioRange: ClosedRange<CGFloat> = 0.2...1

    var whiteKeyWidth: CGFloat
    // rowHeight 表示单行总高度；顶部 A/B 区按上下两条控制区布局。
    var rowHeight: CGFloat
    var rowSpacing: CGFloat
    var scaleAreaHeight: CGFloat
    var buttonAreaWidth: CGFloat
    var blackKeyWidthRatio: CGFloat
    var blackKeyHeightRatio: CGFloat
    var whiteKeyStyle: PianoWhiteKeyStyle
    var snapEnabled: Bool

    init(
        whiteKeyWidth: CGFloat = 44,
        rowHeight: CGFloat = 160,
        rowSpacing: CGFloat = 12,
        scaleAreaHeight: CGFloat = 34,
        buttonAreaWidth: CGFloat = 28,
        blackKeyWidthRatio: CGFloat = 0.62,
        blackKeyHeightRatio: CGFloat = 0.6,
        whiteKeyStyle: PianoWhiteKeyStyle = .outlined,
        snapEnabled: Bool = true
    ) {
        self.whiteKeyWidth = whiteKeyWidth
        self.rowHeight = rowHeight
        self.rowSpacing = rowSpacing
        self.scaleAreaHeight = scaleAreaHeight
        self.buttonAreaWidth = buttonAreaWidth
        self.blackKeyWidthRatio = blackKeyWidthRatio
        self.blackKeyHeightRatio = blackKeyHeightRatio
        self.whiteKeyStyle = whiteKeyStyle
        self.snapEnabled = snapEnabled
    }

    var resolvedWhiteKeyWidth: CGFloat {
        max(whiteKeyWidth, 1)
    }

    var resolvedRowHeight: CGFloat {
        max(rowHeight, 1)
    }

    var resolvedRowSpacing: CGFloat {
        max(rowSpacing, 0)
    }

    var resolvedScaleAreaHeight: CGFloat {
        min(max(scaleAreaHeight, 0), resolvedRowHeight)
    }

    var resolvedButtonStripHeight: CGFloat {
        min(
            resolvedScaleAreaHeight,
            max(resolvedRowHeight - resolvedScaleAreaHeight, 0)
        )
    }

    var resolvedControlAreaHeight: CGFloat {
        resolvedButtonStripHeight + resolvedScaleAreaHeight
    }

    var resolvedButtonAreaWidth: CGFloat {
        max(buttonAreaWidth, 0)
    }

    var resolvedBlackKeyWidthRatio: CGFloat {
        min(
            max(blackKeyWidthRatio, Self.blackKeyWidthRatioRange.lowerBound),
            Self.blackKeyWidthRatioRange.upperBound
        )
    }

    var resolvedBlackKeyHeightRatio: CGFloat {
        min(
            max(blackKeyHeightRatio, Self.blackKeyHeightRatioRange.lowerBound),
            Self.blackKeyHeightRatioRange.upperBound
        )
    }

    var keyAreaHeight: CGFloat {
        max(resolvedRowHeight - resolvedControlAreaHeight, 0)
    }
}
