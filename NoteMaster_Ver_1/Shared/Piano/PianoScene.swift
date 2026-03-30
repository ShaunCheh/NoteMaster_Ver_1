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

        static let empty = RowScene(
            rowIndex: 0,
            frame: .null,
            controlStripRect: .null,
            buttonStripRect: .null,
            buttonLeftRect: .null,
            buttonRightRect: .null,
            scaleRect: .null,
            keysRect: .null,
            whiteKeys: [],
            blackKeys: [],
            scaleMarkers: []
        )

        var rowIndex: Int
        var frame: CGRect
        var controlStripRect: CGRect
        var buttonStripRect: CGRect
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

        func localizedToRowBounds() -> RowScene {
            guard !frame.isNull else {
                return self
            }

            let dx = -frame.minX
            let dy = -frame.minY

            return RowScene(
                rowIndex: rowIndex,
                frame: CGRect(origin: .zero, size: frame.size),
                controlStripRect: controlStripRect.offsetBy(dx: dx, dy: dy),
                buttonStripRect: buttonStripRect.offsetBy(dx: dx, dy: dy),
                buttonLeftRect: buttonLeftRect.offsetBy(dx: dx, dy: dy),
                buttonRightRect: buttonRightRect.offsetBy(dx: dx, dy: dy),
                scaleRect: scaleRect.offsetBy(dx: dx, dy: dy),
                keysRect: keysRect.offsetBy(dx: dx, dy: dy),
                whiteKeys: whiteKeys.map { key in
                    WhiteKey(
                        note: key.note,
                        rect: key.rect.offsetBy(dx: dx, dy: dy)
                    )
                },
                blackKeys: blackKeys.map { key in
                    BlackKey(
                        note: key.note,
                        rect: key.rect.offsetBy(dx: dx, dy: dy)
                    )
                },
                scaleMarkers: scaleMarkers.map { marker in
                    ScaleMarker(
                        note: marker.note,
                        x: marker.x + dx,
                        labelText: marker.labelText
                    )
                }
            )
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
