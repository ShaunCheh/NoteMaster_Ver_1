//
//  PlaybackValidation.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/4/7.
//

import Foundation

enum PlaybackValidationPlatform: String {
    case iOS
    case macOS
    case commandLine

    var displayName: String {
        rawValue
    }
}

struct PlaybackValidationIssue: Equatable {
    var fixtureName: String
    var message: String
}

struct PlaybackValidationReport {
    var platform: PlaybackValidationPlatform
    var fixtureCount: Int
    var passedFixtureNames: [String]
    var issues: [PlaybackValidationIssue]
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
        [PlaybackValidation][\(platform.displayName)] automated=\(automatedStatus) fixtures=\(fixtureCount)
        通过夹具: \(passedFixturesText)
        自动化问题:
        \(issuesText)
        手工回归清单:
        \(checklistText)
        """
    }
}

enum PlaybackValidationRunner {
    static func run(platform: PlaybackValidationPlatform) -> PlaybackValidationReport {
        let fixtures = makeFixtures()
        var passedFixtureNames: [String] = []
        var issues: [PlaybackValidationIssue] = []
        print("[PlaybackValidation][\(platform.displayName)] begin fixtures=\(fixtures.count)")

        for fixture in fixtures {
            print("[PlaybackValidation][\(platform.displayName)] fixture begin name=\(fixture.name)")
            let fixtureIssues = fixture.validate()
            print(
                "[PlaybackValidation][\(platform.displayName)] fixture end name=\(fixture.name) issues=\(fixtureIssues.count)"
            )
            if fixtureIssues.isEmpty {
                passedFixtureNames.append(fixture.name)
            } else {
                issues.append(contentsOf: fixtureIssues)
            }
        }

        print("[PlaybackValidation][\(platform.displayName)] end totalIssues=\(issues.count)")

        return PlaybackValidationReport(
            platform: platform,
            fixtureCount: fixtures.count,
            passedFixtureNames: passedFixtureNames,
            issues: issues,
            manualChecklist: manualChecklist(for: platform)
        )
    }

    static func runAndReportIfNeeded(platform: PlaybackValidationPlatform) {
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

private struct PlaybackValidationFixture {
    var name: String
    var validate: () -> [PlaybackValidationIssue]
}

private enum PlaybackValidationBackendCommand: Equatable {
    case start(NotePitch)
    case replace(NotePitch)
    case stop
}

private final class PlaybackValidationBackendSpy: PlaybackAudioBackend {
    var commands: [PlaybackValidationBackendCommand] = []

    func startPreview(note: NotePitch) {
        commands.append(.start(note))
    }

    func replacePreview(note: NotePitch) {
        commands.append(.replace(note))
    }

    func stopPreview() {
        commands.append(.stop)
    }
}

private extension PlaybackValidationRunner {
    static func makeFixtures() -> [PlaybackValidationFixture] {
        [
            PlaybackValidationFixture(
                name: "preview_lifecycle_routes_start_replace_stop",
                validate: validatePreviewLifecycle
            ),
            PlaybackValidationFixture(
                name: "changed_then_ended_does_not_leave_hanging_note",
                validate: validateChangedThenEnded
            ),
            PlaybackValidationFixture(
                name: "stale_preview_end_is_ignored",
                validate: validateStalePreviewEnd
            ),
            PlaybackValidationFixture(
                name: "force_stop_clears_active_preview",
                validate: validateForceStop
            ),
            PlaybackValidationFixture(
                name: "rows_changed_is_ignored",
                validate: validateRowsChangedIgnored
            )
        ]
    }

    static func manualChecklist(for platform: PlaybackValidationPlatform) -> [String] {
        [
            "在 \(platform.displayName) 上确认 play 页面按下钢琴键会立即发声，保持按下时不会断音。",
            "确认横向滑音时旧音会被当前音替换，松手后立即停音。",
            "确认切换 exercise/play、关闭窗口层级、隐藏当前页面或 view disappear 后，不会残留悬空音。",
            "确认修改钢琴行数、步进按钮改 row、settings 触发重建时，旧预览音会被强制打断。"
        ]
    }

    static func validatePreviewLifecycle() -> [PlaybackValidationIssue] {
        let fixtureName = "preview_lifecycle_routes_start_replace_stop"
        let spy = PlaybackValidationBackendSpy()
        let coordinator = PlaybackCoordinator(backend: spy)
        let startedPreview = PianoPreviewState(
            rowIndex: 0,
            note: note(.c, octave: 4)
        )
        let changedPreview = PianoPreviewState(
            rowIndex: 0,
            note: note(.d, octave: 4)
        )

        coordinator.handle(.previewStarted(startedPreview))
        coordinator.handle(.previewChanged(changedPreview))
        coordinator.handle(.previewEnded(changedPreview))

        var issues: [PlaybackValidationIssue] = []
        if spy.commands != [
            .start(note(.c, octave: 4)),
            .replace(note(.d, octave: 4)),
            .stop
        ] {
            issues.append(issue(fixtureName, "preview 生命周期应映射成 start -> replace -> stop。"))
        }
        if coordinator.currentPreview != nil {
            issues.append(issue(fixtureName, "previewEnded 后不应残留 currentPreview。"))
        }
        return issues
    }

    static func validateChangedThenEnded() -> [PlaybackValidationIssue] {
        let fixtureName = "changed_then_ended_does_not_leave_hanging_note"
        let spy = PlaybackValidationBackendSpy()
        let coordinator = PlaybackCoordinator(backend: spy)
        let startedPreview = PianoPreviewState(
            rowIndex: 1,
            note: note(.f, octave: 4)
        )
        let finalPreview = PianoPreviewState(
            rowIndex: 1,
            note: note(.fSharp, octave: 4)
        )

        coordinator.handle(.previewStarted(startedPreview))
        coordinator.handle(.previewChanged(finalPreview))
        coordinator.handle(.previewEnded(finalPreview))

        var issues: [PlaybackValidationIssue] = []
        if coordinator.currentPreview != nil {
            issues.append(issue(fixtureName, "previewChanged + previewEnded 背靠背后不应残留 active preview。"))
        }
        if Array(spy.commands.suffix(2)) != [
            .replace(note(.fSharp, octave: 4)),
            .stop
        ] {
            issues.append(issue(fixtureName, "最终切音后应立即停音，不得遗漏 stop。"))
        }
        return issues
    }

    static func validateStalePreviewEnd() -> [PlaybackValidationIssue] {
        let fixtureName = "stale_preview_end_is_ignored"
        let spy = PlaybackValidationBackendSpy()
        let coordinator = PlaybackCoordinator(backend: spy)
        let startedPreview = PianoPreviewState(
            rowIndex: 0,
            note: note(.g, octave: 4)
        )
        let currentPreview = PianoPreviewState(
            rowIndex: 0,
            note: note(.a, octave: 4)
        )

        coordinator.handle(.previewStarted(startedPreview))
        coordinator.handle(.previewChanged(currentPreview))
        coordinator.handle(.previewEnded(startedPreview))

        var issues: [PlaybackValidationIssue] = []
        if coordinator.currentPreview != currentPreview {
            issues.append(issue(fixtureName, "过期 previewEnded 不应把当前音错误停掉。"))
        }
        if spy.commands != [
            .start(note(.g, octave: 4)),
            .replace(note(.a, octave: 4))
        ] {
            issues.append(issue(fixtureName, "过期 previewEnded 不应额外触发 stop。"))
        }
        return issues
    }

    static func validateForceStop() -> [PlaybackValidationIssue] {
        let fixtureName = "force_stop_clears_active_preview"
        let spy = PlaybackValidationBackendSpy()
        let coordinator = PlaybackCoordinator(backend: spy)

        coordinator.handle(
            .previewStarted(
                PianoPreviewState(
                    rowIndex: 2,
                    note: note(.b, octave: 3)
                )
            )
        )
        coordinator.forceStop(reason: .rootModeChanged)

        var issues: [PlaybackValidationIssue] = []
        if coordinator.currentPreview != nil {
            issues.append(issue(fixtureName, "forceStop 后 currentPreview 应被清空。"))
        }
        if spy.commands != [
            .start(note(.b, octave: 3)),
            .stop
        ] {
            issues.append(issue(fixtureName, "forceStop 应向 backend 追加 stop 命令。"))
        }
        return issues
    }

    static func validateRowsChangedIgnored() -> [PlaybackValidationIssue] {
        let fixtureName = "rows_changed_is_ignored"
        let spy = PlaybackValidationBackendSpy()
        let coordinator = PlaybackCoordinator(backend: spy)

        coordinator.handle(.rowsChanged(PianoSurfaceDefaults.rows))

        if !spy.commands.isEmpty {
            return [issue(fixtureName, "rowsChanged 不应直接触发 backend 命令。")]
        }
        return []
    }

    static func note(
        _ pitchClass: PitchClass,
        octave: Int
    ) -> NotePitch {
        NotePitch(pitchClass: pitchClass, octave: octave)
    }

    static func issue(
        _ fixtureName: String,
        _ message: String
    ) -> PlaybackValidationIssue {
        PlaybackValidationIssue(
            fixtureName: fixtureName,
            message: message
        )
    }
}
