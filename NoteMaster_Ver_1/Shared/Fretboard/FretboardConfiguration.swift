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

    // 运行期配置以 tuning 为真相来源，instrument 由 tuning 派生。
    var tuning: InstrumentTuning
    var maxFret: Int
    var layoutMetrics: LayoutMetrics
    var markerLayout: MarkerLayout

    init(
        tuning: InstrumentTuning = .standard(for: .guitar6),
        maxFret: Int = 12,
        layoutMetrics: LayoutMetrics = .default,
        markerLayout: MarkerLayout = .standard
    ) {
        self.tuning = tuning
        self.maxFret = max(0, maxFret)
        self.layoutMetrics = layoutMetrics
        self.markerLayout = markerLayout
    }

    init(
        instrument: InstrumentType,
        maxFret: Int = 12,
        layoutMetrics: LayoutMetrics = .default,
        markerLayout: MarkerLayout = .standard
    ) {
        self.init(
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

    func resolvedHeight(forAvailableWidth width: CGFloat) -> CGFloat {
        layoutMetrics.totalHeight(
            forAvailableWidth: width,
            displayPositionCount: displayPositionCount,
            stringCount: stringCount
        )
    }

    var heightToWidthMultiplier: CGFloat {
        layoutMetrics.heightToWidthMultiplier(
            displayPositionCount: displayPositionCount,
            stringCount: stringCount
        )
    }

    // 兼容当前平台尺寸出口；后续阶段改为消费宽度优先的 resolvedHeight/heightToWidthMultiplier。
    var preferredHeight: CGFloat {
        layoutMetrics.legacyPreferredHeight(forStringCount: stringCount)
    }
}
