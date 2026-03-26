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
    var bounds: CGRect
    var expectedLedgerLineCount: Int
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

        return [
            StaffValidationFixture(
                name: "treble-default-demo",
                configuration: trebleConfiguration,
                score: StaffScoreFixtures.defaultDemo(clef: .treble),
                bounds: fixtureBounds(configuration: trebleConfiguration),
                expectedLedgerLineCount: 0
            ),
            StaffValidationFixture(
                name: "bass-ascending-reference",
                configuration: bassConfiguration,
                score: score(
                    clef: .bass,
                    notes: [
                        ("g2", .quarter),
                        ("a2", .quarter),
                        ("bb2", .quarter),
                        ("c3", .half),
                        ("d3", .quarter),
                        ("e3", .quarter),
                        ("f3", .half),
                        ("a3", .whole)
                    ]
                ),
                bounds: fixtureBounds(configuration: bassConfiguration),
                expectedLedgerLineCount: 0
            ),
            StaffValidationFixture(
                name: "treble-ledger-both-sides",
                configuration: trebleConfiguration,
                score: score(
                    clef: .treble,
                    notes: [
                        ("c4", .quarter),
                        ("a5", .quarter),
                        ("c6", .half)
                    ]
                ),
                bounds: fixtureBounds(
                    configuration: trebleConfiguration,
                    extraVerticalSpaces: 8
                ),
                expectedLedgerLineCount: 4
            ),
            StaffValidationFixture(
                name: "bass-ledger-both-sides",
                configuration: bassConfiguration,
                score: score(
                    clef: .bass,
                    notes: [
                        ("e2", .quarter),
                        ("c4", .quarter),
                        ("e4", .half)
                    ]
                ),
                bounds: fixtureBounds(
                    configuration: bassConfiguration,
                    extraVerticalSpaces: 8
                ),
                expectedLedgerLineCount: 4
            )
        ]
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

    static func score(
        clef: StaffClef,
        notes: [(String, StaffNoteDuration)]
    ) -> StaffScore {
        do {
            return try StaffScoreDTO(
                clef: clefToken(clef),
                notes: notes.map {
                    StaffScoreNoteDTO(
                        pitch: $0.0,
                        duration: $0.1.rawValue
                    )
                }
            ).resolve()
        } catch {
            assertionFailure("Failed to build staff validation score: \(error)")
            return StaffScore(clef: clef, notes: [])
        }
    }

    static func validate(_ fixture: StaffValidationFixture) -> [StaffValidationIssue] {
        let geometry = StaffGeometry(
            configuration: fixture.configuration,
            bounds: fixture.bounds
        )
        let scene = StaffSceneProvider(
            clef: fixture.configuration.clef,
            score: fixture.score
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
        validateAccidentals(
            scene: scene,
            fixture: fixture,
            record: record
        )
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

        let expectedAccidentalCount = fixture.score.notes.filter {
            $0.pitch.accidental != .natural
        }.count
        let actualAccidentalCount = scene.glyphs.filter(\.symbolID.isAccidental).count
        if actualAccidentalCount != expectedAccidentalCount {
            record("accidental glyph 数量错误，期望 \(expectedAccidentalCount)，实际 \(actualAccidentalCount)。")
        }

        let expectedStemCount = fixture.score.notes.filter(\.duration.showsStem).count
        let actualStemCount = scene.strokeItems.filter { $0.semantic == .stem }.count
        if actualStemCount != expectedStemCount {
            record("stem 数量错误，期望 \(expectedStemCount)，实际 \(actualStemCount)。")
        }

        let actualLedgerLineCount = scene.strokeItems.filter { $0.semantic == .ledgerLine }.count
        if actualLedgerLineCount != fixture.expectedLedgerLineCount {
            record("ledger line 数量错误，期望 \(fixture.expectedLedgerLineCount)，实际 \(actualLedgerLineCount)。")
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
        fixture: StaffValidationFixture,
        record: (String) -> Void
    ) {
        let accidentalGlyphs = scene.glyphs.filter(\.symbolID.isAccidental)
        let accidentalFrames = accidentalGlyphs.compactMap { frame(of: $0) }
        if accidentalFrames.count != accidentalGlyphs.count {
            record("存在 accidental glyph 不是 frame placement。")
            return
        }

        let expectedAccidentalSymbols = fixture.score.notes.compactMap {
            accidentalSymbolID(for: $0.pitch.accidental)
        }
        let actualAccidentalSymbols = accidentalGlyphs.map(\.symbolID)
        if actualAccidentalSymbols != expectedAccidentalSymbols {
            record("accidental glyph 类型序列错误，期望 \(expectedAccidentalSymbols)，实际 \(actualAccidentalSymbols)。")
        }

        let noteheadFrames = scene.glyphs.filter(\.symbolID.isNotehead).compactMap { frame(of: $0) }
        var accidentalIndex = 0
        for (noteIndex, note) in fixture.score.notes.enumerated() where note.pitch.accidental != .natural {
            guard
                accidentalIndex < accidentalFrames.count,
                noteIndex < noteheadFrames.count
            else {
                record("accidental 与 notehead 的映射数量不一致。")
                break
            }

            let accidentalFrame = accidentalFrames[accidentalIndex]
            let noteheadFrame = noteheadFrames[noteIndex]
            if accidentalFrame.maxX >= noteheadFrame.minX {
                record("accidental[\(accidentalIndex)] 没有落在 notehead[\(noteIndex)] 左侧。")
            }

            accidentalIndex += 1
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
            "启动 App，确认五线谱除 clef 外还能看到 demo notehead、stem 和 accidental，且没有回退成 clef-only 场景。",
            "在 settings 中切换 Treble / Bass，确认同一组 demo notes 会按新 clef 重新布局，accidental 仍位于 notehead 左侧。",
            "观察包含高低音边界的音符，确认 ledger line 会随音符出现且与 notehead 对齐。",
            "调整窗口大小或设备方向，确认 note spacing 与 glyph 位置稳定更新，不出现 clefArea 与 noteArea 重叠。"
        ]

        switch platform {
        case .iOS:
            checklist.append("在 iOS 上验证 settings 打开/关闭与滚动共存时，五线谱内容不会闪烁或错位。")
        case .macOS:
            checklist.append("在 macOS 上执行 live resize，确认五线谱中的 notehead / stem / ledger line 在 resize 过程中保持稳定。")
        case .commandLine:
            checklist.append("命令行只覆盖共享层 scene fixture，不覆盖 iOS/macOS 运行时渲染与交互。")
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

    static func accidentalSymbolID(
        for accidental: StaffAccidental
    ) -> StaffGlyphSymbolID? {
        switch accidental {
        case .flat:
            return .accidentalFlat
        case .natural:
            return nil
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

private extension StaffGlyphSymbolID {
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
}
