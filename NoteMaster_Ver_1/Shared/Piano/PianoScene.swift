//
//  PianoScene.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/30.
//

import CoreGraphics

struct PianoScene: Equatable, Sendable {
    struct RowScene: Equatable, Sendable {
        struct WhiteKey: Equatable, Sendable {
            var note: NotePitch
            var rect: CGRect
        }

        struct BlackKey: Equatable, Sendable {
            var note: NotePitch
            var rect: CGRect
        }

        struct ScaleMarker: Equatable, Sendable {
            var note: NotePitch
            var x: CGFloat
            var labelText: String
        }

        var rowIndex: Int
        var frame: CGRect
        var controlStripRect: CGRect
        var buttonLeftRect: CGRect
        var buttonRightRect: CGRect
        var scaleRect: CGRect
        var keysRect: CGRect
        var whiteKeys: [WhiteKey]
        var blackKeys: [BlackKey]
        var scaleMarkers: [ScaleMarker]

        func whiteKey(for note: NotePitch) -> WhiteKey? {
            whiteKeys.first { $0.note == note }
        }

        func blackKey(for note: NotePitch) -> BlackKey? {
            blackKeys.first { $0.note == note }
        }

        func noteRect(for note: NotePitch) -> CGRect? {
            if let blackKey = blackKey(for: note) {
                return blackKey.rect
            }

            return whiteKey(for: note)?.rect
        }

        func scaleMarker(for note: NotePitch) -> ScaleMarker? {
            scaleMarkers.first { $0.note == note }
        }
    }

    static let empty = PianoScene(
        bounds: .null,
        contentRect: .null,
        rows: []
    )

    var bounds: CGRect
    var contentRect: CGRect
    var rows: [RowScene]

    func rowScene(at rowIndex: Int) -> RowScene? {
        rows.first { $0.rowIndex == rowIndex }
    }
}
