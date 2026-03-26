//
//  StaffClefLayoutGuide.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/25.
//

import Foundation
import CoreGraphics
import CoreText

struct StaffClefVisibleExtents: Equatable, Sendable {
    var top: CGFloat
    var bottom: CGFloat

    func scaled(by factor: CGFloat) -> StaffClefVisibleExtents {
        StaffClefVisibleExtents(
            top: top * factor,
            bottom: bottom * factor
        )
    }
}

struct StaffClefHorizontalExtents: Equatable, Sendable {
    var leading: CGFloat
    var trailing: CGFloat
}

struct StaffClefLayoutInsets: Equatable, Sendable {
    var top: CGFloat
    var bottom: CGFloat
}

struct StaffClefAnchorMetrics: Equatable, Sendable {
    var xRatio: CGFloat
    var yRatio: CGFloat
}

enum StaffClefLayoutGuide {
    private static let measurementGlyphHeight: CGFloat = 1000
    static let anchoredTargetWidthRatio: CGFloat = 0.92

    private struct StaffClefMeasuredMetrics: Equatable, Sendable {
        var visibleExtentRatios: StaffClefVisibleExtents
        var opticalWidthToFontSize: CGFloat
        var opticalHeightToFontSize: CGFloat
    }

    private static let lock = NSLock()
    private static var cachedDefaultMeasuredMetrics: [StaffClef: StaffClefMeasuredMetrics] = [:]

    static func defaultLayoutInsets(
        for clef: StaffClef,
        staffHeight: CGFloat,
        staffSpaceHeight: CGFloat,
        clefScale: CGFloat,
        bundle: Bundle = .main
    ) -> StaffClefLayoutInsets? {
        guard staffHeight > 0, staffSpaceHeight > 0 else {
            return nil
        }

        guard let visibleExtentRatios = defaultVisibleExtentRatios(
            for: clef,
            bundle: bundle
        ) else {
            return nil
        }

        let targetHeight = max(staffHeight * max(clefScale, 1), 1)
        let visibleExtents = visibleExtentRatios.scaled(by: targetHeight)
        let anchorOffsetFromStaffTop = min(
            max(CGFloat(clef.anchorLineIndex) * staffSpaceHeight, 0),
            staffHeight
        )
        let anchorOffsetToStaffBottom = max(staffHeight - anchorOffsetFromStaffTop, 0)

        return StaffClefLayoutInsets(
            top: max(visibleExtents.top - anchorOffsetFromStaffTop, 0),
            bottom: max(visibleExtents.bottom - anchorOffsetToStaffBottom, 0)
        )
    }

    static func anchorMetrics(
        for clef: StaffClef,
        downwardShiftRatio: CGFloat
    ) -> StaffClefAnchorMetrics {
        switch clef {
        case .treble:
            // 基于 Bravura treble clef 的 optical bounds 做经验对齐；
            // 逻辑“向下”偏移会体现在 y-up 局部坐标里更小的 yRatio。
            return StaffClefAnchorMetrics(
                xRatio: 0.5,
                yRatio: 0.56 - downwardShiftRatio
            )
        case .bass:
            // bass clef 的语义锚点位于双点之间，因此 xRatio 偏向 glyph 右侧。
            return StaffClefAnchorMetrics(
                xRatio: 0.74,
                yRatio: 0.5 - downwardShiftRatio
            )
        }
    }

    static func defaultHorizontalExtents(
        for clef: StaffClef,
        targetHeight: CGFloat,
        targetWidth: CGFloat,
        downwardShiftRatio: CGFloat,
        bundle: Bundle = .main
    ) -> StaffClefHorizontalExtents? {
        guard targetHeight > 0, targetWidth > 0 else {
            return nil
        }

        guard let measuredMetrics = defaultMeasuredMetrics(
            for: clef,
            bundle: bundle
        ) else {
            return nil
        }

        let baseOpticalWidth = measuredMetrics.opticalWidthToFontSize * targetHeight
        let baseOpticalHeight = measuredMetrics.opticalHeightToFontSize * targetHeight
        let widthScale = targetWidth / max(baseOpticalWidth, 1)
        let heightScale = targetHeight / max(baseOpticalHeight, 1)
        let fitScale = min(
            max(min(widthScale, heightScale), 0.01),
            1
        )
        let resolvedOpticalWidth = baseOpticalWidth * fitScale
        let anchorMetrics = anchorMetrics(
            for: clef,
            downwardShiftRatio: downwardShiftRatio
        )

        return StaffClefHorizontalExtents(
            leading: resolvedOpticalWidth * anchorMetrics.xRatio,
            trailing: resolvedOpticalWidth * (1 - anchorMetrics.xRatio)
        )
    }

    static func trimmedBounds(
        from bounds: CGRect,
        verticalTrimRatio: CGFloat
    ) -> CGRect {
        guard !bounds.isNull, !bounds.isEmpty else {
            return .null
        }

        let clampedTrimRatio = min(max(verticalTrimRatio, 0), 0.45)
        guard clampedTrimRatio > 0 else {
            return bounds
        }

        let maximumInset = max((bounds.height - 1) / 2, 0)
        let inset = min(bounds.height * clampedTrimRatio, maximumInset)
        let trimmedBounds = bounds.insetBy(dx: 0, dy: inset)

        return trimmedBounds.isNull || trimmedBounds.isEmpty ? .null : trimmedBounds
    }

    private static func defaultVisibleExtentRatios(
        for clef: StaffClef,
        bundle: Bundle
    ) -> StaffClefVisibleExtents? {
        defaultMeasuredMetrics(
            for: clef,
            bundle: bundle
        )?.visibleExtentRatios
    }

    private static func defaultMeasuredMetrics(
        for clef: StaffClef,
        bundle: Bundle
    ) -> StaffClefMeasuredMetrics? {
        lock.lock()
        let cachedValue = cachedDefaultMeasuredMetrics[clef]
        lock.unlock()

        if let cachedValue {
            return cachedValue
        }

        guard let measuredValue = measureDefaultMetrics(
            for: clef,
            bundle: bundle
        ) else {
            return nil
        }

        lock.lock()
        cachedDefaultMeasuredMetrics[clef] = measuredValue
        lock.unlock()
        return measuredValue
    }

    private static func measureDefaultMetrics(
        for clef: StaffClef,
        bundle: Bundle
    ) -> StaffClefMeasuredMetrics? {
        guard let font = MusicFontRegistry.font(
            for: clef.musicGlyph.fontFace,
            size: measurementGlyphHeight,
            bundle: bundle
        ) else {
            return nil
        }

        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(rawValue: kCTFontAttributeName as String): font
        ]
        let attributedText = NSAttributedString(
            string: clef.musicGlyph.string,
            attributes: attributes
        )
        let line = CTLineCreateWithAttributedString(attributedText)
        let opticalBounds = CTLineGetBoundsWithOptions(
            line,
            [.useOpticalBounds]
        )
        let defaultConfiguration = StaffConfiguration()
        let clippedBounds = trimmedBounds(
            from: opticalBounds,
            verticalTrimRatio: defaultConfiguration.clefVerticalTrimRatio(for: clef)
        )

        guard
            !opticalBounds.isNull,
            !opticalBounds.isEmpty,
            !clippedBounds.isNull,
            !clippedBounds.isEmpty
        else {
            return nil
        }

        let defaultAnchorMetrics = anchorMetrics(
            for: clef,
            downwardShiftRatio: defaultConfiguration.clefAnchorLogicalDownwardShiftRatio(
                for: clef
            )
        )
        let anchorY = opticalBounds.minY + (opticalBounds.height * defaultAnchorMetrics.yRatio)
        let visibleTop = max(clippedBounds.maxY - anchorY, 0)
        let visibleBottom = max(anchorY - clippedBounds.minY, 0)

        return StaffClefMeasuredMetrics(
            visibleExtentRatios: StaffClefVisibleExtents(
                top: visibleTop / opticalBounds.height,
                bottom: visibleBottom / opticalBounds.height
            ),
            opticalWidthToFontSize: opticalBounds.width / measurementGlyphHeight,
            opticalHeightToFontSize: opticalBounds.height / measurementGlyphHeight
        )
    }
}

extension StaffClef {
    var anchorLineIndex: Int {
        switch self {
        case .treble:
            return 3
        case .bass:
            return 1
        }
    }

    var anchorSemantic: ClefAnchor.Semantic {
        switch self {
        case .treble:
            return .trebleGLine
        case .bass:
            return .bassFLine
        }
    }

    var musicGlyph: MusicGlyph {
        switch self {
        case .treble:
            return .trebleClef
        case .bass:
            return .bassClef
        }
    }
}
