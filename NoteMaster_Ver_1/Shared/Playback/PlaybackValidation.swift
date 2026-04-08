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
    case start(PlaybackVoiceID, NotePitch)
    case update(PlaybackVoiceID, NotePitch)
    case stop(PlaybackVoiceID)
    case stopAll
}

private final class PlaybackValidationBackendSpy: PlaybackAudioBackend {
    var commands: [PlaybackValidationBackendCommand] = []

    func startVoice(_ voiceID: PlaybackVoiceID, note: NotePitch) {
        commands.append(.start(voiceID, note))
    }

    func updateVoice(_ voiceID: PlaybackVoiceID, note: NotePitch) {
        commands.append(.update(voiceID, note))
    }

    func stopVoice(_ voiceID: PlaybackVoiceID) {
        commands.append(.stop(voiceID))
    }

    func stopAllVoices() {
        commands.append(.stopAll)
    }
}

private extension PlaybackValidationRunner {
    static func makeFixtures() -> [PlaybackValidationFixture] {
        [
            PlaybackValidationFixture(
                name: "multiple_voices_start_independently",
                validate: validateMultipleVoiceStart
            ),
            PlaybackValidationFixture(
                name: "single_voice_update_does_not_replace_siblings",
                validate: validateSingleVoiceUpdate
            ),
            PlaybackValidationFixture(
                name: "single_voice_stop_does_not_stop_siblings",
                validate: validateSingleVoiceStop
            ),
            PlaybackValidationFixture(
                name: "stale_preview_end_is_ignored_per_voice",
                validate: validateStalePreviewEndIsolation
            ),
            PlaybackValidationFixture(
                name: "force_stop_stops_all_voices",
                validate: validateForceStopStopsAllVoices
            ),
            PlaybackValidationFixture(
                name: "rows_changed_is_ignored",
                validate: validateRowsChangedIgnored
            )
        ]
    }

    static func manualChecklist(for platform: PlaybackValidationPlatform) -> [String] {
        [
            "在 \(platform.displayName) 上确认双指和弦可并发发声，抬起其中一指时另一指不会被误停。",
            "确认快速交替两个音时，stale previewEnded 不会把当前仍活动的 voice 停掉。",
            "确认 glissando 与另一根手指保持和弦并发时，只会更新对应 voice，另一 voice 持续发声。",
            "确认切换 exercise/play、关闭页面、view disappear 或禁用交互时，所有活动 voice 都会可靠 stop all。",
            "确认 play mode 与 exercise accessory piano 都共享同一套复音播放行为。"
        ]
    }

    static func validateMultipleVoiceStart() -> [PlaybackValidationIssue] {
        let fixtureName = "multiple_voices_start_independently"
        let spy = PlaybackValidationBackendSpy()
        let coordinator = PlaybackCoordinator(backend: spy)
        let voiceA = preview(
            id: 1,
            rowIndex: 0,
            note: note(.c, octave: 4)
        )
        let voiceB = preview(
            id: 2,
            rowIndex: 1,
            note: note(.g, octave: 4)
        )

        coordinator.handle(.previewStarted(voiceA))
        coordinator.handle(.previewStarted(voiceB))

        var issues: [PlaybackValidationIssue] = []
        if spy.commands != [
            .start(voiceA.voiceID, note(.c, octave: 4)),
            .start(voiceB.voiceID, note(.g, octave: 4))
        ] {
            issues.append(issue(fixtureName, "两个 previewStarted 应分别路由成两个独立的 start voice 命令。"))
        }
        if coordinator.activeVoices != [
            voiceA.voiceID: voiceA,
            voiceB.voiceID: voiceB
        ] {
            issues.append(issue(fixtureName, "activeVoices 应同时保留两个活动 voice。"))
        }
        if coordinator.currentPreview != voiceA {
            issues.append(issue(fixtureName, "兼容访问口 currentPreview 应稳定指向最小 voiceID 对应的 preview。"))
        }
        return issues
    }

    static func validateSingleVoiceUpdate() -> [PlaybackValidationIssue] {
        let fixtureName = "single_voice_update_does_not_replace_siblings"
        let spy = PlaybackValidationBackendSpy()
        let coordinator = PlaybackCoordinator(backend: spy)
        let voiceAStarted = preview(
            id: 1,
            rowIndex: 0,
            note: note(.c, octave: 4)
        )
        let voiceB = preview(
            id: 2,
            rowIndex: 1,
            note: note(.g, octave: 4)
        )
        let voiceAChanged = preview(
            id: 1,
            rowIndex: 0,
            note: note(.d, octave: 4)
        )

        coordinator.handle(.previewStarted(voiceAStarted))
        coordinator.handle(.previewStarted(voiceB))
        coordinator.handle(.previewChanged(voiceAChanged))

        var issues: [PlaybackValidationIssue] = []
        if coordinator.activeVoices[voiceAChanged.voiceID] != voiceAChanged {
            issues.append(issue(fixtureName, "单 voice update 后，voiceA 应刷新为最新 preview。"))
        }
        if coordinator.activeVoices[voiceB.voiceID] != voiceB {
            issues.append(issue(fixtureName, "更新 voiceA 时，不应把并发的 voiceB 从 activeVoices 中挤掉。"))
        }
        if spy.commands != [
            .start(voiceAStarted.voiceID, note(.c, octave: 4)),
            .start(voiceB.voiceID, note(.g, octave: 4)),
            .update(voiceAChanged.voiceID, note(.d, octave: 4))
        ] {
            issues.append(issue(fixtureName, "单 voice previewChanged 只应路由成该 voice 的 update 命令。"))
        }
        return issues
    }

    static func validateSingleVoiceStop() -> [PlaybackValidationIssue] {
        let fixtureName = "single_voice_stop_does_not_stop_siblings"
        let spy = PlaybackValidationBackendSpy()
        let coordinator = PlaybackCoordinator(backend: spy)
        let voiceA = preview(
            id: 1,
            rowIndex: 0,
            note: note(.g, octave: 4)
        )
        let voiceB = preview(
            id: 2,
            rowIndex: 1,
            note: note(.b, octave: 3)
        )

        coordinator.handle(.previewStarted(voiceA))
        coordinator.handle(.previewStarted(voiceB))
        coordinator.handle(.previewEnded(voiceA))

        var issues: [PlaybackValidationIssue] = []
        if coordinator.activeVoices[voiceA.voiceID] != nil {
            issues.append(issue(fixtureName, "previewEnded 后，voiceA 应从 activeVoices 中移除。"))
        }
        if coordinator.activeVoices[voiceB.voiceID] != voiceB {
            issues.append(issue(fixtureName, "停止 voiceA 时，不应把并发的 voiceB 一起停掉。"))
        }
        if spy.commands != [
            .start(voiceA.voiceID, note(.g, octave: 4)),
            .start(voiceB.voiceID, note(.b, octave: 3)),
            .stop(voiceA.voiceID)
        ] {
            issues.append(issue(fixtureName, "单 voice stop 只应路由成对应 voice 的 stop 命令。"))
        }
        return issues
    }

    static func validateStalePreviewEndIsolation() -> [PlaybackValidationIssue] {
        let fixtureName = "stale_preview_end_is_ignored_per_voice"
        let spy = PlaybackValidationBackendSpy()
        let coordinator = PlaybackCoordinator(backend: spy)
        let voiceAStarted = preview(
            id: 1,
            rowIndex: 0,
            note: note(.g, octave: 4)
        )
        let voiceAChanged = preview(
            id: 1,
            rowIndex: 0,
            note: note(.a, octave: 4)
        )
        let voiceB = preview(
            id: 2,
            rowIndex: 1,
            note: note(.c, octave: 5)
        )

        coordinator.handle(.previewStarted(voiceAStarted))
        coordinator.handle(.previewStarted(voiceB))
        coordinator.handle(.previewChanged(voiceAChanged))
        coordinator.handle(.previewEnded(voiceAStarted))

        var issues: [PlaybackValidationIssue] = []
        if coordinator.activeVoices[voiceAChanged.voiceID] != voiceAChanged {
            issues.append(issue(fixtureName, "过期 previewEnded 不应把已 update 的 voiceA 错误移除。"))
        }
        if coordinator.activeVoices[voiceB.voiceID] != voiceB {
            issues.append(issue(fixtureName, "过期 previewEnded 不应影响其他并发 voice。"))
        }
        if spy.commands != [
            .start(voiceAStarted.voiceID, note(.g, octave: 4)),
            .start(voiceB.voiceID, note(.c, octave: 5)),
            .update(voiceAChanged.voiceID, note(.a, octave: 4))
        ] {
            issues.append(issue(fixtureName, "过期 previewEnded 不应额外触发 stop 或 stopAll 命令。"))
        }
        return issues
    }

    static func validateForceStopStopsAllVoices() -> [PlaybackValidationIssue] {
        let fixtureName = "force_stop_stops_all_voices"
        let spy = PlaybackValidationBackendSpy()
        let coordinator = PlaybackCoordinator(backend: spy)
        let voiceA = preview(
            id: 1,
            rowIndex: 0,
            note: note(.b, octave: 3)
        )
        let voiceB = preview(
            id: 2,
            rowIndex: 1,
            note: note(.e, octave: 4)
        )

        coordinator.handle(.previewStarted(voiceA))
        coordinator.handle(.previewStarted(voiceB))
        coordinator.forceStop(reason: .rootModeChanged)

        var issues: [PlaybackValidationIssue] = []
        if !coordinator.activeVoices.isEmpty || coordinator.currentPreview != nil {
            issues.append(issue(fixtureName, "forceStop 后不应残留任何活动 voice。"))
        }
        if spy.commands != [
            .start(voiceA.voiceID, note(.b, octave: 3)),
            .start(voiceB.voiceID, note(.e, octave: 4)),
            .stopAll
        ] {
            issues.append(issue(fixtureName, "forceStop 应路由成 stopAllVoices，而不是只停最后一路 voice。"))
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

    static func preview(
        id: UInt64,
        rowIndex: Int,
        note: NotePitch
    ) -> PianoPreviewState {
        PianoPreviewState(
            previewID: PianoPreviewID(rawValue: id),
            rowIndex: rowIndex,
            note: note
        )
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
