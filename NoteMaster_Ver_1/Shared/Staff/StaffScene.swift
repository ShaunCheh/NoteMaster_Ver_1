//
//  StaffScene.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/24.
//

import CoreGraphics

struct StaffNotationDisplayOptions: Equatable, Sendable {
    var showsAccidentals: Bool
    var showsStems: Bool
    var showsLedgerLines: Bool

    static let noteheadsOnly = StaffNotationDisplayOptions(
        showsAccidentals: false,
        showsStems: false,
        showsLedgerLines: false
    )

    static let fullNotation = StaffNotationDisplayOptions(
        showsAccidentals: true,
        showsStems: true,
        showsLedgerLines: true
    )

    // 调号 accidental 与 note accidental 在阶段 4 继续共用同一套显示策略；
    // 这里拆成语义化访问点，避免调用方继续直接猜“showsAccidentals”具体覆盖哪些区域。
    var showsKeySignatureAccidentals: Bool {
        showsAccidentals
    }

    var showsNoteAccidentals: Bool {
        showsAccidentals
    }

    var debugSummary: String {
        "keySignatureAccidentals=\(showsKeySignatureAccidentals) noteAccidentals=\(showsNoteAccidentals) stems=\(showsStems) ledgerLines=\(showsLedgerLines)"
    }
}

struct ClefAnchor: Equatable, Sendable {
    enum Semantic: Equatable, Sendable {
        case trebleGLine
        case bassFLine
    }

    // 语义锚点使用共享逻辑坐标，不暴露 CoreText baseline。
    var point: CGPoint
    var semantic: Semantic
    var targetHeight: CGFloat
}

enum StaffGlyphSymbolID: Equatable, Sendable {
    case trebleClef
    case bassClef
    case noteheadWhole
    case noteheadHalf
    case noteheadBlack
    case accidentalFlat
    case accidentalNatural
    case accidentalSharp
}

struct StaffSceneColor: Equatable, Sendable {
    var red: CGFloat
    var green: CGFloat
    var blue: CGFloat
    var alpha: CGFloat

    static let primaryInk = StaffSceneColor(
        red: 0.12,
        green: 0.12,
        blue: 0.14,
        alpha: 1
    )

    static let debugRed = StaffSceneColor(
        red: 0.88,
        green: 0.18,
        blue: 0.18,
        alpha: 1
    )
}

enum StaffSequenceEvaluationResult: Equatable, Sendable {
    case correct
    case incorrect
}

struct StaffSequencePresentation: Equatable, Sendable {
    enum State: Equatable, Sendable {
        case idle
        case wrong
        case correct
        case completed
    }

    var state: State
    var cursorIndex: Int?
    var lastEvaluatedIndex: Int?
    var lastEvaluationResult: StaffSequenceEvaluationResult?

    // 序列反馈状态先在共享层标准化，后续 builder/layer 直接消费这一语义，
    // 避免双端控制器各自推导“当前游标 + 上次判题”的显示规则。
    private init(
        state: State,
        cursorIndex: Int?,
        lastEvaluatedIndex: Int?,
        lastEvaluationResult: StaffSequenceEvaluationResult?
    ) {
        if let cursorIndex {
            precondition(
                cursorIndex >= 0,
                "Staff sequence cursor index must not be negative."
            )
        }
        if let lastEvaluatedIndex {
            precondition(
                lastEvaluatedIndex >= 0,
                "Staff sequence last evaluated index must not be negative."
            )
        }

        switch state {
        case .idle:
            precondition(
                cursorIndex != nil,
                "Idle staff sequence presentation requires a cursor index."
            )
            precondition(
                lastEvaluatedIndex == nil && lastEvaluationResult == nil,
                "Idle staff sequence presentation must not carry evaluation feedback."
            )
        case .wrong:
            precondition(
                cursorIndex != nil,
                "Wrong staff sequence presentation requires a cursor index."
            )
            precondition(
                lastEvaluatedIndex != nil,
                "Wrong staff sequence presentation requires a last evaluated index."
            )
            precondition(
                lastEvaluationResult == .incorrect,
                "Wrong staff sequence presentation must carry an incorrect evaluation result."
            )
        case .correct:
            precondition(
                cursorIndex != nil,
                "Correct staff sequence presentation requires the next cursor index."
            )
            precondition(
                lastEvaluatedIndex != nil,
                "Correct staff sequence presentation requires a last evaluated index."
            )
            precondition(
                lastEvaluationResult == .correct,
                "Correct staff sequence presentation must carry a correct evaluation result."
            )
        case .completed:
            precondition(
                cursorIndex == nil,
                "Completed staff sequence presentation must hide the cursor."
            )
            precondition(
                (lastEvaluatedIndex == nil) == (lastEvaluationResult == nil),
                "Completed staff sequence presentation must either keep both evaluation fields or neither."
            )
        }

        self.state = state
        self.cursorIndex = cursorIndex
        self.lastEvaluatedIndex = lastEvaluatedIndex
        self.lastEvaluationResult = lastEvaluationResult
    }

    static func idle(cursorIndex: Int) -> Self {
        StaffSequencePresentation(
            state: .idle,
            cursorIndex: cursorIndex,
            lastEvaluatedIndex: nil,
            lastEvaluationResult: nil
        )
    }

    static func wrong(
        cursorIndex: Int,
        evaluatedIndex: Int
    ) -> Self {
        StaffSequencePresentation(
            state: .wrong,
            cursorIndex: cursorIndex,
            lastEvaluatedIndex: evaluatedIndex,
            lastEvaluationResult: .incorrect
        )
    }

    static func correct(
        cursorIndex: Int,
        evaluatedIndex: Int
    ) -> Self {
        StaffSequencePresentation(
            state: .correct,
            cursorIndex: cursorIndex,
            lastEvaluatedIndex: evaluatedIndex,
            lastEvaluationResult: .correct
        )
    }

    static func completed(
        lastEvaluatedIndex: Int? = nil,
        lastEvaluationResult: StaffSequenceEvaluationResult? = nil
    ) -> Self {
        StaffSequencePresentation(
            state: .completed,
            cursorIndex: nil,
            lastEvaluatedIndex: lastEvaluatedIndex,
            lastEvaluationResult: lastEvaluationResult
        )
    }

    var showsCursor: Bool {
        cursorIndex != nil
    }

    var isCompleted: Bool {
        state == .completed
    }
}

struct StaffGlyphBoundsOverlayStyle: Equatable, Sendable {
    var strokeColor: StaffSceneColor
    var lineWidth: CGFloat

    static func clefDebug(lineWidth: CGFloat = 1) -> Self {
        StaffGlyphBoundsOverlayStyle(
            strokeColor: .debugRed,
            lineWidth: max(lineWidth, 0.5)
        )
    }
}

struct StaffGlyphAnchorOverlayStyle: Equatable, Sendable {
    var strokeColor: StaffSceneColor
    var lineWidth: CGFloat
    var crossHalfLength: CGFloat

    static func clefDebug(
        lineWidth: CGFloat = 1,
        crossHalfLength: CGFloat = 4
    ) -> Self {
        StaffGlyphAnchorOverlayStyle(
            strokeColor: .debugRed,
            lineWidth: max(lineWidth, 0.5),
            crossHalfLength: max(crossHalfLength, 2)
        )
    }
}

struct StaffGlyphRenderHint: Equatable, Sendable {
    enum VerticalTrimMode: Equatable, Sendable {
        case none
        case clefSpecific
    }

    var preservesAspectRatio: Bool
    var prefersOpticalBoundsAlignment: Bool
    var verticalTrimMode: VerticalTrimMode
    var boundsOverlayStyle: StaffGlyphBoundsOverlayStyle?
    var anchorOverlayStyle: StaffGlyphAnchorOverlayStyle?

    static func staffClef(
        boundsOverlayStyle: StaffGlyphBoundsOverlayStyle? = nil,
        anchorOverlayStyle: StaffGlyphAnchorOverlayStyle? = nil
    ) -> StaffGlyphRenderHint {
        StaffGlyphRenderHint(
            preservesAspectRatio: true,
            prefersOpticalBoundsAlignment: true,
            verticalTrimMode: .clefSpecific,
            boundsOverlayStyle: boundsOverlayStyle,
            anchorOverlayStyle: anchorOverlayStyle
        )
    }

    static func notehead(
        boundsOverlayStyle: StaffGlyphBoundsOverlayStyle? = nil
    ) -> StaffGlyphRenderHint {
        StaffGlyphRenderHint(
            preservesAspectRatio: true,
            prefersOpticalBoundsAlignment: true,
            verticalTrimMode: .none,
            boundsOverlayStyle: boundsOverlayStyle,
            anchorOverlayStyle: nil
        )
    }

    static func accidental(
        boundsOverlayStyle: StaffGlyphBoundsOverlayStyle? = nil
    ) -> StaffGlyphRenderHint {
        StaffGlyphRenderHint(
            preservesAspectRatio: true,
            prefersOpticalBoundsAlignment: true,
            verticalTrimMode: .none,
            boundsOverlayStyle: boundsOverlayStyle,
            anchorOverlayStyle: nil
        )
    }
}

enum StaffGlyphPlacement: Equatable, Sendable {
    case anchor(ClefAnchor)
    case frame(CGRect)
}

struct StaffGlyphItem: Equatable, Sendable {
    var symbolID: StaffGlyphSymbolID
    var placement: StaffGlyphPlacement
    var tintColor: StaffSceneColor
    var renderHint: StaffGlyphRenderHint
}

enum StaffStrokeSemantic: Equatable, Sendable {
    case stem
    case ledgerLine
}

enum StaffStrokeLineCap: Equatable, Sendable {
    case butt
    case round
    case square
}

struct StaffStrokeStyle: Equatable, Sendable {
    var strokeColor: StaffSceneColor
    var lineWidth: CGFloat
    var lineCap: StaffStrokeLineCap

    static func stem(
        strokeColor: StaffSceneColor = .primaryInk,
        lineWidth: CGFloat = 1.4
    ) -> Self {
        StaffStrokeStyle(
            strokeColor: strokeColor,
            lineWidth: max(lineWidth, 0.5),
            lineCap: .round
        )
    }

    static func ledgerLine(
        strokeColor: StaffSceneColor = .primaryInk,
        lineWidth: CGFloat = 1.2
    ) -> Self {
        StaffStrokeStyle(
            strokeColor: strokeColor,
            lineWidth: max(lineWidth, 0.5),
            lineCap: .round
        )
    }
}

struct StaffStrokeItem: Equatable, Sendable {
    var semantic: StaffStrokeSemantic
    var start: CGPoint
    var end: CGPoint
    var style: StaffStrokeStyle
}

struct StaffScene: Equatable, Sendable {
    // 五线谱本体由独立 lines layer 绘制；scene 仍保留这份语义结果，供验证和后续 builder 使用。
    var lineSegments: [StaffGeometry.StaffLineSegment]
    // note stem / ledger line 等附加线段走 scene item，而不是伪装成 staff line。
    var strokeItems: [StaffStrokeItem]
    var glyphs: [StaffGlyphItem]

    static let empty = StaffScene(
        lineSegments: [],
        strokeItems: [],
        glyphs: []
    )
}

extension ClefAnchor.Semantic {
    var clef: StaffClef {
        switch self {
        case .trebleGLine:
            return .treble
        case .bassFLine:
            return .bass
        }
    }
}

extension StaffGlyphSymbolID {
    var clef: StaffClef? {
        switch self {
        case .trebleClef:
            return .treble
        case .bassClef:
            return .bass
        case .noteheadWhole, .noteheadHalf, .noteheadBlack,
                .accidentalFlat, .accidentalNatural, .accidentalSharp:
            return nil
        }
    }

    var isClef: Bool {
        switch self {
        case .trebleClef, .bassClef:
            return true
        case .noteheadWhole, .noteheadHalf, .noteheadBlack,
                .accidentalFlat, .accidentalNatural, .accidentalSharp:
            return false
        }
    }

    var isNotehead: Bool {
        switch self {
        case .noteheadWhole, .noteheadHalf, .noteheadBlack:
            return true
        case .trebleClef, .bassClef,
                .accidentalFlat, .accidentalNatural, .accidentalSharp:
            return false
        }
    }

    var isAccidental: Bool {
        switch self {
        case .accidentalFlat, .accidentalNatural, .accidentalSharp:
            return true
        case .trebleClef, .bassClef, .noteheadWhole, .noteheadHalf, .noteheadBlack:
            return false
        }
    }

    var debugName: String {
        switch self {
        case .trebleClef:
            return "trebleClef"
        case .bassClef:
            return "bassClef"
        case .noteheadWhole:
            return "noteheadWhole"
        case .noteheadHalf:
            return "noteheadHalf"
        case .noteheadBlack:
            return "noteheadBlack"
        case .accidentalFlat:
            return "accidentalFlat"
        case .accidentalNatural:
            return "accidentalNatural"
        case .accidentalSharp:
            return "accidentalSharp"
        }
    }
}
