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
        let decodeCases = makeDecodeCases()
        let fixtures = makeFixtures()
        var passedFixtureNames: [String] = []
        var issues: [StaffValidationIssue] = []
        print(
            "[StaffValidation][\(platform.displayName)] begin decodeCases=\(decodeCases.count) fixtures=\(fixtures.count)"
        )

        for decodeCase in decodeCases {
            print("[StaffValidation][\(platform.displayName)] decode begin name=\(decodeCase.name)")
            let decodeCaseIssues = validate(decodeCase)
            print(
                "[StaffValidation][\(platform.displayName)] decode end name=\(decodeCase.name) issues=\(decodeCaseIssues.count)"
            )
            if decodeCaseIssues.isEmpty {
                passedFixtureNames.append(decodeCase.name)
            } else {
                issues.append(contentsOf: decodeCaseIssues)
            }
        }

        for fixture in fixtures {
            print("[StaffValidation][\(platform.displayName)] fixture begin name=\(fixture.name)")
            let fixtureIssues = validate(fixture)
            print(
                "[StaffValidation][\(platform.displayName)] fixture end name=\(fixture.name) issues=\(fixtureIssues.count)"
            )
            if fixtureIssues.isEmpty {
                passedFixtureNames.append(fixture.name)
            } else {
                issues.append(contentsOf: fixtureIssues)
            }
        }

        print("[StaffValidation][\(platform.displayName)] end totalIssues=\(issues.count)")

        return StaffValidationReport(
            platform: platform,
            fixtureCount: decodeCases.count + fixtures.count,
            passedFixtureNames: passedFixtureNames,
            issues: issues,
            manualChecklist: manualChecklist(for: platform)
        )
    }

    static func runAndReportIfNeeded(platform: StaffValidationPlatform) {
        #if DEBUG
        print("[StaffValidation][\(platform.displayName)] runAndReportIfNeeded begin")
        let report = run(platform: platform)
        let summary = report.debugSummary()
        print(summary)
        print("[StaffValidation][\(platform.displayName)] runAndReportIfNeeded end passing=\(report.isPassing)")

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
    var sequencePresentation: StaffSequencePresentation?
}

private struct StaffValidationExpectedNoteAccidental: Equatable {
    var noteIndex: Int
    var symbolID: StaffGlyphSymbolID
}

private struct StaffValidationDecodeCase {
    var name: String
    var json: String
    var expectation: StaffValidationDecodeExpectation
}

private enum StaffValidationDecodeExpectation {
    case success(
        clef: StaffClef,
        keySignatureFifths: Int,
        measureCount: Int,
        noteCount: Int
    )
    case failure(StaffScoreDecodingError)
}

private extension StaffValidationRunner {
    static let tolerance: CGFloat = 0.001
    static let fixtureWidth: CGFloat = 860

    static func makeDecodeCases() -> [StaffValidationDecodeCase] {
        [
            decodeCase(
                name: "decode-key-d-major-zh-inline",
                json: decodeScoreJSON(
                    keySignatureField: #""keySignature": "D大调""#
                ),
                expectedKeySignatureFifths: 2
            ),
            decodeCase(
                name: "decode-key-a-major-zh-inline",
                json: decodeScoreJSON(
                    keySignatureField: #""keySignature": "A大调""#
                ),
                expectedKeySignatureFifths: 3
            ),
            decodeCase(
                name: "decode-key-d-major-en-inline",
                json: decodeScoreJSON(
                    keySignatureField: #""keySignature": "D major""#
                ),
                expectedKeySignatureFifths: 2
            ),
            decodeCase(
                name: "decode-key-a-major-en-inline",
                json: decodeScoreJSON(
                    keySignatureField: #""keySignature": "A major""#
                ),
                expectedKeySignatureFifths: 3
            ),
            decodeCase(
                name: "decode-key-bb-major-en-inline",
                json: decodeScoreJSON(
                    keySignatureField: #""keySignature": "Bb major""#
                ),
                expectedKeySignatureFifths: -2
            ),
            decodeCase(
                name: "decode-key-bb-major-zh-inline",
                json: decodeScoreJSON(
                    keySignatureField: #""keySignature": "降B大调""#
                ),
                expectedKeySignatureFifths: -2
            ),
            decodeCase(
                name: "decode-key-fsharp-major-en-inline",
                json: decodeScoreJSON(
                    keySignatureField: #""keySignature": "F# major""#
                ),
                expectedKeySignatureFifths: 6
            ),
            decodeCase(
                name: "decode-key-fsharp-major-zh-inline",
                json: decodeScoreJSON(
                    keySignatureField: #""keySignature": "升F大调""#
                ),
                expectedKeySignatureFifths: 6
            ),
            decodeCase(
                name: "decode-key-a-bare-tonic-inline",
                json: decodeScoreJSON(
                    keySignatureField: #""keySignature": "a""#
                ),
                expectedKeySignatureFifths: 3
            ),
            decodeFailureCase(
                name: "decode-key-a-minor-en-unsupported",
                json: decodeScoreJSON(
                    keySignatureField: #""keySignature": "A minor""#
                ),
                expectedError: .unsupportedKeySignatureMode("A minor")
            ),
            decodeFailureCase(
                name: "decode-key-a-minor-zh-unsupported",
                json: decodeScoreJSON(
                    keySignatureField: #""keySignature": "A小调""#
                ),
                expectedError: .unsupportedKeySignatureMode("A小调")
            ),
            decodeFailureCase(
                name: "decode-key-fsharp-minor-keyed-fifths-unsupported",
                json: decodeScoreJSON(
                    keySignatureField: #""keySignature": { "fifths": "F# minor" }"#
                ),
                expectedError: .unsupportedKeySignatureMode("F# minor")
            ),
            decodeCase(
                name: "decode-key-d-major-english-keyed-fifths",
                json: decodeScoreJSON(
                    keySignatureField: #""keySignature": { "fifths": "D大调" }"#
                ),
                expectedKeySignatureFifths: 2
            ),
            decodeCase(
                name: "decode-key-a-major-chinese-keyed-fifths",
                json: decodeScoreJSON(
                    clefField: #""谱号": "高音""#,
                    keySignatureField: #""调号": { "升降号个数": "A major" }"#,
                    notesField: """
                    "音符": [
                      { "音高": "c4", "时值": "quarter" }
                    ]
                    """
                ),
                expectedKeySignatureFifths: 3
            )
        ]
    }

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
            ("a", StaffKeySignature(fifths: 3)),
            ("e", StaffKeySignature(fifths: 4)),
            ("b", StaffKeySignature(fifths: 5)),
            ("fsharp", StaffKeySignature(fifths: 6)),
            ("csharp", StaffKeySignature(fifths: 7)),
            ("f", StaffKeySignature(fifths: -1)),
            ("bb", StaffKeySignature(fifths: -2)),
            ("eb", StaffKeySignature(fifths: -3)),
            ("ab", StaffKeySignature(fifths: -4)),
            ("db", StaffKeySignature(fifths: -5)),
            ("gb", StaffKeySignature(fifths: -6)),
            ("cb", StaffKeySignature(fifths: -7))
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
                name: "treble-named-key-demo-full-notation",
                configuration: trebleConfiguration,
                score: StaffScoreFixtures.namedKeySignatureDemo(clef: .treble),
                notationDisplayOptions: .fullNotation,
                expectedDisplayedNoteAccidentals: [
                    noteAccidental(noteIndex: 3, accidental: .flat),
                    noteAccidental(noteIndex: 4, accidental: .natural),
                    noteAccidental(noteIndex: 7, accidental: .natural)
                ]
            ),
            fixture(
                name: "treble-sequence-initial-cursor-default-demo",
                configuration: trebleConfiguration,
                score: StaffScoreFixtures.defaultDemo(clef: .treble),
                notationDisplayOptions: .fullNotation,
                expectedDisplayedNoteAccidentals: [
                    noteAccidental(noteIndex: 1, accidental: .sharp),
                    noteAccidental(noteIndex: 3, accidental: .flat)
                ],
                sequencePresentation: .idle(cursorIndex: 0)
            ),
            fixture(
                name: "treble-sequence-wrong-current-accidental-feedback",
                configuration: trebleConfiguration,
                score: StaffScoreFixtures.defaultDemo(clef: .treble),
                notationDisplayOptions: .fullNotation,
                expectedDisplayedNoteAccidentals: [
                    noteAccidental(noteIndex: 1, accidental: .sharp),
                    noteAccidental(noteIndex: 3, accidental: .flat)
                ],
                sequencePresentation: .wrong(
                    cursorIndex: 1,
                    evaluatedIndex: 1
                )
            ),
            fixture(
                name: "treble-sequence-correct-ledger-advance",
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
                expectedLedgerLineCount: 4,
                sequencePresentation: .correct(
                    cursorIndex: 2,
                    evaluatedIndex: 1
                )
            ),
            fixture(
                name: "treble-sequence-completed-no-cursor",
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
                expectedLedgerLineCount: 4,
                sequencePresentation: .completed(
                    lastEvaluatedIndex: 2,
                    lastEvaluationResult: .correct
                )
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
                name: "treble-a-major-context-reset",
                configuration: trebleConfiguration,
                score: StaffScoreFixtures.aMajorAccidentalContextReference(),
                notationDisplayOptions: .fullNotation,
                expectedDisplayedNoteAccidentals: [
                    noteAccidental(noteIndex: 3, accidental: .natural),
                    noteAccidental(noteIndex: 4, accidental: .sharp),
                    noteAccidental(noteIndex: 5, accidental: .natural),
                    noteAccidental(noteIndex: 7, accidental: .natural),
                    noteAccidental(noteIndex: 9, accidental: .natural),
                    noteAccidental(noteIndex: 10, accidental: .natural),
                    noteAccidental(noteIndex: 11, accidental: .natural)
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
        expectedDisplayedNoteAccidentals: [StaffValidationExpectedNoteAccidental] = [],
        sequencePresentation: StaffSequencePresentation? = nil
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
            expectedDisplayedNoteAccidentals: expectedDisplayedNoteAccidentals,
            sequencePresentation: sequencePresentation
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

    static func decodeCase(
        name: String,
        json: String,
        expectedKeySignatureFifths: Int,
        expectedClef: StaffClef = .treble,
        expectedMeasureCount: Int = 1,
        expectedNoteCount: Int = 1
    ) -> StaffValidationDecodeCase {
        StaffValidationDecodeCase(
            name: name,
            json: json,
            expectation: .success(
                clef: expectedClef,
                keySignatureFifths: expectedKeySignatureFifths,
                measureCount: expectedMeasureCount,
                noteCount: expectedNoteCount
            )
        )
    }

    static func decodeFailureCase(
        name: String,
        json: String,
        expectedError: StaffScoreDecodingError
    ) -> StaffValidationDecodeCase {
        StaffValidationDecodeCase(
            name: name,
            json: json,
            expectation: .failure(expectedError)
        )
    }

    static func decodeScoreJSON(
        clefField: String = #""clef": "treble""#,
        keySignatureField: String,
        notesField: String = """
        "notes": [
          { "pitch": "c4", "duration": "quarter" }
        ]
        """
    ) -> String {
        """
        {
          \(clefField),
          \(keySignatureField),
          \(notesField)
        }
        """
    }

    static func validate(_ decodeCase: StaffValidationDecodeCase) -> [StaffValidationIssue] {
        var issues: [StaffValidationIssue] = []

        func record(_ message: String) {
            issues.append(
                StaffValidationIssue(
                    fixtureName: decodeCase.name,
                    message: message
                )
            )
        }

        switch decodeCase.expectation {
        case let .success(
            expectedClef,
            expectedKeySignatureFifths,
            expectedMeasureCount,
            expectedNoteCount
        ):
            let score: StaffScore
            do {
                score = try StaffScore.decode(from: decodeCase.json)
            } catch {
                record("命名调号解码失败：\(error)。")
                return issues
            }

            if score.clef != expectedClef {
                record("clef 解码错误，期望 \(expectedClef)，实际 \(score.clef)。")
            }

            if score.keySignature.fifths != expectedKeySignatureFifths {
                record("key signature fifths 解码错误，期望 \(expectedKeySignatureFifths)，实际 \(score.keySignature.fifths)。")
            }

            if score.measures.count != expectedMeasureCount {
                record("measure 数量错误，期望 \(expectedMeasureCount)，实际 \(score.measures.count)。")
            }

            if score.notes.count != expectedNoteCount {
                record("note 数量错误，期望 \(expectedNoteCount)，实际 \(score.notes.count)。")
            }
        case let .failure(expectedError):
            do {
                _ = try StaffScore.decode(from: decodeCase.json)
                record("命名调号解码本应失败，但实际成功。")
            } catch let actualError as StaffScoreDecodingError {
                if actualError != expectedError {
                    record("命名调号解码错误不匹配，期望 \(expectedError)，实际 \(actualError)。")
                }
            } catch {
                record("命名调号解码错误类型不匹配，期望 \(expectedError)，实际 \(error)。")
            }
        }

        return issues
    }

    static func validate(_ fixture: StaffValidationFixture) -> [StaffValidationIssue] {
        let geometry = StaffGeometry(
            configuration: fixture.configuration,
            bounds: fixture.bounds
        )
        let scene = StaffSceneProvider(
            clef: fixture.configuration.clef,
            score: fixture.score,
            notationDisplayOptions: fixture.notationDisplayOptions,
            sequencePresentation: fixture.sequencePresentation
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
        validateSequencePresentation(
            scene: scene,
            geometry: geometry,
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

        let expectedCursorCount = fixture.sequencePresentation?.showsCursor == true ? 1 : 0
        let actualCursorCount = scene.strokeItems.filter { $0.semantic == .sequenceCursor }.count
        if actualCursorCount != expectedCursorCount {
            record("sequence cursor 数量错误，期望 \(expectedCursorCount)，实际 \(actualCursorCount)。")
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

            if frame.minX <= geometry.clefVisibleMaxX(for: fixture.configuration.clef) + tolerance {
                record("notehead[\(noteIndex)] 侵入 clef 可见边界。")
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

        if let firstKeySignatureFrame = actualKeySignatureFrames.first {
            let expectedStartX = geometry.clefContentStartX(
                for: fixture.configuration.clef,
                gapInSpaces: StaffSceneBuilder.LayoutMetrics.default.clefToNoteGapInSpaces
            )
            if !approximatelyEqual(firstKeySignatureFrame.minX, expectedStartX) {
                record("首个 key signature accidental 起点错误，期望 \(expectedStartX)，实际 \(firstKeySignatureFrame.minX)。")
            }

            if firstKeySignatureFrame.minX <= geometry.clefVisibleMaxX(for: fixture.configuration.clef) + tolerance {
                record("首个 key signature accidental 侵入 clef 可见边界。")
            }
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
            case .sequenceCursor:
                if !approximatelyEqual(stroke.start.x, stroke.end.x) {
                    record("sequenceCursor[\(index)] 不是竖线。")
                }

                if !(stroke.end.y > stroke.start.y + tolerance) {
                    record("sequenceCursor[\(index)] 高度非法。")
                }
            }
        }
    }

    static func validateSequencePresentation(
        scene: StaffScene,
        geometry: StaffGeometry,
        fixture: StaffValidationFixture,
        record: (String) -> Void
    ) {
        guard let sequencePresentation = fixture.sequencePresentation else {
            return
        }

        let noteheadGlyphs = scene.glyphs.filter(\.symbolID.isNotehead)
        let noteheadFrames = noteheadGlyphs.compactMap { frame(of: $0) }
        guard noteheadFrames.count == noteheadGlyphs.count,
              noteheadFrames.count == fixture.score.notes.count else {
            record("sequence fixture 的 notehead frame 映射不完整，无法校验游标与反馈颜色。")
            return
        }

        if let highlightedIndex = sequencePresentation.lastEvaluatedIndex,
           highlightedIndex >= noteheadGlyphs.count {
            record("sequence presentation 的 lastEvaluatedIndex 超出 notehead 范围。")
        }

        let cursorStrokes = scene.strokeItems.filter { $0.semantic == .sequenceCursor }
        if let cursorIndex = sequencePresentation.cursorIndex {
            guard cursorIndex < noteheadFrames.count else {
                record("sequence presentation 的 cursorIndex 超出 notehead 范围。")
                return
            }

            if let cursorStroke = cursorStrokes.first {
                let expectedX = noteheadFrames[cursorIndex].midX
                if !approximatelyEqual(cursorStroke.start.x, expectedX)
                    || !approximatelyEqual(cursorStroke.end.x, expectedX) {
                    record("sequence cursor 未对齐到 notehead[\(cursorIndex)] 的中心 X。")
                }

                if !approximatelyEqual(cursorStroke.start.y, geometry.drawingRect.minY)
                    || !approximatelyEqual(cursorStroke.end.y, geometry.drawingRect.maxY) {
                    record("sequence cursor 的纵向范围未对齐 geometry.drawingRect。")
                }

                if cursorStroke.style.strokeColor != .sequenceCursorBlue {
                    record("sequence cursor 颜色错误，期望 \(StaffSceneColor.sequenceCursorBlue)，实际 \(cursorStroke.style.strokeColor)。")
                }
            }
        } else if !cursorStrokes.isEmpty {
            record("完成态或无游标态不应生成 sequence cursor。")
        }

        for (noteIndex, noteheadGlyph) in noteheadGlyphs.enumerated() {
            let expectedTintColor = expectedSequenceTintColor(
                noteIndex: noteIndex,
                presentation: sequencePresentation
            )
            if noteheadGlyph.tintColor != expectedTintColor {
                record("notehead[\(noteIndex)] 的 sequence tintColor 错误，期望 \(expectedTintColor)，实际 \(noteheadGlyph.tintColor)。")
            }
        }

        let accidentalGlyphs = scene.glyphs.filter(\.symbolID.isAccidental)
        let keySignatureAccidentalCount = expectedKeySignatureAccidentalSymbols(
            for: fixture
        ).count
        let keySignatureAccidentalGlyphs = Array(
            accidentalGlyphs.prefix(keySignatureAccidentalCount)
        )
        for (index, glyph) in keySignatureAccidentalGlyphs.enumerated() {
            if glyph.tintColor != .primaryInk {
                record("key signature accidental[\(index)] 不应被 sequence 反馈着色。")
            }
        }

        let noteAccidentalGlyphs = Array(
            accidentalGlyphs.dropFirst(keySignatureAccidentalCount)
        )
        let expectedNoteAccidentals = expectedDisplayedNoteAccidentals(for: fixture)
        for (index, glyph) in noteAccidentalGlyphs.enumerated() {
            guard index < expectedNoteAccidentals.count else {
                break
            }

            let noteIndex = expectedNoteAccidentals[index].noteIndex
            let expectedTintColor = expectedSequenceTintColor(
                noteIndex: noteIndex,
                presentation: sequencePresentation
            )
            if glyph.tintColor != expectedTintColor {
                record("note accidental[\(index)] 的 sequence tintColor 错误，期望 \(expectedTintColor)，实际 \(glyph.tintColor)。")
            }
        }

        let feedbackStrokes = scene.strokeItems.filter {
            $0.semantic == .stem || $0.semantic == .ledgerLine
        }
        for (index, stroke) in feedbackStrokes.enumerated() {
            guard let noteIndex = noteIndex(for: stroke, noteheadFrames: noteheadFrames) else {
                record("feedback stroke[\(index)] 无法映射到对应的 notehead。")
                continue
            }

            let expectedTintColor = expectedSequenceTintColor(
                noteIndex: noteIndex,
                presentation: sequencePresentation
            )
            if stroke.style.strokeColor != expectedTintColor {
                record("\(stroke.semantic)[\(index)] 的 sequence tintColor 错误，期望 \(expectedTintColor)，实际 \(stroke.style.strokeColor)。")
            }
        }
    }

    static func manualChecklist(for platform: StaffValidationPlatform) -> [String] {
        var checklist = [
            "启动 App，确认默认五线谱已恢复完整记谱显示，且默认 demo 已切到命名调号输入示例：当前应能看到 `D大调` 对应的 key signature，同时保留 stem，以及需要时的 accidental / ledger line。",
            "将共享 score 临时切到 `StaffScoreFixtures.keySignatureReference(...)` 的 major circle-of-fifths 参考谱例：`C / G / D / A / E / B / F# / C# / F / Bb / Eb / Ab / Db / Gb / Cb`，并在 Treble / Bass 间切换；确认调号 glyph 数量、sharp/flat 顺序和垂直落点正确，同时首个调号 glyph 紧贴 clef 实际可见右边界，不再被整块 clefArea 预留宽度推得过远。",
            "把调号输入临时切成命名形式，例如 `D大调`、`A大调`、`D major`、`A major`，以及 keyed 对象形式 `{ \"fifths\": \"D大调\" }`；确认 scene 结果与直接传 `fifths` 等价。同时确认 bare token `a` 仍按 `A大调` 兼容，而 `A minor / A小调` 当前会在 decode 边界明确拒绝。",
            "将共享 score 切到 `StaffScoreFixtures.gMajorAccidentalContextReference()`，确认同小节里 `f#` 会被调号抑制、写出 `f natural` 后同小节再次 `f#` 会重新显示 sharp，跨小节后恢复调号默认规则。",
            "将共享 score 切到 `StaffScoreFixtures.aMajorAccidentalContextReference()`，确认 A major 下 `F# / C# / G#` 默认会被调号抑制；写出 `f natural` 后同小节再次 `f#` 会重新显示 sharp；同小节写出的 `c natural / g natural` 到下一小节会再次显示 natural，证明 measure reset 生效。",
            "将共享 score 切到 `StaffScoreFixtures.bbMajorBassAccidentalContextReference()`，确认 Bass + Bb major 下 `bb3` 默认不显示 accidental，`b3` 显示 natural，跨小节后再次按调号默认值重置。",
            "显式把 `staffDisplayState.notationDisplayOptions` 切到 `.noteheadsOnly` 再切回 `.fullNotation`，确认 notehead 可见性稳定，且 accidental / stem / ledger line 能正确隐藏与恢复。",
            "把 `TopContent` 切到 `Staff` 且 `Exercise Mode` 切到 `Sequence`：确认初始竖线游标准确对齐当前目标音；错误作答时当前音变红且游标不前进；正确作答时刚答中的音变绿且游标前进；完成整条序列后游标隐藏，但最后一次反馈颜色仍保留。随后切到 `Target Prompt` 再切回 `Staff`，确认旧红/绿反馈不会泄漏回来，只保留当前进度对应的中性游标或完成态。",
            "调整窗口大小或设备方向，确认 key signature 区与 note 区不会重叠，note spacing 与 glyph 位置稳定更新。"
        ]

        switch platform {
        case .iOS:
            checklist.append("在 iOS 上验证 settings 打开/关闭与滚动共存时，完整记谱场景不会闪烁、错位或因为调号变宽而破坏滚动体验。")
        case .macOS:
            checklist.append("在 macOS 上执行 live resize，确认调号区和音符区在 resize 过程中保持稳定，不出现 accidental 抖动或重叠。")
        case .commandLine:
            checklist.append("命令行已覆盖命名调号 decode 回归、bare token 兼容策略、当前未实现的小调拒绝分支，以及共享层 scene fixture；不覆盖 iOS/macOS 运行时渲染、字体注册与交互。")
        }

        return checklist
    }

    static func frame(of glyphItem: StaffGlyphItem) -> CGRect? {
        guard case let .frame(frame) = glyphItem.placement else {
            return nil
        }

        return frame
    }

    static func expectedSequenceTintColor(
        noteIndex: Int,
        presentation: StaffSequencePresentation
    ) -> StaffSceneColor {
        guard presentation.lastEvaluatedIndex == noteIndex else {
            return .primaryInk
        }

        switch presentation.lastEvaluationResult {
        case .correct?:
            return .sequenceCorrectGreen
        case .incorrect?:
            return .sequenceIncorrectRed
        case nil:
            return .primaryInk
        }
    }

    static func noteIndex(
        for stroke: StaffStrokeItem,
        noteheadFrames: [CGRect]
    ) -> Int? {
        let strokeMidX = (stroke.start.x + stroke.end.x) / 2
        if let containingIndex = noteheadFrames.firstIndex(where: {
            strokeMidX >= $0.minX - tolerance && strokeMidX <= $0.maxX + tolerance
        }) {
            return containingIndex
        }

        return noteheadFrames.enumerated().min {
            abs($0.element.midX - strokeMidX) < abs($1.element.midX - strokeMidX)
        }?.offset
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
