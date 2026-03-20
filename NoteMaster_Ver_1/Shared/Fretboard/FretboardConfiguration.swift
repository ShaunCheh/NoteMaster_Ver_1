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
        var nutWidthRatio: CGFloat
        var fretLineWidth: CGFloat
        var stringLineWidth: CGFloat
        var markerDiameterRatio: CGFloat
        var doubleMarkerOffsetRatio: CGFloat

        static let `default` = LayoutMetrics(
            horizontalInsetRatio: 0.04,
            verticalInsetRatio: 0.16,
            stringEdgeInsetRatio: 0.09,
            nutWidthRatio: 0.014,
            fretLineWidth: 1,
            stringLineWidth: 1.5,
            markerDiameterRatio: 0.15,
            doubleMarkerOffsetRatio: 0.18
        )
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
    var preferredHeight: CGFloat
    var layoutMetrics: LayoutMetrics
    var markerLayout: MarkerLayout

    init(
        tuning: InstrumentTuning = .standard(for: .guitar6),
        maxFret: Int = 12,
        preferredHeight: CGFloat = 180,
        layoutMetrics: LayoutMetrics = .default,
        markerLayout: MarkerLayout = .standard
    ) {
        self.tuning = tuning
        self.maxFret = max(0, maxFret)
        self.preferredHeight = max(1, preferredHeight)
        self.layoutMetrics = layoutMetrics
        self.markerLayout = markerLayout
    }

    init(
        instrument: InstrumentType,
        maxFret: Int = 12,
        preferredHeight: CGFloat = 180,
        layoutMetrics: LayoutMetrics = .default,
        markerLayout: MarkerLayout = .standard
    ) {
        self.init(
            tuning: .standard(for: instrument),
            maxFret: maxFret,
            preferredHeight: preferredHeight,
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
}
