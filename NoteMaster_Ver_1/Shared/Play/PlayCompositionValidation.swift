//
//  PlayCompositionValidation.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/4/7.
//

import Foundation

enum PlayCompositionValidationPlatform: String {
    case iOS
    case macOS
    case commandLine

    var displayName: String {
        rawValue
    }
}

struct PlayCompositionValidationIssue: Equatable {
    var fixtureName: String
    var message: String
}

struct PlayCompositionValidationReport {
    var platform: PlayCompositionValidationPlatform
    var fixtureCount: Int
    var passedFixtureNames: [String]
    var issues: [PlayCompositionValidationIssue]
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
            : issues.map { "- [\($0.fixtureName)] \($0.message)" }
                .joined(separator: "\n")
        let checklistText = manualChecklist.enumerated().map {
            "\($0.offset + 1). \($0.element)"
        }.joined(separator: "\n")

        return """
        [PlayCompositionValidation][\(platform.displayName)] automated=\(automatedStatus) fixtures=\(fixtureCount)
        通过夹具: \(passedFixturesText)
        自动化问题:
        \(issuesText)
        手工回归清单:
        \(checklistText)
        """
    }
}

enum PlayCompositionValidationRunner {
    static func run(
        platform: PlayCompositionValidationPlatform
    ) -> PlayCompositionValidationReport {
        let fixtures = makeFixtures()
        var passedFixtureNames: [String] = []
        var issues: [PlayCompositionValidationIssue] = []
        print(
            "[PlayCompositionValidation][\(platform.displayName)] begin fixtures=\(fixtures.count)"
        )

        for fixture in fixtures {
            print(
                "[PlayCompositionValidation][\(platform.displayName)] fixture begin name=\(fixture.name)"
            )
            let fixtureIssues = validate(fixture)
            print(
                "[PlayCompositionValidation][\(platform.displayName)] fixture end name=\(fixture.name) issues=\(fixtureIssues.count)"
            )
            if fixtureIssues.isEmpty {
                passedFixtureNames.append(fixture.name)
            } else {
                issues.append(contentsOf: fixtureIssues)
            }
        }

        print(
            "[PlayCompositionValidation][\(platform.displayName)] end totalIssues=\(issues.count)"
        )

        return PlayCompositionValidationReport(
            platform: platform,
            fixtureCount: fixtures.count,
            passedFixtureNames: passedFixtureNames,
            issues: issues,
            manualChecklist: manualChecklist(for: platform)
        )
    }

    static func runAndReportIfNeeded(
        platform: PlayCompositionValidationPlatform
    ) {
        #if DEBUG
        print(
            "[PlayCompositionValidation][\(platform.displayName)] runAndReportIfNeeded begin"
        )
        let report = run(platform: platform)
        let summary = report.debugSummary()
        print(summary)
        print(
            "[PlayCompositionValidation][\(platform.displayName)] runAndReportIfNeeded end passing=\(report.isPassing)"
        )

        if !report.isPassing {
            assertionFailure(summary)
        }
        #endif
    }
}

private struct PlayCompositionValidationFixture {
    var name: String
    var validate: () -> [PlayCompositionValidationIssue]
}

private extension PlayCompositionValidationRunner {
    static func validate(
        _ fixture: PlayCompositionValidationFixture
    ) -> [PlayCompositionValidationIssue] {
        fixture.validate()
    }

    static func makeFixtures() -> [PlayCompositionValidationFixture] {
        [
            PlayCompositionValidationFixture(
                name: "play_policy_emits_single_piano_surface",
                validate: validatePlayPolicyEmitsSinglePianoSurface
            ),
            PlayCompositionValidationFixture(
                name: "play_policy_keeps_piano_visible_and_interactive",
                validate: validatePlayPolicyKeepsPianoVisibleAndInteractive
            )
        ]
    }

    static func validatePlayPolicyEmitsSinglePianoSurface()
        -> [PlayCompositionValidationIssue] {
        let presentation = PlayCompositionPolicy.makePresentation()
        var issues: [PlayCompositionValidationIssue] = []

        if presentation.scene.surfaceNodes.count != 1 {
            issues.append(
                issue(
                    fixture: "play_policy_emits_single_piano_surface",
                    message: "play scene 应只包含 1 个 surface。"
                )
            )
        }

        if presentation.scene.surfaceNodes.first?.id != .piano {
            issues.append(
                issue(
                    fixture: "play_policy_emits_single_piano_surface",
                    message: "play scene 的唯一 surface 应为 piano。"
                )
            )
        }

        if presentation.scene.containsSurface(.fretboard)
            || presentation.scene.containsSurface(.staff)
            || presentation.scene.containsSurface(.targetPrompt)
            || presentation.scene.containsSurface(.naturalNoteStrip) {
            issues.append(
                issue(
                    fixture: "play_policy_emits_single_piano_surface",
                    message: "play scene 不应混入非 piano surface。"
                )
            )
        }

        let structureIssues = SceneValidator.validate(presentation.scene)
        if !structureIssues.isEmpty {
            issues.append(
                issue(
                    fixture: "play_policy_emits_single_piano_surface",
                    message: "play scene 的通用结构校验未通过：\(structureIssues)"
                )
            )
        }

        return issues
    }

    static func validatePlayPolicyKeepsPianoVisibleAndInteractive()
        -> [PlayCompositionValidationIssue] {
        let presentation = PlayCompositionPolicy.makePresentation()
        let pianoState = presentation.effectiveSurfaceState(for: .piano)
        var issues: [PlayCompositionValidationIssue] = []

        if !pianoState.isVisible {
            issues.append(
                issue(
                    fixture: "play_policy_keeps_piano_visible_and_interactive",
                    message: "piano 在 play scene 中必须可见。"
                )
            )
        }

        if !pianoState.isInteractionEnabled {
            issues.append(
                issue(
                    fixture: "play_policy_keeps_piano_visible_and_interactive",
                    message: "piano 在 play scene 中必须可交互。"
                )
            )
        }

        return issues
    }

    static func manualChecklist(
        for platform: PlayCompositionValidationPlatform
    ) -> [String] {
        switch platform {
        case .iOS, .macOS:
            return [
                "切到 play 页面后，确认首屏只剩 piano，没有 fretboard/staff/notestrip。",
                "后续接入真实 play UI 时，确认 piano 的交互状态与这里的 scene policy 输出一致。"
            ]
        case .commandLine:
            return [
                "命令行模式下无需额外手工检查。"
            ]
        }
    }

    static func issue(
        fixture: String,
        message: String
    ) -> PlayCompositionValidationIssue {
        PlayCompositionValidationIssue(
            fixtureName: fixture,
            message: message
        )
    }
}
