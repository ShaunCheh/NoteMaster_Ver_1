//
//  StaffConfiguration.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/24.
//

import CoreGraphics

// 显式保留未来的 glyph 后端切换点；阶段 1/4 仍默认回落到 CoreText。
enum MusicGlyphRenderMode: Equatable, Sendable {
    case automatic
    case coreText
    case cgPath
}

enum StaffClef: CaseIterable, Equatable, Hashable, Sendable {
    case treble
    case bass

    var title: String {
        switch self {
        case .treble:
            return "Treble"
        case .bass:
            return "Bass"
        }
    }
}

struct StaffConfiguration: Equatable, Sendable {
    struct DebugOptions: Equatable, Sendable {
        // 调试开关只表达“要不要看包围框/锚点”等调试信息，不把具体绘制实现泄漏到控制器层。
        var showsClefBounds: Bool
        var clefBoundsLineWidth: CGFloat
        var showsClefAnchor: Bool
        var clefAnchorLineWidth: CGFloat
        var clefAnchorCrossHalfLength: CGFloat

        static let `default` = DebugOptions()

        init(
            showsClefBounds: Bool = false,
            clefBoundsLineWidth: CGFloat = 1,
            showsClefAnchor: Bool = false,
            clefAnchorLineWidth: CGFloat = 1,
            clefAnchorCrossHalfLength: CGFloat = 4
        ) {
            self.showsClefBounds = showsClefBounds
            self.clefBoundsLineWidth = max(clefBoundsLineWidth, 0.5)
            self.showsClefAnchor = showsClefAnchor
            self.clefAnchorLineWidth = max(clefAnchorLineWidth, 0.5)
            self.clefAnchorCrossHalfLength = max(clefAnchorCrossHalfLength, 2)
        }
    }

    struct LayoutMetrics: Equatable, Sendable {
        var horizontalInsetRatio: CGFloat
        var verticalInsetRatio: CGFloat
        var staffLineCount: Int
        // 相邻两条 staff line 之间的垂直距离。
        var staffSpaceHeight: CGFloat
        var clefAreaWidthRatio: CGFloat
        var staffLineWidth: CGFloat
        // clef 的目标高度相对于 staff 高度的比例。
        var clefScale: CGFloat

        static let `default` = LayoutMetrics(
            horizontalInsetRatio: 0.08,
            verticalInsetRatio: 0.18,
            staffLineCount: 5,
            staffSpaceHeight: 12,
            clefAreaWidthRatio: 0.22,
            staffLineWidth: 1,
            clefScale: 4
        )

        private static let minimumLayoutFactor: CGFloat = 0.01

        var normalizedStaffLineCount: Int {
            max(staffLineCount, 2)
        }

        var normalizedStaffSpaceHeight: CGFloat {
            max(staffSpaceHeight, 1)
        }

        func staffHeight() -> CGFloat {
            CGFloat(normalizedStaffLineCount - 1) * normalizedStaffSpaceHeight
        }

        // 当字体资源不可用时，回落到旧的保守高度策略，避免 intrinsic size 失效。
        private func legacyMinimumDrawingHeight() -> CGFloat {
            let resolvedStaffHeight = staffHeight()
            return max(resolvedStaffHeight, resolvedStaffHeight * max(clefScale, 1))
        }

        func defaultClefLayoutInsets(for clef: StaffClef) -> StaffClefLayoutInsets? {
            StaffClefLayoutGuide.defaultLayoutInsets(
                for: clef,
                staffHeight: staffHeight(),
                staffSpaceHeight: normalizedStaffSpaceHeight,
                clefScale: clefScale
            )
        }

        // 默认高度改为基于“默认 clef 裁后可见 extents”反推，而不是把额外空间在五线上下对称摊开。
        func minimumDrawingHeight(for clef: StaffClef) -> CGFloat {
            let resolvedStaffHeight = staffHeight()

            guard let layoutInsets = defaultClefLayoutInsets(for: clef) else {
                return legacyMinimumDrawingHeight()
            }

            return max(
                resolvedStaffHeight + layoutInsets.top + layoutInsets.bottom,
                resolvedStaffHeight
            )
        }

        func preferredHeight(for clef: StaffClef) -> CGFloat {
            let drawingFactor = max(
                1 - (verticalInsetRatio * 2),
                Self.minimumLayoutFactor
            )
            return minimumDrawingHeight(for: clef) / drawingFactor
        }
    }

    // Shared/Staff 统一约定使用左上原点、y 向下的逻辑坐标。
    var canvasOrientation: StaffCanvasOrientation
    var clef: StaffClef
    var renderMode: MusicGlyphRenderMode
    var layoutMetrics: LayoutMetrics
    // 以共享逻辑坐标语义描述各 clef 的 glyph 内部锚点下移比例；正值表示向下。
    var trebleClefAnchorLogicalDownwardShiftRatio: CGFloat
    var bassClefAnchorLogicalDownwardShiftRatio: CGFloat
    // 以共享逻辑坐标语义描述各 clef 在 optical bounds 上下两侧各自裁切的比例。
    var trebleClefVerticalTrimRatio: CGFloat
    var bassClefVerticalTrimRatio: CGFloat
    var debugOptions: DebugOptions

    init(
        canvasOrientation: StaffCanvasOrientation = .standard,
        clef: StaffClef = .treble,
        renderMode: MusicGlyphRenderMode = .automatic,
        layoutMetrics: LayoutMetrics = .default,
        trebleClefAnchorLogicalDownwardShiftRatio: CGFloat = 0.06,
        bassClefAnchorLogicalDownwardShiftRatio: CGFloat = 0,
        trebleClefVerticalTrimRatio: CGFloat = 0.2,
        bassClefVerticalTrimRatio: CGFloat = 0.33,
        debugOptions: DebugOptions = .default
    ) {
        self.canvasOrientation = canvasOrientation
        self.clef = clef
        self.renderMode = renderMode
        self.layoutMetrics = layoutMetrics
        self.trebleClefAnchorLogicalDownwardShiftRatio = trebleClefAnchorLogicalDownwardShiftRatio
        self.bassClefAnchorLogicalDownwardShiftRatio = bassClefAnchorLogicalDownwardShiftRatio
        self.trebleClefVerticalTrimRatio = trebleClefVerticalTrimRatio
        self.bassClefVerticalTrimRatio = bassClefVerticalTrimRatio
        self.debugOptions = debugOptions
    }

    var preferredHeight: CGFloat {
        layoutMetrics.preferredHeight(for: clef)
    }

    func clefAnchorLogicalDownwardShiftRatio(for clef: StaffClef) -> CGFloat {
        switch clef {
        case .treble:
            return trebleClefAnchorLogicalDownwardShiftRatio
        case .bass:
            return bassClefAnchorLogicalDownwardShiftRatio
        }
    }

    func clefVerticalTrimRatio(for clef: StaffClef) -> CGFloat {
        switch clef {
        case .treble:
            return trebleClefVerticalTrimRatio
        case .bass:
            return bassClefVerticalTrimRatio
        }
    }

    mutating func setClefAnchorLogicalDownwardShiftRatio(
        _ value: CGFloat,
        for clef: StaffClef
    ) {
        switch clef {
        case .treble:
            trebleClefAnchorLogicalDownwardShiftRatio = value
        case .bass:
            bassClefAnchorLogicalDownwardShiftRatio = value
        }
    }

    mutating func setClefVerticalTrimRatio(
        _ value: CGFloat,
        for clef: StaffClef
    ) {
        switch clef {
        case .treble:
            trebleClefVerticalTrimRatio = value
        case .bass:
            bassClefVerticalTrimRatio = value
        }
    }
}
