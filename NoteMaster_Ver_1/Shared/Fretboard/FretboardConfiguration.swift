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
        var stringEdgeInsetRatio: CGFloat
        // 每根弦占据的垂直车道高度，弦位应落在车道中心。
        var stringLaneHeight: CGFloat
        var nutWidthRatio: CGFloat
        var fretLineWidth: CGFloat
        var stringLineWidth: CGFloat
        var markerDiameterRatio: CGFloat
        var doubleMarkerOffsetRatio: CGFloat

        static let `default` = LayoutMetrics(
            horizontalInsetRatio: 0.04,
            verticalInsetRatio: 0.16,
            stringEdgeInsetRatio: 0.09,
            stringLaneHeight: 17,
            nutWidthRatio: 0.014,
            fretLineWidth: 1,
            stringLineWidth: 1.5,
            markerDiameterRatio: 0.15,
            doubleMarkerOffsetRatio: 0.18
        )

        private static let minimumLayoutFactor: CGFloat = 0.01

        func stringBandHeight(forStringCount stringCount: Int) -> CGFloat {
            CGFloat(max(stringCount, 1)) * max(stringLaneHeight, 1)
        }

        func drawingHeight(forStringCount stringCount: Int) -> CGFloat {
            let stringBandHeight = stringBandHeight(forStringCount: stringCount)
            let stringBandFactor = max(
                1 - (stringEdgeInsetRatio * 2),
                Self.minimumLayoutFactor
            )
            return stringBandHeight / stringBandFactor
        }

        func preferredHeight(forStringCount stringCount: Int) -> CGFloat {
            let drawingHeight = drawingHeight(forStringCount: stringCount)
            let drawingFactor = max(
                1 - (verticalInsetRatio * 2),
                Self.minimumLayoutFactor
            )
            return drawingHeight / drawingFactor
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

    var preferredHeight: CGFloat {
        layoutMetrics.preferredHeight(forStringCount: stringCount)
    }
}
