//
//  FretboardConfiguration.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/19.
//

import CoreGraphics

struct FretboardConfiguration: Equatable, Sendable {
    struct LayoutMetrics: Equatable, Sendable {
        var horizontalInsetRatio: CGFloat
        var verticalInsetRatio: CGFloat
        // 宽度优先链路的真相来源：单个显示格子的宽高比（width / height）。
        var cellWidthToHeightRatio: CGFloat
        // 兼容旧的固定弦高链路；后续平台尺寸出口迁移完成后移除。
        var stringLaneHeight: CGFloat
        var nutWidthRatio: CGFloat
        var fretLineWidth: CGFloat
        var stringLineWidth: CGFloat
        var markerDiameterRatio: CGFloat
        var doubleMarkerOffsetRatio: CGFloat

        static let `default` = LayoutMetrics(
            horizontalInsetRatio: 0.04,
            verticalInsetRatio: 0.16,
            cellWidthToHeightRatio: 1.6,
            stringLaneHeight: 17,
            nutWidthRatio: 0.014,
            fretLineWidth: 1,
            stringLineWidth: 1.5,
            markerDiameterRatio: 0.15,
            doubleMarkerOffsetRatio: 0.18
        )

        private static let minimumLayoutFactor: CGFloat = 0.01
        private static let minimumAspectRatio: CGFloat = 0.01

        private var drawingWidthFactor: CGFloat {
            max(1 - (horizontalInsetRatio * 2), Self.minimumLayoutFactor)
        }

        private var drawingHeightFactor: CGFloat {
            max(1 - (verticalInsetRatio * 2), Self.minimumLayoutFactor)
        }

        private var resolvedCellWidthToHeightRatio: CGFloat {
            max(cellWidthToHeightRatio, Self.minimumAspectRatio)
        }

        func drawingWidth(forAvailableWidth width: CGFloat) -> CGFloat {
            max(width, 0) * drawingWidthFactor
        }

        func cellWidth(
            forAvailableWidth width: CGFloat,
            displayPositionCount: Int
        ) -> CGFloat {
            let resolvedDisplayPositionCount = max(displayPositionCount, 1)
            return drawingWidth(forAvailableWidth: width) / CGFloat(resolvedDisplayPositionCount)
        }

        func cellHeight(
            forAvailableWidth width: CGFloat,
            displayPositionCount: Int
        ) -> CGFloat {
            cellWidth(
                forAvailableWidth: width,
                displayPositionCount: displayPositionCount
            ) / resolvedCellWidthToHeightRatio
        }

        func drawingHeight(
            forAvailableWidth width: CGFloat,
            displayPositionCount: Int,
            stringCount: Int
        ) -> CGFloat {
            CGFloat(max(stringCount, 1)) * cellHeight(
                forAvailableWidth: width,
                displayPositionCount: displayPositionCount
            )
        }

        func totalHeight(
            forAvailableWidth width: CGFloat,
            displayPositionCount: Int,
            stringCount: Int
        ) -> CGFloat {
            drawingHeight(
                forAvailableWidth: width,
                displayPositionCount: displayPositionCount,
                stringCount: stringCount
            ) / drawingHeightFactor
        }

        // horizontal 模式下基于现有宽度优先链路反推总宽度。
        func totalWidth(
            forAvailableHeight height: CGFloat,
            displayPositionCount: Int,
            stringCount: Int
        ) -> CGFloat {
            let resolvedHeightToWidthMultiplier = heightToWidthMultiplier(
                displayPositionCount: displayPositionCount,
                stringCount: stringCount
            )
            guard resolvedHeightToWidthMultiplier > 0 else {
                return 0
            }

            return max(height, 0) / resolvedHeightToWidthMultiplier
        }

        func heightToWidthMultiplier(
            displayPositionCount: Int,
            stringCount: Int
        ) -> CGFloat {
            let resolvedDisplayPositionCount = max(displayPositionCount, 1)
            let resolvedStringCount = max(stringCount, 1)
            return drawingWidthFactor
                / drawingHeightFactor
                * CGFloat(resolvedStringCount)
                / (CGFloat(resolvedDisplayPositionCount) * resolvedCellWidthToHeightRatio)
        }

        func widthToHeightMultiplier(
            displayPositionCount: Int,
            stringCount: Int
        ) -> CGFloat {
            let resolvedHeightToWidthMultiplier = heightToWidthMultiplier(
                displayPositionCount: displayPositionCount,
                stringCount: stringCount
            )
            guard resolvedHeightToWidthMultiplier > 0 else {
                return 0
            }

            return 1 / resolvedHeightToWidthMultiplier
        }

        func verticalWidthToHeightMultiplier(
            displayPositionCount: Int,
            stringCount: Int
        ) -> CGFloat {
            let resolvedDisplayPositionCount = max(displayPositionCount, 1)
            let resolvedStringCount = max(stringCount, 1)
            // 竖向局部横滚语义下，绿色边界代表真实内容矩形：
            // 指板内容应优先吃满整个可见高度，因此这里只保留左右 inset，
            // 不再把上下 inset 也折进 width/height 倍率，否则内容宽度充足时仍会保留上下 letterbox。
            return CGFloat(resolvedStringCount)
                / (drawingWidthFactor
                    * CGFloat(resolvedDisplayPositionCount)
                    * resolvedCellWidthToHeightRatio)
        }

        func verticalHeightToWidthMultiplier(
            displayPositionCount: Int,
            stringCount: Int
        ) -> CGFloat {
            let resolvedWidthToHeightMultiplier = verticalWidthToHeightMultiplier(
                displayPositionCount: displayPositionCount,
                stringCount: stringCount
            )
            guard resolvedWidthToHeightMultiplier > 0 else {
                return 0
            }

            return 1 / resolvedWidthToHeightMultiplier
        }

        func verticalTotalWidth(
            forAvailableHeight height: CGFloat,
            displayPositionCount: Int,
            stringCount: Int
        ) -> CGFloat {
            max(height, 0) * verticalWidthToHeightMultiplier(
                displayPositionCount: displayPositionCount,
                stringCount: stringCount
            )
        }

        // vertical 局部横滚场景下，高度来自页面分配；这里显式表达“给定视口高度时，整把指板内容需要的总宽度”。
        func verticalContentWidth(
            forViewportHeight viewportHeight: CGFloat,
            displayPositionCount: Int,
            stringCount: Int
        ) -> CGFloat {
            verticalTotalWidth(
                forAvailableHeight: viewportHeight,
                displayPositionCount: displayPositionCount,
                stringCount: stringCount
            )
        }

        func verticalTotalHeight(
            forAvailableWidth width: CGFloat,
            displayPositionCount: Int,
            stringCount: Int
        ) -> CGFloat {
            max(width, 0) * verticalHeightToWidthMultiplier(
                displayPositionCount: displayPositionCount,
                stringCount: stringCount
            )
        }

        // 当平台层拿到某个竖向内容宽度时，可通过这条反向链路恢复保持同一比例所需的内容高度。
        func verticalContentHeight(
            forContentWidth contentWidth: CGFloat,
            displayPositionCount: Int,
            stringCount: Int
        ) -> CGFloat {
            verticalTotalHeight(
                forAvailableWidth: contentWidth,
                displayPositionCount: displayPositionCount,
                stringCount: stringCount
            )
        }

        func legacyPreferredHeight(forStringCount stringCount: Int) -> CGFloat {
            let stringBandHeight = CGFloat(max(stringCount, 1)) * max(stringLaneHeight, 1)
            return stringBandHeight / drawingHeightFactor
        }
    }

    struct MarkerLayout: Equatable, Sendable {
        var singleDotFrets: [Int]
        var doubleDotFrets: [Int]

        static let standard = MarkerLayout(
            singleDotFrets: [3, 5, 7, 9],
            doubleDotFrets: [12]
        )

        func allMarkerFrets(upTo maxFret: Int) -> [Int] {
            Array(Set(
                normalizedSingleDotFrets(upTo: maxFret)
                + normalizedDoubleDotFrets(upTo: maxFret)
            )).sorted()
        }

        func normalizedSingleDotFrets(upTo maxFret: Int) -> [Int] {
            Self.normalize(singleDotFrets, maxFret: maxFret)
        }

        func normalizedDoubleDotFrets(upTo maxFret: Int) -> [Int] {
            Self.normalize(doubleDotFrets, maxFret: maxFret)
        }

        private static func normalize(_ frets: [Int], maxFret: Int) -> [Int] {
            Array(Set(frets.filter { $0 > 0 && $0 <= maxFret })).sorted()
        }
    }

    struct VerticalContentLayout: Equatable, Sendable {
        var viewportHeight: CGFloat
        var contentWidth: CGFloat

        var contentSize: CGSize {
            CGSize(
                width: contentWidth,
                height: viewportHeight
            )
        }
    }

    // 运行期配置以 tuning 为真相来源，instrument 由 tuning 派生。
    var displayMode: FretboardDisplayMode
    var tuning: InstrumentTuning
    var maxFret: Int
    var layoutMetrics: LayoutMetrics
    var markerLayout: MarkerLayout

    init(
        displayMode: FretboardDisplayMode = .horizontal,
        tuning: InstrumentTuning = .standard(for: .guitar6),
        maxFret: Int = 12,
        layoutMetrics: LayoutMetrics = .default,
        markerLayout: MarkerLayout = .standard
    ) {
        self.displayMode = displayMode
        self.tuning = tuning
        self.maxFret = max(0, maxFret)
        self.layoutMetrics = layoutMetrics
        self.markerLayout = markerLayout
    }

    init(
        instrument: InstrumentType,
        displayMode: FretboardDisplayMode = .horizontal,
        maxFret: Int = 12,
        layoutMetrics: LayoutMetrics = .default,
        markerLayout: MarkerLayout = .standard
    ) {
        self.init(
            displayMode: displayMode,
            tuning: .standard(for: instrument),
            maxFret: maxFret,
            layoutMetrics: layoutMetrics,
            markerLayout: markerLayout
        )
    }

    var instrument: InstrumentType {
        tuning.instrument
    }

    var fretRange: ClosedRange<Int> {
        0...maxFret
    }

    var stringCount: Int {
        tuning.stringCount
    }

    var displayPositionCount: Int {
        maxFret + 1
    }

    func notePitch(
        stringIndex: Int,
        fret: Int
    ) -> NotePitch? {
        guard
            (0..<stringCount).contains(stringIndex),
            fretRange.contains(fret)
        else {
            return nil
        }

        return tuning.notePitch(
            stringIndex: stringIndex,
            fret: fret
        )
    }

    func notePitch(for cell: FretboardCell) -> NotePitch? {
        notePitch(
            stringIndex: cell.stringIndex,
            fret: cell.fret
        )
    }

    func pitchClass(
        stringIndex: Int,
        fret: Int
    ) -> PitchClass? {
        notePitch(
            stringIndex: stringIndex,
            fret: fret
        )?.pitchClass
    }

    func pitchClass(for cell: FretboardCell) -> PitchClass? {
        notePitch(for: cell)?.pitchClass
    }

    // 竖向局部横滚阶段的共享尺寸真相：页面决定可见高度，shared 几何反推出整把指板内容宽度。
    func verticalContentLayout(
        forViewportHeight viewportHeight: CGFloat
    ) -> VerticalContentLayout {
        let resolvedViewportHeight = max(viewportHeight, 0)
        return VerticalContentLayout(
            viewportHeight: resolvedViewportHeight,
            contentWidth: layoutMetrics.verticalContentWidth(
                forViewportHeight: resolvedViewportHeight,
                displayPositionCount: displayPositionCount,
                stringCount: stringCount
            )
        )
    }

    func verticalContentWidth(
        forViewportHeight viewportHeight: CGFloat
    ) -> CGFloat {
        verticalContentLayout(forViewportHeight: viewportHeight).contentWidth
    }

    func verticalContentHeight(
        forContentWidth contentWidth: CGFloat
    ) -> CGFloat {
        layoutMetrics.verticalContentHeight(
            forContentWidth: contentWidth,
            displayPositionCount: displayPositionCount,
            stringCount: stringCount
        )
    }

    func resolvedHeight(forAvailableWidth width: CGFloat) -> CGFloat {
        switch displayMode {
        case .horizontal:
            return layoutMetrics.totalHeight(
                forAvailableWidth: width,
                displayPositionCount: displayPositionCount,
                stringCount: stringCount
            )
        case .vertical:
            // 兼容当前平台层旧调用；后续竖向局部横滚新链路应优先使用 verticalContentHeight / Layout。
            return verticalContentHeight(forContentWidth: width)
        }
    }

    func resolvedWidth(forAvailableHeight height: CGFloat) -> CGFloat {
        switch displayMode {
        case .horizontal:
            return layoutMetrics.totalWidth(
                forAvailableHeight: height,
                displayPositionCount: displayPositionCount,
                stringCount: stringCount
            )
        case .vertical:
            // 兼容当前平台层旧调用；后续竖向局部横滚新链路应优先使用 verticalContentWidth / Layout。
            return verticalContentWidth(forViewportHeight: height)
        }
    }

    var heightToWidthMultiplier: CGFloat {
        switch displayMode {
        case .horizontal:
            return layoutMetrics.heightToWidthMultiplier(
                displayPositionCount: displayPositionCount,
                stringCount: stringCount
            )
        case .vertical:
            return layoutMetrics.verticalHeightToWidthMultiplier(
                displayPositionCount: displayPositionCount,
                stringCount: stringCount
            )
        }
    }

    var widthToHeightMultiplier: CGFloat {
        switch displayMode {
        case .horizontal:
            return layoutMetrics.widthToHeightMultiplier(
                displayPositionCount: displayPositionCount,
                stringCount: stringCount
            )
        case .vertical:
            return layoutMetrics.verticalWidthToHeightMultiplier(
                displayPositionCount: displayPositionCount,
                stringCount: stringCount
            )
        }
    }

    // 作为 zero-bounds 回退值保留，避免 Auto Layout 首轮询问 intrinsic 时得到 0。
    var preferredHeight: CGFloat {
        layoutMetrics.legacyPreferredHeight(forStringCount: stringCount)
    }
}
