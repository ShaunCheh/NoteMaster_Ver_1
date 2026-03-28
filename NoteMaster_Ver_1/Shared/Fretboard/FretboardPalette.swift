//
//  FretboardPalette.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/25.
//

import CoreGraphics

enum FretboardPalette {
    static let openStringArea = makeColor(0.93, 0.91, 0.87)
    static let fretboardWood = makeColor(0.42, 0.29, 0.19)
    static let fretMetal = makeColor(0.86, 0.86, 0.88)
    static let nut = makeColor(0.15, 0.15, 0.16)
    static let string = makeColor(0.96, 0.96, 0.97, 0.94)
    static let markerFill = makeColor(0.97, 0.95, 0.90)
    static let displayBorder = makeColor(0.22, 0.18, 0.14, 0.28)
    static let noteBadgeFill = makeColor(0.98, 0.97, 0.94, 0.98)
    static let noteBadgeStroke = makeColor(0.23, 0.18, 0.14, 0.36)
    static let noteBadgeText = makeColor(0.16, 0.12, 0.09)
    static let feedbackCorrectFill = makeColor(0.18, 0.70, 0.36, 0.28)
    static let feedbackCorrectStroke = makeColor(0.12, 0.58, 0.28, 0.82)
    static let feedbackWrongFill = makeColor(0.86, 0.24, 0.24, 0.26)
    static let feedbackWrongStroke = makeColor(0.78, 0.14, 0.14, 0.84)

    private static func makeColor(
        _ red: CGFloat,
        _ green: CGFloat,
        _ blue: CGFloat,
        _ alpha: CGFloat = 1
    ) -> CGColor {
        CGColor(red: red, green: green, blue: blue, alpha: alpha)
    }
}
