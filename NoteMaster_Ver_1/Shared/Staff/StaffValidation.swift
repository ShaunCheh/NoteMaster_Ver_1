//
//  StaffValidation.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/26.
//

import Foundation
import CoreGraphics

enum StaffValidationPlatform: String {
    case iOS
    case macOS
    case commandLine

    var displayName: String {
        rawValue
    }
}

struct StaffValidationIssue: Equatable {
    var fixtureName: String
    var message: String
}

struct StaffValidationReport {
    var platform: StaffValidationPlatform
    var fixtureCount: Int
    var passedFixtureNames: [String]
    var issues: [StaffValidationIssue]
    var manualChecklist: [String]

    var isPassing: Bool {
        issues.isEmpty
    }

    func debugSummary() -> String {
        let automatedStatus = isPassing ? "PASS" : "FAIL"
        let passedFixturesText = passedFixtureNames.isEmpty
            ? "无"
            : passedFixtureNames.joined(separator: ", ")
        let issuesText = issues.isEmpty
            ? "- 无"
            : issues.map { "- [\($0.fixtureName)] \($0.message)" }.joined(separator: "\n")
        let checklistText = manualChecklist.enumerated().map {
            "\($0.offset + 1). \($0.element)"
        }.joined(separator: "\n")

        return """
        [StaffValidation][\(platform.displayName)] automated=\(automatedStatus) fixtures=\(fixtureCount)
        通过夹具: \(passedFixturesText)
        自动化问题:
        \(issuesText)
        手工回归清单:
        \(checklistText)
        """
    }
}

enum StaffValidationRunner {
    static func run(platform: StaffValidationPlatform) -> StaffValidationReport {
        let fixtures = makeFixtures()
        var passedFixtureNames: [String] = []
        var issues: [StaffValidationIssue] = []

        for fixture in fixtures {
            let fixtureIssues = validate(fixture)
            if fixtureIssues.isEmpty {
                passedFixtureNames.append(fixture.name)
            } else {
                issues.append(contentsOf: fixtureIssues)
            }
        }

        return StaffValidationReport(
            platform: platform,
            fixtureCount: fixtures.count,
            passedFixtureNames: passedFixtureNames,
            issues: issues,
            manualChecklist: manualChecklist(for: platform)
        )
    }

    static func runAndReportIfNeeded(platform: StaffValidationPlatform) {
        #if DEBUG
        let report = run(platform: platform)
        let summary = report.debugSummary()
        print(summary)

        if !report.isPassing {
            assertionFailure(summary)
        }
        #endif
    }
}

private struct StaffValidationFixture {
    var name: String
    var configuration: StaffConfiguration
    var score: StaffScore
    var notationDisplayOptions: StaffNotationDisplayOptions
    var bounds: CGRect
    var expectedLedgerLineCount: Int
    var expectedDisplayedNoteAccidentals: [StaffValidationExpectedNoteAccidental]
}

private struct StaffValidationExpectedNoteAccidental: Equatable {
    var noteIndex: Int
    var symbolID: StaffGlyphSymbolID
}

private extension StaffValidationRunner {
    static let tolerance: CGFloat = 0.001
    static let fixtureWidth: CGFloat = 860

    static func makeFixtures() -> [StaffValidationFixture] {
        let trebleConfiguration = StaffConfiguration(
            clef: .treble,
            renderMode: .coreText
        )
        let bassConfiguration = StaffConfiguration(
            clef: .bass,
            renderMode: .coreText
        )

        let keySignatureFixtures: [(String, StaffKeySignature)] = [
            ("c", .natural),
            ("g", StaffKeySignature(fifths: 1)),
            ("d", StaffKeySignature(fifths: 2)),
            ("f", StaffKeySignature(fifths: -1)),
            ("bb", StaffKeySignature(fifths: -2))
        ]

        var fixtures = [
            fixture(
                name: "treble-default-demo-full-notation",
                configuration: trebleConfiguration,
                score: StaffScoreFixtures.defaultDemo(clef: .treble),
                notationDisplayOptions: .fullNotation,
                expectedDisplayedNoteAccidentals: [
                    noteAccidental(noteIndex: 1, accidental: .sharp),
                    noteAccidental(noteIndex: 3, accidental: .flat)
                ]
            ),
            fixture(
                name: "treble-default-demo-noteheads-only",
                configuration: trebleConfiguration,
                score: StaffScoreFixtures.defaultDemo(clef: .treble),
                notationDisplayOptions: .noteheadsOnly
            ),
            fixture(
                name: "bass-ascending-reference-full-notation",
                configuration: bassConfiguration,
                score: score(
                    clef: .bass,
                    measures: [[
                        ("g2", .quarter),
                        ("a2", .quarter),
                        ("bb2", .quarter),
                        ("c3", .half),
                        ("d3", .quarter),
                        ("e3", .quarter),
                        ("f3", .half),
                        ("a3", .whole)
                    ]]
                ),
                notationDisplayOptions: .fullNotation,
                expectedDisplayedNoteAccidentals: [
                    noteAccidental(noteIndex: 2, accidental: .flat)
                ]
            ),
            fixture(
                name: "treble-ledger-both-sides-full-notation",
                configuration: trebleConfiguration,
                score: score(
                    clef: .treble,
                    measures: [[
                        ("c4", .quarter),
                        ("a5", .quarter),
                        ("c6", .half)
                    ]]
                ),
                notationDisplayOptions: .fullNotation,
                extraVerticalSpaces: 8,
                expectedLedgerLineCount: 4
            ),
            fixture(
                name: "bass-ledger-both-sides-full-notation",
                configuration: bassConfiguration,
                score: score(
                    clef: .bass,
                    measures: [[
                        ("e2", .quarter),
                        ("c4", .quarter),
                        ("e4", .half)
                    ]]
                ),
                notationDisplayOptions: .fullNotation,
                extraVerticalSpaces: 8,
                expectedLedgerLineCount: 4
            ),
            fixture(
                name: "treble-g-major-context-reset",
                configuration: trebleConfiguration,
                score: StaffScoreFixtures.gMajorAccidentalContextReference(),
                notationDisplayOptions: .fullNotation,
                expectedDisplayedNoteAccidentals: [
                    noteAccidental(noteIndex: 2, accidental: .natural),
                    noteAccidental(noteIndex: 4, accidental: .sharp),
                    noteAccidental(noteIndex: 6, accidental: .natural)
                ]
            ),
            fixture(
                name: "bass-bb-major-context-reset",
                configuration: bassConfiguration,
                score: StaffScoreFixtures.bbMajorBassAccidentalContextReference(),
                notationDisplayOptions: .fullNotation,
                expectedDisplayedNoteAccidentals: [
                    noteAccidental(noteIndex: 2, accidental: .natural),
                    noteAccidental(noteIndex: 5, accidental: .natural)
                ]
            )
        ]

        fixtures.append(
            contentsOf: keySignatureFixtures.map {
                fixture(
                    name: "treble-key-\($0.0)-reference",
                    configuration: trebleConfiguration,
                    score: StaffScoreFixtures.keySignatureReference(
                        clef: .treble,
                        keySignature: $0.1
                    ),
                    notationDisplayOptions: .fullNotation
                )
            }
        )
        fixtures.append(
            contentsOf: keySignatureFixtures.map {
                fixture(
                    name: "bass-key-\($0.0)-reference",
                    configuration: bassConfiguration,
                    score: StaffScoreFixtures.keySignatureReference(
                        clef: .bass,
                        keySignature: $0.1
                    ),
                    notationDisplayOptions: .fullNotation
                )
            }
        )

        return fixtures
    }

    static func fixtureBounds(
        configuration: StaffConfiguration,
        extraVerticalSpaces: CGFloat = 0
    ) -> CGRect {
        let extraHeight = configuration.layoutMetrics.normalizedStaffSpaceHeight * extraVerticalSpaces
        return CGRect(
            origin: .zero,
            size: CGSize(
                width: fixtureWidth,
                height: configuration.preferredHeight + extraHeight
            )
        )
    }

    static func fixture(
        name: String,
        configuration: StaffConfiguration,
        score: StaffScore,
        notationDisplayOptions: StaffNotationDisplayOptions,
        extraVerticalSpaces: CGFloat = 0,
        expectedLedgerLineCount: Int = 0,
        expectedDisplayedNoteAccidentals: [StaffValidationExpectedNoteAccidental] = []
    ) -> StaffValidationFixture {
        StaffValidationFixture(
            name: name,
            configuration: configuration,
            score: score,
            notationDisplayOptions: notationDisplayOptions,
            bounds: fixtureBounds(
                configuration: configuration,
                extraVerticalSpaces: extraVerticalSpaces
            ),
            expectedLedgerLineCount: expectedLedgerLineCount,
            expectedDisplayedNoteAccidentals: expectedDisplayedNoteAccidentals
        )
    }

    static func score(
        clef: StaffClef,
        keySignature: StaffKeySignature = .natural,
        measures: [[(String, StaffNoteDuration)]]
    ) -> StaffScore {
        let measuresJSON = measures.map { measure in
            let notesJSON = measure.map {
                """
                { "pitch": "\($0.0)", "duration": "\($0.1.rawValue)" }
                """
            }.joined(separator: ",\n")
            return """
            {
              "notes": [
            \(notesJSON)
              ]
            }
            """
        }.joined(separator: ",\n")
        let json = """
        {
          "clef": "\(clefToken(clef))",
          "keySignature": {
            "fifths": \(keySignature.fifths)
          },
          "measures": [
        \(measuresJSON)
          ]
        }
        """

        do {
            return try StaffScore.decode(from: json)
        } catch {
            assertionFailure("Failed to build staff validation score: \(error)")
            return StaffScore(
                clef: clef,
                keySignature: keySignature,
                measures: []
            )
        }
    }

    static func validate(_ fixture: StaffValidationFixture) -> [StaffValidationIssue] {
        let geometry = StaffGeometry(
            configuration: fixture.configuration,
            bounds: fixture.bounds
        )
        let scene = StaffSceneProvider(
            clef: fixture.configuration.clef,
            score: fixture.score,
            notationDisplayOptions: fixture.notationDisplayOptions
        ).makeScene(geometry: geometry)
        var issues: [StaffValidationIssue] = []

        func record(_ message: String) {
            issues.append(
                StaffValidationIssue(
                    fixtureName: fixture.name,
                    message: message
                )
            )
        }

        guard !geometry.drawingRect.isNull, !geometry.drawingRect.isEmpty else {
            record("geometry.drawingRect 为空，未生成有效几何。")
            return issues
        }

        validateSceneCounts(
            scene: scene,
            geometry: geometry,
            fixture: fixture,
            record: record
        )
        validateNoteheadLayout(
            scene: scene,
            geometry: geometry,
            fixture: fixture,
            record: record
        )
        if fixture.notationDisplayOptions.showsKeySignatureAccidentals
            || fixture.notationDisplayOptions.showsNoteAccidentals {
            validateAccidentals(
                scene: scene,
                geometry: geometry,
                fixture: fixture,
                record: record
            )
        }
        validatePitchOrdering(
            scene: scene,
            fixture: fixture,
            record: record
        )
        validateStrokeSemantics(
            scene: scene,
            fixture: fixture,
            record: record
        )

        return issues
    }

    static func validateSceneCounts(
        scene: StaffScene,
        geometry: StaffGeometry,
        fixture: StaffValidationFixture,
        record: (String) -> Void
    ) {
        if scene.lineSegments.count != geometry.staffLineCount {
            record("staff line 数量错误，期望 \(geometry.staffLineCount)，实际 \(scene.lineSegments.count)。")
        }

        let clefGlyphs = scene.glyphs.filter(\.symbolID.isClef)
        if clefGlyphs.count != 1 {
            record("clef glyph 数量错误，期望 1，实际 \(clefGlyphs.count)。")
        } else if clefGlyphs[0].symbolID != clefSymbolID(for: fixture.configuration.clef) {
            record("clef glyph 类型错误，期望 \(clefSymbolID(for: fixture.configuration.clef))，实际 \(clefGlyphs[0].symbolID)。")
        }

        let noteheadGlyphs = scene.glyphs.filter(\.symbolID.isNotehead)
        if noteheadGlyphs.count != fixture.score.notes.count {
            record("notehead glyph 数量错误，期望 \(fixture.score.notes.count)，实际 \(noteheadGlyphs.count)。")
        }

        let expectedAccidentalCount = expectedKeySignatureAccidentalSymbols(
            for: fixture
        ).count + expectedDisplayedNoteAccidentals(
            for: fixture
        ).count
        let actualAccidentalCount = scene.glyphs.filter(\.symbolID.isAccidental).count
        if actualAccidentalCount != expectedAccidentalCount {
            record("accidental glyph 数量错误，期望 \(expectedAccidentalCount)，实际 \(actualAccidentalCount)。")
        }

        let expectedStemCount = fixture.notationDisplayOptions.showsStems
            ? fixture.score.notes.filter(\.duration.showsStem).count
            : 0
        let actualStemCount = scene.strokeItems.filter { $0.semantic == .stem }.count
        if actualStemCount != expectedStemCount {
            record("stem 数量错误，期望 \(expectedStemCount)，实际 \(actualStemCount)。")
        }

        let expectedLedgerLineCount = fixture.notationDisplayOptions.showsLedgerLines
            ? fixture.expectedLedgerLineCount
            : 0
        let actualLedgerLineCount = scene.strokeItems.filter { $0.semantic == .ledgerLine }.count
        if actualLedgerLineCount != expectedLedgerLineCount {
            record("ledger line 数量错误，期望 \(expectedLedgerLineCount)，实际 \(actualLedgerLineCount)。")
        }
    }

    static func validateNoteheadLayout(
        scene: StaffScene,
        geometry: StaffGeometry,
        fixture: StaffValidationFixture,
        record: (String) -> Void
    ) {
        let noteheadGlyphs = scene.glyphs.filter(\.symbolID.isNotehead)
        let noteheadFrames = noteheadGlyphs.compactMap { frame(of: $0) }
        if noteheadFrames.count != noteheadGlyphs.count {
            record("存在 notehead glyph 不是 frame placement。")
            return
        }

        let expectedSymbols = fixture.score.notes.map {
            noteheadSymbolID(for: $0.duration)
        }
        let actualSymbols = noteheadGlyphs.map(\.symbolID)
        if actualSymbols != expectedSymbols {
            record("notehead glyph 类型序列错误，期望 \(expectedSymbols)，实际 \(actualSymbols)。")
        }

        for (noteIndex, frame) in noteheadFrames.enumerated() {
            if frame.width <= 0 || frame.height <= 0 {
                record("notehead[\(noteIndex)] 尺寸非法。")
                continue
            }

            if frame.minX <= geometry.clefAreaRect.maxX {
                record("notehead[\(noteIndex)] 侵入 clefAreaRect。")
            }

            if !contains(point: CGPoint(x: frame.midX, y: frame.midY), in: fixture.bounds) {
                record("notehead[\(noteIndex)] 的中心点超出 fixture bounds。")
            }

            if let bottomLineY = geometry.bottomLineY {
                let rawStep = (bottomLineY - frame.midY) / geometry.staffStepHeight
                if !approximatelyEqual(rawStep.rounded(), rawStep) {
                    record("notehead[\(noteIndex)] 未对齐到五线谱 line/space 网格。")
                }
            }
        }

        let centerXs = noteheadFrames.map(\.midX)
        if !isStrictlyIncreasing(centerXs) {
            record("notehead 的 x 位置没有按音符顺序严格递增。")
        }
    }

    static func validateAccidentals(
        scene: StaffScene,
        geometry: StaffGeometry,
        fixture: StaffValidationFixture,
        record: (String) -> Void
    ) {
        let accidentalGlyphs = scene.glyphs.filter(\.symbolID.isAccidental)
        let accidentalFrames = accidentalGlyphs.compactMap { frame(of: $0) }
        if accidentalFrames.count != accidentalGlyphs.count {
            record("存在 accidental glyph 不是 frame placement。")
            return
        }

        let expectedKeySignatureSymbols = expectedKeySignatureAccidentalSymbols(
            for: fixture
        )
        let expectedNoteAccidentals = expectedDisplayedNoteAccidentals(
            for: fixture
        )
        let actualKeySignatureGlyphs = Array(
            accidentalGlyphs.prefix(expectedKeySignatureSymbols.count)
        )
        let actualKeySignatureFrames = Array(
            accidentalFrames.prefix(expectedKeySignatureSymbols.count)
        )
        let actualNoteAccidentalGlyphs = Array(
            accidentalGlyphs.dropFirst(expectedKeySignatureSymbols.count)
        )
        let actualNoteAccidentalFrames = Array(
            accidentalFrames.dropFirst(expectedKeySignatureSymbols.count)
        )

        let actualKeySignatureSymbols = actualKeySignatureGlyphs.map(\.symbolID)
        if actualKeySignatureSymbols != expectedKeySignatureSymbols {
            record("key signature accidental 序列错误，期望 \(expectedKeySignatureSymbols)，实际 \(actualKeySignatureSymbols)。")
        }

        let expectedKeySignatureStaffPositions = expectedKeySignatureStaffPositions(
            clef: fixture.configuration.clef,
            keySignature: fixture.score.keySignature,
            notationDisplayOptions: fixture.notationDisplayOptions
        )
        if expectedKeySignatureStaffPositions.count != actualKeySignatureFrames.count {
            record("key signature accidental 数量与位置期望不一致，期望 \(expectedKeySignatureStaffPositions.count)，实际 \(actualKeySignatureFrames.count)。")
        }

        if !isStrictlyIncreasing(actualKeySignatureFrames.map(\.midX)) {
            record("key signature accidental 的 x 位置没有严格递增。")
        }

        if let bottomLineY = geometry.bottomLineY {
            for (index, frame) in actualKeySignatureFrames.enumerated() {
                guard index < expectedKeySignatureStaffPositions.count else {
                    break
                }

                let rawStep = (bottomLineY - frame.midY) / geometry.staffStepHeight
                if !approximatelyEqual(rawStep, CGFloat(expectedKeySignatureStaffPositions[index])) {
                    record("key signature accidental[\(index)] 的 staffPosition 错误，期望 \(expectedKeySignatureStaffPositions[index])，实际 \(rawStep)。")
                }
            }
        }

        let actualNoteAccidentalSymbols = actualNoteAccidentalGlyphs.map(\.symbolID)
        let expectedNoteAccidentalSymbols = expectedNoteAccidentals.map(\.symbolID)
        if actualNoteAccidentalSymbols != expectedNoteAccidentalSymbols {
            record("note accidental 序列错误，期望 \(expectedNoteAccidentalSymbols)，实际 \(actualNoteAccidentalSymbols)。")
        }

        let noteheadFrames = scene.glyphs.filter(\.symbolID.isNotehead).compactMap { frame(of: $0) }
        for (accidentalIndex, expectedAccidental) in expectedNoteAccidentals.enumerated() {
            guard
                accidentalIndex < actualNoteAccidentalFrames.count,
                expectedAccidental.noteIndex < noteheadFrames.count
            else {
                record("note accidental 与 notehead 的映射数量不一致。")
                break
            }

            let accidentalFrame = actualNoteAccidentalFrames[accidentalIndex]
            let noteheadFrame = noteheadFrames[expectedAccidental.noteIndex]
            if accidentalFrame.maxX >= noteheadFrame.minX {
                record("note accidental[\(accidentalIndex)] 没有落在 notehead[\(expectedAccidental.noteIndex)] 左侧。")
            }

            if !approximatelyEqual(accidentalFrame.midY, noteheadFrame.midY) {
                record("note accidental[\(accidentalIndex)] 与 notehead[\(expectedAccidental.noteIndex)] 的中心 Y 不一致。")
            }
        }

        if let lastKeySignatureFrame = actualKeySignatureFrames.last,
           let firstNoteheadFrame = noteheadFrames.first {
            var firstNoteClusterMinX = firstNoteheadFrame.minX
            if let firstExpectedNoteAccidental = expectedNoteAccidentals.first,
               firstExpectedNoteAccidental.noteIndex == 0,
               let firstNoteAccidentalFrame = actualNoteAccidentalFrames.first {
                firstNoteClusterMinX = min(
                    firstNoteClusterMinX,
                    firstNoteAccidentalFrame.minX
                )
            }

            if firstNoteClusterMinX <= lastKeySignatureFrame.maxX + tolerance {
                record("首个 note cluster 侵入 key signature 区域。")
            }
        }
    }

    static func validatePitchOrdering(
        scene: StaffScene,
        fixture: StaffValidationFixture,
        record: (String) -> Void
    ) {
        let noteheadFrames = scene.glyphs.filter(\.symbolID.isNotehead).compactMap { frame(of: $0) }
        guard noteheadFrames.count == fixture.score.notes.count else {
            return
        }

        for index in 1..<fixture.score.notes.count {
            let previousPitch = fixture.score.notes[index - 1].pitch.diatonicIndex
            let currentPitch = fixture.score.notes[index].pitch.diatonicIndex
            let previousY = noteheadFrames[index - 1].midY
            let currentY = noteheadFrames[index].midY

            if currentPitch > previousPitch, !(currentY < previousY - tolerance) {
                record("音高递增时 notehead[\(index)] 没有向上移动。")
            } else if currentPitch < previousPitch, !(currentY > previousY + tolerance) {
                record("音高递减时 notehead[\(index)] 没有向下移动。")
            } else if currentPitch == previousPitch, !approximatelyEqual(currentY, previousY) {
                record("同音高 notehead[\(index)] 的 y 位置不一致。")
            }
        }
    }

    static func validateStrokeSemantics(
        scene: StaffScene,
        fixture: StaffValidationFixture,
        record: (String) -> Void
    ) {
        for (index, stroke) in scene.strokeItems.enumerated() {
            if !contains(point: stroke.start, in: fixture.bounds)
                || !contains(point: stroke.end, in: fixture.bounds) {
                record("stroke[\(index)] 超出 fixture bounds。")
            }

            switch stroke.semantic {
            case .stem:
                if !approximatelyEqual(stroke.start.x, stroke.end.x) {
                    record("stem[\(index)] 不是竖线。")
                }
            case .ledgerLine:
                if !approximatelyEqual(stroke.start.y, stroke.end.y) {
                    record("ledgerLine[\(index)] 不是横线。")
                }

                if !(stroke.end.x > stroke.start.x + tolerance) {
                    record("ledgerLine[\(index)] 宽度非法。")
                }
            }
        }
    }

    static func manualChecklist(for platform: StaffValidationPlatform) -> [String] {
        var checklist = [
            "启动 App，确认默认五线谱已恢复完整记谱显示：除 clef 与 notehead 外，还能看到 stem，以及需要时的 accidental / ledger line，且没有回退成 clef-only 场景。",
            "将共享 score 临时切到 `StaffScoreFixtures.keySignatureReference(...)` 的 `C / G / D / F / Bb` 参考谱例，并在 Treble / Bass 间切换；确认调号 glyph 数量、sharp/flat 顺序和垂直落点正确。",
            "将共享 score 切到 `StaffScoreFixtures.gMajorAccidentalContextReference()`，确认同小节里 `f#` 会被调号抑制、写出 `f natural` 后同小节再次 `f#` 会重新显示 sharp，跨小节后恢复调号默认规则。",
            "将共享 score 切到 `StaffScoreFixtures.bbMajorBassAccidentalContextReference()`，确认 Bass + Bb major 下 `bb3` 默认不显示 accidental，`b3` 显示 natural，跨小节后再次按调号默认值重置。",
            "显式把 `staffDisplayState.notationDisplayOptions` 切到 `.noteheadsOnly` 再切回 `.fullNotation`，确认 notehead 可见性稳定，且 accidental / stem / ledger line 能正确隐藏与恢复。",
            "调整窗口大小或设备方向，确认 key signature 区与 note 区不会重叠，note spacing 与 glyph 位置稳定更新。"
        ]

        switch platform {
        case .iOS:
            checklist.append("在 iOS 上验证 settings 打开/关闭与滚动共存时，完整记谱场景不会闪烁、错位或因为调号变宽而破坏滚动体验。")
        case .macOS:
            checklist.append("在 macOS 上执行 live resize，确认调号区和音符区在 resize 过程中保持稳定，不出现 accidental 抖动或重叠。")
        case .commandLine:
            checklist.append("命令行只覆盖共享层 scene fixture，不覆盖 iOS/macOS 运行时渲染、字体注册与交互。")
        }

        return checklist
    }

    static func frame(of glyphItem: StaffGlyphItem) -> CGRect? {
        guard case let .frame(frame) = glyphItem.placement else {
            return nil
        }

        return frame
    }

    static func noteheadSymbolID(
        for duration: StaffNoteDuration
    ) -> StaffGlyphSymbolID {
        switch duration {
        case .whole:
            return .noteheadWhole
        case .half:
            return .noteheadHalf
        case .quarter:
            return .noteheadBlack
        }
    }

    static func noteAccidental(
        noteIndex: Int,
        accidental: StaffAccidental
    ) -> StaffValidationExpectedNoteAccidental {
        StaffValidationExpectedNoteAccidental(
            noteIndex: noteIndex,
            symbolID: noteAccidentalSymbolID(for: accidental)
        )
    }

    static func expectedDisplayedNoteAccidentals(
        for fixture: StaffValidationFixture
    ) -> [StaffValidationExpectedNoteAccidental] {
        guard fixture.notationDisplayOptions.showsNoteAccidentals else {
            return []
        }

        return fixture.expectedDisplayedNoteAccidentals
    }

    static func expectedKeySignatureAccidentalSymbols(
        for fixture: StaffValidationFixture
    ) -> [StaffGlyphSymbolID] {
        guard
            fixture.notationDisplayOptions.showsKeySignatureAccidentals,
            let symbolID = keySignatureAccidentalSymbolID(
                for: fixture.score.keySignature
            )
        else {
            return []
        }

        return Array(
            repeating: symbolID,
            count: abs(fixture.score.keySignature.fifths)
        )
    }

    static func expectedKeySignatureStaffPositions(
        clef: StaffClef,
        keySignature: StaffKeySignature,
        notationDisplayOptions: StaffNotationDisplayOptions
    ) -> [Int] {
        guard notationDisplayOptions.showsKeySignatureAccidentals else {
            return []
        }

        if keySignature.fifths > 0 {
            let order: [Int] = switch clef {
            case .treble:
                [8, 5, 9, 6, 3, 7, 4]
            case .bass:
                [6, 3, 7, 4, 1, 5, 2]
            }
            return Array(order.prefix(keySignature.fifths))
        }

        if keySignature.fifths < 0 {
            let order: [Int] = switch clef {
            case .treble:
                [4, 7, 3, 6, 2, 5, 1]
            case .bass:
                [2, 5, 1, 4, 0, 3, -1]
            }
            return Array(order.prefix(abs(keySignature.fifths)))
        }

        return []
    }

    static func keySignatureAccidentalSymbolID(
        for keySignature: StaffKeySignature
    ) -> StaffGlyphSymbolID? {
        switch keySignature.signatureAccidental {
        case .flat:
            return .accidentalFlat
        case .sharp:
            return .accidentalSharp
        case .natural, nil:
            return nil
        }
    }

    static func noteAccidentalSymbolID(
        for accidental: StaffAccidental
    ) -> StaffGlyphSymbolID {
        switch accidental {
        case .flat:
            return .accidentalFlat
        case .natural:
            return .accidentalNatural
        case .sharp:
            return .accidentalSharp
        }
    }

    static func clefSymbolID(
        for clef: StaffClef
    ) -> StaffGlyphSymbolID {
        switch clef {
        case .treble:
            return .trebleClef
        case .bass:
            return .bassClef
        }
    }

    static func clefToken(_ clef: StaffClef) -> String {
        switch clef {
        case .treble:
            return "treble"
        case .bass:
            return "bass"
        }
    }

    static func isStrictlyIncreasing(_ values: [CGFloat]) -> Bool {
        guard values.count > 1 else {
            return true
        }

        for index in 1..<values.count where !(values[index] > values[index - 1] + tolerance) {
            return false
        }

        return true
    }

    static func contains(point: CGPoint, in rect: CGRect) -> Bool {
        point.x >= rect.minX - tolerance
            && point.x <= rect.maxX + tolerance
            && point.y >= rect.minY - tolerance
            && point.y <= rect.maxY + tolerance
    }

    static func approximatelyEqual(_ lhs: CGFloat, _ rhs: CGFloat) -> Bool {
        abs(lhs - rhs) <= tolerance
    }
}
