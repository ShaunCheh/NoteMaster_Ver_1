//
//  FretboardValidation.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/25.
//

import Foundation
import CoreGraphics

enum FretboardValidationPlatform: String {
    case iOS
    case macOS
    case commandLine

    var displayName: String {
        rawValue
    }
}

struct FretboardValidationIssue: Equatable {
    var fixtureName: String
    var message: String
}

struct FretboardValidationReport {
    var platform: FretboardValidationPlatform
    var fixtureCount: Int
    var passedFixtureNames: [String]
    var issues: [FretboardValidationIssue]
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
        [FretboardValidation][\(platform.displayName)] automated=\(automatedStatus) fixtures=\(fixtureCount)
        通过夹具: \(passedFixturesText)
        自动化问题:
        \(issuesText)
        手工回归清单:
        \(checklistText)
        """
    }
}

enum FretboardValidationRunner {
    static func run(platform: FretboardValidationPlatform) -> FretboardValidationReport {
        let fixtures = makeFixtures()
        var passedFixtureNames: [String] = []
        var issues: [FretboardValidationIssue] = []

        for fixture in fixtures {
            let fixtureIssues = validate(fixture)
            if fixtureIssues.isEmpty {
                passedFixtureNames.append(fixture.name)
            } else {
                issues.append(contentsOf: fixtureIssues)
            }
        }

        return FretboardValidationReport(
            platform: platform,
            fixtureCount: fixtures.count,
            passedFixtureNames: passedFixtureNames,
            issues: issues,
            manualChecklist: manualChecklist(for: platform)
        )
    }

    static func runAndReportIfNeeded(platform: FretboardValidationPlatform) {
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

private struct FretboardValidationFixture {
    var name: String
    var configuration: FretboardConfiguration
    var bounds: CGRect
}

private extension FretboardValidationRunner {
    static let tolerance: CGFloat = 0.001
    static let horizontalFixtureWidth: CGFloat = 860
    static let verticalFixtureHeight: CGFloat = 520

    static func makeFixtures() -> [FretboardValidationFixture] {
        [
            horizontalFixture(
                name: "horizontal-guitar6-reference",
                instrument: .guitar6
            ),
            horizontalFixture(
                name: "horizontal-bass4-reference",
                instrument: .bass4
            ),
            horizontalFixture(
                name: "horizontal-bass5-reference",
                instrument: .bass5
            ),
            verticalFixture(
                name: "vertical-guitar6-height-driven",
                instrument: .guitar6
            ),
            verticalFixture(
                name: "vertical-bass4-height-driven",
                instrument: .bass4
            ),
            verticalFixture(
                name: "vertical-bass5-height-driven",
                instrument: .bass5
            ),
            verticalFixture(
                name: "vertical-guitar6-width-constrained",
                instrument: .guitar6,
                widthOverride: 120
            )
        ]
    }

    static func horizontalFixture(
        name: String,
        instrument: InstrumentType
    ) -> FretboardValidationFixture {
        let configuration = FretboardConfiguration(
            displayMode: .horizontal,
            tuning: .standard(for: instrument),
            maxFret: 12
        )
        let height = configuration.resolvedHeight(forAvailableWidth: horizontalFixtureWidth)

        return FretboardValidationFixture(
            name: name,
            configuration: configuration,
            bounds: CGRect(
                origin: .zero,
                size: CGSize(
                    width: horizontalFixtureWidth,
                    height: height
                )
            )
        )
    }

    static func verticalFixture(
        name: String,
        instrument: InstrumentType,
        widthOverride: CGFloat? = nil
    ) -> FretboardValidationFixture {
        let configuration = FretboardConfiguration(
            displayMode: .vertical,
            tuning: .standard(for: instrument),
            maxFret: 12
        )
        let contentLayout = configuration.verticalContentLayout(
            forViewportHeight: verticalFixtureHeight
        )
        let width = widthOverride ?? contentLayout.contentWidth

        return FretboardValidationFixture(
            name: name,
            configuration: configuration,
            bounds: CGRect(
                origin: .zero,
                size: CGSize(
                    width: width,
                    height: contentLayout.contentSize.height
                )
            )
        )
    }

    static func validate(_ fixture: FretboardValidationFixture) -> [FretboardValidationIssue] {
        let sceneBuilder = FretboardSceneBuilder(configuration: fixture.configuration)
        let scene = sceneBuilder.makeScene(bounds: fixture.bounds)
        var issues: [FretboardValidationIssue] = []

        func record(_ message: String) {
            issues.append(
                FretboardValidationIssue(
                    fixtureName: fixture.name,
                    message: message
                )
            )
        }

        guard !scene.drawingRect.isNull, !scene.drawingRect.isEmpty else {
            record("scene.drawingRect 为空，未生成有效几何。")
            return issues
        }

        validateBoundsContainment(
            scene: scene,
            fixture: fixture,
            record: record
        )
        validateVerticalHeightConsumption(
            scene: scene,
            fixture: fixture,
            record: record
        )
        validateSceneCounts(
            scene: scene,
            fixture: fixture,
            record: record
        )
        validateCellAndAnchorMapping(
            scene: scene,
            fixture: fixture,
            record: record
        )
        validateCellAspectRatio(
            scene: scene,
            fixture: fixture,
            record: record
        )
        validateAxisOrientation(
            scene: scene,
            fixture: fixture,
            record: record
        )
        validateMarkerPlacements(
            scene: scene,
            fixture: fixture,
            record: record
        )
        validateHitTesting(
            scene: scene,
            fixture: fixture,
            sceneBuilder: sceneBuilder,
            record: record
        )
        validatePitchResolution(
            fixture: fixture,
            record: record
        )
        validateNaturalNoteTrainer(
            fixture: fixture,
            record: record
        )
        validateQuarterNoteSequenceTrainer(
            fixture: fixture,
            record: record
        )

        return issues
    }

    static func validateBoundsContainment(
        scene: FretboardScene,
        fixture: FretboardValidationFixture,
        record: (String) -> Void
    ) {
        if !contains(rect: scene.drawingRect, in: fixture.bounds) {
            record("drawingRect 越出 fixture bounds。")
        }

        if scene.openStringRect.isNull || scene.nutRect.isNull || scene.fretboardRect.isNull {
            record("openStringRect / nutRect / fretboardRect 中存在空矩形。")
        }

        if !contains(rect: scene.openStringRect, in: scene.drawingRect) {
            record("openStringRect 未包含在 drawingRect 内。")
        }

        if !contains(rect: scene.fretboardRect, in: scene.drawingRect) {
            record("fretboardRect 未包含在 drawingRect 内。")
        }

        if !scene.nutRect.intersects(scene.drawingRect) {
            record("nutRect 未与 drawingRect 相交。")
        }

        if let fretZeroRect = scene.fretSpanRect(at: 0),
           !approximatelyEqual(rect: fretZeroRect, other: scene.openStringRect) {
            record("openStringRect 与 fret 0 的 span rect 不一致。")
        }
    }

    static func validateVerticalHeightConsumption(
        scene: FretboardScene,
        fixture: FretboardValidationFixture,
        record: (String) -> Void
    ) {
        guard fixture.configuration.displayMode == .vertical else {
            return
        }

        let fullHeightContentWidth = fixture.configuration.verticalContentWidth(
            forViewportHeight: fixture.bounds.height
        )
        guard fixture.bounds.width + tolerance >= fullHeightContentWidth else {
            return
        }

        if !approximatelyEqual(scene.drawingRect.minY, fixture.bounds.minY)
            || !approximatelyEqual(scene.drawingRect.maxY, fixture.bounds.maxY) {
            record("vertical 高度驱动场景下 drawingRect 未优先吃满 bounds.height。")
        }
    }

    static func validateSceneCounts(
        scene: FretboardScene,
        fixture: FretboardValidationFixture,
        record: (String) -> Void
    ) {
        let configuration = fixture.configuration
        let expectedCellCount = configuration.stringCount * configuration.displayPositionCount

        if scene.stringSegments.count != configuration.stringCount {
            record("stringSegments 数量错误，期望 \(configuration.stringCount)，实际 \(scene.stringSegments.count)。")
        }

        if scene.fretSegments.count != configuration.maxFret {
            record("fretSegments 数量错误，期望 \(configuration.maxFret)，实际 \(scene.fretSegments.count)。")
        }

        if scene.cellFrames.count != expectedCellCount {
            record("cellFrames 数量错误，期望 \(expectedCellCount)，实际 \(scene.cellFrames.count)。")
        }

        if scene.labelAnchors.count != expectedCellCount {
            record("labelAnchors 数量错误，期望 \(expectedCellCount)，实际 \(scene.labelAnchors.count)。")
        }

        let expectedMarkers = Set(configuration.markerLayout.allMarkerFrets(upTo: configuration.maxFret))
        let actualMarkers = Set(scene.markerPlacements.map(\.fret))
        if expectedMarkers != actualMarkers {
            record("marker fret 集合不一致，期望 \(expectedMarkers.sorted())，实际 \(actualMarkers.sorted())。")
        }
    }

    static func validateCellAndAnchorMapping(
        scene: FretboardScene,
        fixture: FretboardValidationFixture,
        record: (String) -> Void
    ) {
        for anchor in scene.labelAnchors {
            guard let cellFrame = scene.cellFrame(stringIndex: anchor.stringIndex, fret: anchor.fret) else {
                record("label anchor(\(anchor.stringIndex), \(anchor.fret)) 找不到对应 cell frame。")
                continue
            }

            if !approximatelyEqual(rect: cellFrame, other: anchor.cellFrame) {
                record("label anchor(\(anchor.stringIndex), \(anchor.fret)) 的 cellFrame 与 scene 不一致。")
            }

            if !contains(point: anchor.center, in: anchor.cellFrame) {
                record("label anchor(\(anchor.stringIndex), \(anchor.fret)) 的 center 未落在 cellFrame 内。")
            }
        }

        let expectedPairs = Set(
            fixture.configuration.fretRange.flatMap { fret in
                (0..<fixture.configuration.stringCount).map { stringIndex in
                    "\(stringIndex)-\(fret)"
                }
            }
        )
        let actualPairs = Set(scene.cellFrames.map { "\($0.stringIndex)-\($0.fret)" })
        if actualPairs != expectedPairs {
            record("scene.cellFrames 的 string/fret 组合不完整。")
        }
    }

    static func validateCellAspectRatio(
        scene: FretboardScene,
        fixture: FretboardValidationFixture,
        record: (String) -> Void
    ) {
        let ratio = max(
            fixture.configuration.layoutMetrics.cellWidthToHeightRatio,
            tolerance
        )
        let expectedWidthToHeightRatio: CGFloat

        switch fixture.configuration.displayMode {
        case .horizontal:
            expectedWidthToHeightRatio = ratio
        case .vertical:
            expectedWidthToHeightRatio = 1 / ratio
        }

        for cell in scene.cellFrames {
            guard cell.frame.width > 0, cell.frame.height > 0 else {
                record("cell(\(cell.stringIndex), \(cell.fret)) 的尺寸非法。")
                continue
            }

            let actualWidthToHeightRatio = cell.frame.width / cell.frame.height
            if !approximatelyEqual(actualWidthToHeightRatio, expectedWidthToHeightRatio) {
                record(
                    "cell(\(cell.stringIndex), \(cell.fret)) 的 width/height 比例错误，期望 \(expectedWidthToHeightRatio)，实际 \(actualWidthToHeightRatio)。"
                )
                break
            }
        }
    }

    static func validateAxisOrientation(
        scene: FretboardScene,
        fixture: FretboardValidationFixture,
        record: (String) -> Void
    ) {
        let configuration = fixture.configuration
        let orderedStrings = scene.stringSegments.sorted { $0.stringIndex < $1.stringIndex }
        let orderedFrets = scene.fretSegments.sorted { $0.fret < $1.fret }

        switch configuration.displayMode {
        case .horizontal:
            for segment in orderedStrings {
                if !approximatelyEqual(segment.start.y, segment.end.y) {
                    record("horizontal 模式下 string segment \(segment.stringIndex) 不是横线。")
                }
            }

            for segment in orderedFrets {
                if !approximatelyEqual(segment.start.x, segment.end.x) {
                    record("horizontal 模式下 fret segment \(segment.fret) 不是竖线。")
                }
            }

            if !isStrictlyIncreasing(orderedStrings.map { midpoint(of: $0).y }) {
                record("horizontal 模式下弦序没有按低音到高音沿 y 轴递增。")
            }

            if !isStrictlyIncreasing(orderedFrets.map(\.start.x)) {
                record("horizontal 模式下品位没有沿 x 轴递增。")
            }

            if let firstCell = scene.cellFrames.first,
               !(firstCell.frame.width > firstCell.frame.height + tolerance) {
                record("horizontal 模式下 cell 长边应沿 x 轴。")
            }

            if !approximatelyEqual(scene.nutRect.midX, scene.openStringRect.maxX) {
                record("horizontal 模式下 nutRect 没有对齐到空弦区域右侧。")
            }

            if scene.fretboardRect.minX + tolerance < scene.nutRect.maxX {
                record("horizontal 模式下 fretboardRect 起点早于 nutRect 末端。")
            }
        case .vertical:
            for segment in orderedStrings {
                if !approximatelyEqual(segment.start.x, segment.end.x) {
                    record("vertical 模式下 string segment \(segment.stringIndex) 不是竖线。")
                }
            }

            for segment in orderedFrets {
                if !approximatelyEqual(segment.start.y, segment.end.y) {
                    record("vertical 模式下 fret segment \(segment.fret) 不是横线。")
                }
            }

            if !isStrictlyIncreasing(orderedStrings.map { midpoint(of: $0).x }) {
                record("vertical 模式下弦序没有按低音到高音沿 x 轴递增。")
            }

            if !isStrictlyIncreasing(orderedFrets.map(\.start.y)) {
                record("vertical 模式下品位没有沿 y 轴递增。")
            }

            if let firstCell = scene.cellFrames.first,
               !(firstCell.frame.height > firstCell.frame.width + tolerance) {
                record("vertical 模式下 cell 长边应沿 y 轴。")
            }

            if !approximatelyEqual(scene.nutRect.midY, scene.openStringRect.maxY) {
                record("vertical 模式下 nutRect 没有对齐到空弦区域下侧。")
            }

            if scene.fretboardRect.minY + tolerance < scene.nutRect.maxY {
                record("vertical 模式下 fretboardRect 起点早于 nutRect 末端。")
            }
        }
    }

    static func validateMarkerPlacements(
        scene: FretboardScene,
        fixture: FretboardValidationFixture,
        record: (String) -> Void
    ) {
        for marker in scene.markerPlacements {
            if marker.diameter <= 0 {
                record("marker(\(marker.fret)) 的 diameter 非法。")
            }

            for center in marker.centers where !contains(point: center, in: scene.drawingRect) {
                record("marker(\(marker.fret)) 的中心点超出 drawingRect。")
            }

            switch marker.style {
            case .singleDot:
                if marker.centers.count != 1 {
                    record("singleDot marker(\(marker.fret)) 的中心点数量应为 1，实际 \(marker.centers.count)。")
                }
            case .doubleDot:
                if marker.centers.count != 2 {
                    record("doubleDot marker(\(marker.fret)) 的中心点数量应为 2，实际 \(marker.centers.count)。")
                    continue
                }

                let firstCenter = marker.centers[0]
                let secondCenter = marker.centers[1]
                switch fixture.configuration.displayMode {
                case .horizontal:
                    if !approximatelyEqual(firstCenter.x, secondCenter.x) {
                        record("horizontal 模式下 doubleDot marker(\(marker.fret)) 应共享 x 坐标。")
                    }
                    if approximatelyEqual(firstCenter.y, secondCenter.y) {
                        record("horizontal 模式下 doubleDot marker(\(marker.fret)) 应沿 y 轴分离。")
                    }
                case .vertical:
                    if !approximatelyEqual(firstCenter.y, secondCenter.y) {
                        record("vertical 模式下 doubleDot marker(\(marker.fret)) 应共享 y 坐标。")
                    }
                    if approximatelyEqual(firstCenter.x, secondCenter.x) {
                        record("vertical 模式下 doubleDot marker(\(marker.fret)) 应沿 x 轴分离。")
                    }
                }
            }
        }
    }

    static func validateHitTesting(
        scene: FretboardScene,
        fixture: FretboardValidationFixture,
        sceneBuilder: FretboardSceneBuilder,
        record: (String) -> Void
    ) {
        for anchor in scene.labelAnchors {
            let hit = sceneBuilder.hitTest(
                anchor.center,
                phase: .began,
                scene: scene
            )
            let expectedCell = FretboardCell(
                stringIndex: anchor.stringIndex,
                fret: anchor.fret
            )

            if hit.cell != expectedCell {
                record("命中测试未命中中心点 (\(anchor.stringIndex), \(anchor.fret))，实际 \(String(describing: hit.cell))。")
            }

            if !hit.isInsideDrawingRect {
                record("命中测试中心点 (\(anchor.stringIndex), \(anchor.fret)) 时 inside 标记为 false。")
            }
        }

        let outsidePoint = CGPoint(
            x: scene.drawingRect.minX - 1,
            y: scene.drawingRect.minY - 1
        )
        let outsideHit = sceneBuilder.hitTest(
            outsidePoint,
            phase: .began,
            scene: scene
        )
        if outsideHit.cell != nil || outsideHit.isInsideDrawingRect {
            record("drawingRect 外部点仍然命中了有效格子。")
        }
    }

    static func validatePitchResolution(
        fixture: FretboardValidationFixture,
        record: (String) -> Void
    ) {
        let configuration = fixture.configuration

        for stringIndex in 0..<configuration.stringCount {
            guard let openPitch = configuration.tuning.openStringPitch(for: stringIndex) else {
                record("string[\(stringIndex)] 找不到空弦音高。")
                continue
            }

            for fret in configuration.fretRange {
                let expectedPitch = openPitch.advanced(by: fret)
                let cell = FretboardCell(
                    stringIndex: stringIndex,
                    fret: fret
                )

                guard let resolvedPitch = configuration.notePitch(
                    stringIndex: stringIndex,
                    fret: fret
                ) else {
                    record("cell(\(stringIndex), \(fret)) 无法解析 NotePitch。")
                    continue
                }

                if resolvedPitch != expectedPitch {
                    record(
                        "cell(\(stringIndex), \(fret)) NotePitch 解析错误，期望 \(expectedPitch.displayText())，实际 \(resolvedPitch.displayText())。"
                    )
                }

                if configuration.notePitch(for: cell) != expectedPitch {
                    record("cell(\(stringIndex), \(fret)) 的 cell 入口 NotePitch 解析与直接入口不一致。")
                }

                if configuration.pitchClass(
                    stringIndex: stringIndex,
                    fret: fret
                ) != expectedPitch.pitchClass {
                    record("cell(\(stringIndex), \(fret)) 的 pitchClass 解析与 NotePitch 不一致。")
                }

                if configuration.pitchClass(for: cell) != expectedPitch.pitchClass {
                    record("cell(\(stringIndex), \(fret)) 的 cell 入口 pitchClass 解析与直接入口不一致。")
                }
            }
        }

        if configuration.notePitch(stringIndex: -1, fret: 0) != nil {
            record("非法 stringIndex(-1) 仍然解析出了 NotePitch。")
        }

        if configuration.notePitch(
            stringIndex: configuration.stringCount,
            fret: 0
        ) != nil {
            record("越界 stringIndex(\(configuration.stringCount)) 仍然解析出了 NotePitch。")
        }

        if configuration.notePitch(stringIndex: 0, fret: -1) != nil {
            record("非法 fret(-1) 仍然解析出了 NotePitch。")
        }

        if configuration.notePitch(
            stringIndex: 0,
            fret: configuration.maxFret + 1
        ) != nil {
            record("越界 fret(\(configuration.maxFret + 1)) 仍然解析出了 NotePitch。")
        }
    }

    static func validateNaturalNoteTrainer(
        fixture: FretboardValidationFixture,
        record: (String) -> Void
    ) {
        guard fixture.name == "horizontal-guitar6-reference" else {
            return
        }

        let configuration = fixture.configuration
        let correctCell = FretboardCell(stringIndex: 2, fret: 10)
        let accidentalCell = FretboardCell(stringIndex: 1, fret: 4)
        let invalidCell = FretboardCell(
            stringIndex: configuration.stringCount,
            fret: 0
        )

        guard let correctPitch = configuration.notePitch(for: correctCell) else {
            record("trainer 验证基准 cell(\(correctCell.stringIndex), \(correctCell.fret)) 无法解析 NotePitch。")
            return
        }

        if correctPitch.pitchClass != .c {
            record(
                "trainer 正确命中基准 cell(\(correctCell.stringIndex), \(correctCell.fret)) 应为 C，实际 \(correctPitch.displayText())。"
            )
        }

        guard let accidentalPitch = configuration.notePitch(for: accidentalCell) else {
            record("trainer 验证 accidental cell(\(accidentalCell.stringIndex), \(accidentalCell.fret)) 无法解析 NotePitch。")
            return
        }

        if accidentalPitch.pitchClass == .c || !accidentalPitch.pitchClass.isAccidental {
            record(
                "trainer 错误命中基准 cell(\(accidentalCell.stringIndex), \(accidentalCell.fret)) 应为非 C 的升降音，实际 \(accidentalPitch.displayText())。"
            )
        }

        var ignoredPhaseTrainer = FretboardNaturalNoteTrainerState(targetPitchClass: .c)
        let ignoredPhaseResult = ignoredPhaseTrainer.handle(
            hitResult: makeHitResult(
                phase: .began,
                cell: correctCell
            ),
            configuration: configuration
        )
        if ignoredPhaseResult != .ignored(.nonEndedPhase(.began)) {
            record("trainer 对非 ended 事件未返回 ignored(.nonEndedPhase(.began))。")
        }
        if ignoredPhaseTrainer.targetPitchClass != .c {
            record("trainer 在忽略非 ended 事件后不应推进目标音。")
        }

        var missingHitTrainer = FretboardNaturalNoteTrainerState(targetPitchClass: .c)
        let missingHitResult = missingHitTrainer.handle(
            hitResult: makeHitResult(
                phase: .ended,
                cell: nil
            ),
            configuration: configuration
        )
        if missingHitResult != .ignored(.missingHitCell) {
            record("trainer 对空命中事件未返回 ignored(.missingHitCell)。")
        }
        if missingHitTrainer.targetPitchClass != .c {
            record("trainer 在忽略空命中事件后不应推进目标音。")
        }

        var unresolvedHitTrainer = FretboardNaturalNoteTrainerState(targetPitchClass: .c)
        let unresolvedHitResult = unresolvedHitTrainer.handle(
            hitResult: makeHitResult(
                phase: .ended,
                cell: invalidCell
            ),
            configuration: configuration
        )
        if unresolvedHitResult != .ignored(.unresolvedHitPitch(invalidCell)) {
            record("trainer 对不可解析 cell 未返回 ignored(.unresolvedHitPitch)。")
        }
        if unresolvedHitTrainer.targetPitchClass != .c {
            record("trainer 在忽略不可解析 cell 后不应推进目标音。")
        }

        var incorrectTrainer = FretboardNaturalNoteTrainerState(targetPitchClass: .c)
        switch incorrectTrainer.handle(
            hitResult: makeHitResult(
                phase: .ended,
                cell: accidentalCell
            ),
            configuration: configuration
        ) {
        case let .evaluated(evaluation):
            if evaluation.selectedPitch != accidentalPitch {
                record("trainer 错误命中时返回的 selectedPitch 与配置解析结果不一致。")
            }
            if evaluation.isCorrect {
                record("trainer 把 \(accidentalPitch.displayText()) 错判成了目标音 C。")
            }
            if evaluation.didAdvanceTarget {
                record("trainer 在答错后不应把 didAdvanceTarget 标记为 true。")
            }
            if evaluation.nextTargetPitchClass != .c {
                record("trainer 在答错后不应切换到下一题。")
            }
            if incorrectTrainer.targetPitchClass != .c {
                record("trainer 在答错后不应修改当前目标音状态。")
            }
        default:
            record("trainer 对升降音错误命中未返回 evaluated 结果。")
        }

        var correctTrainer = FretboardNaturalNoteTrainerState(targetPitchClass: .c)
        switch correctTrainer.handle(
            hitResult: makeHitResult(
                phase: .ended,
                cell: correctCell
            ),
            configuration: configuration
        ) {
        case let .evaluated(evaluation):
            if evaluation.selectedPitch != correctPitch {
                record("trainer 正确命中时返回的 selectedPitch 与配置解析结果不一致。")
            }
            if !evaluation.isCorrect {
                record("trainer 未把不同八度的 C 判定为正确。")
            }
            if !evaluation.didAdvanceTarget {
                record("trainer 在答对后应把 didAdvanceTarget 标记为 true。")
            }
            if evaluation.nextTargetPitchClass == .c {
                record("trainer 在答对后未切换到新的目标音。")
            }
            if evaluation.nextTargetPitchClass.isAccidental {
                record("trainer 在答对后切换到了非自然音目标。")
            }
            if correctTrainer.targetPitchClass != evaluation.nextTargetPitchClass {
                record("trainer 内部状态与 evaluation.nextTargetPitchClass 不一致。")
            }
        default:
            record("trainer 对正确命中未返回 evaluated 结果。")
        }
    }

    static func validateQuarterNoteSequenceTrainer(
        fixture: FretboardValidationFixture,
        record: (String) -> Void
    ) {
        guard fixture.name == "horizontal-guitar6-reference" else {
            return
        }

        let naturalSpec = FretboardNaturalNoteTrainerState.QuarterNoteSequenceSpec(
            clef: .treble,
            noteCount: 7,
            includesAccidentals: false
        )
        var naturalTrainer = FretboardNaturalNoteTrainerState(
            quarterNoteSequenceSpec: naturalSpec
        )
        let naturalPrompt = naturalTrainer.generateQuarterNoteSequencePrompt()
        validateQuarterNoteSequencePrompt(
            naturalPrompt,
            expectedSpec: naturalSpec,
            requiresNaturalOnly: true,
            requiresAccidentalEvidence: false,
            record: record
        )
        guard case let .quarterNoteSequence(resolvedNaturalSpec) = naturalTrainer.mode else {
            record("quarter-note trainer 初始化后 mode 应为 .quarterNoteSequence。")
            return
        }
        if resolvedNaturalSpec != naturalSpec {
            record("quarter-note trainer 的 natural spec 与初始化参数不一致。")
        }
        if naturalTrainer.quarterNoteSequencePrompt != naturalPrompt {
            record("quarter-note trainer 未保存最近一次生成的 natural prompt。")
        }

        let naturalSession = naturalTrainer.makeQuarterNoteSequenceSession()
        if naturalSession.prompt != naturalPrompt {
            record("quarter-note trainer 生成的 session prompt 与最近一次 prompt 不一致。")
        }
        if naturalSession.currentIndex != 0 {
            record("quarter-note trainer 新建 session 的 currentIndex 应为 0。")
        }
        if naturalSession.totalCount != naturalPrompt.expectedPitchClasses.count {
            record("quarter-note trainer 新建 session 的 totalCount 与 prompt 不一致。")
        }
        if naturalSession.answeredCount != 0 || naturalSession.remainingCount != naturalSession.totalCount {
            record("quarter-note trainer 新建 session 的 answeredCount / remainingCount 初始值错误。")
        }
        if naturalSession.isCompleted {
            record("quarter-note trainer 新建 session 不应直接处于 completed 状态。")
        }
        if naturalSession.currentExpectedPitchClass != naturalPrompt.expectedPitchClasses.first {
            record("quarter-note trainer 新建 session 的 currentExpectedPitchClass 未对齐首个答案。")
        }

        guard let firstExpectedPitchClass = naturalPrompt.expectedPitchClasses.first else {
            record("quarter-note trainer natural prompt 缺少首个 expectedPitchClass。")
            return
        }

        let incorrectPitchClass = PitchClass.allCases.first { candidate in
            candidate != firstExpectedPitchClass
        }
        guard let incorrectPitchClass else {
            record("quarter-note trainer 无法构造与首题不同的错误答案。")
            return
        }

        var incorrectSession = naturalSession
        switch naturalTrainer.handleQuarterNoteSequenceAnswer(
            incorrectPitchClass,
            session: &incorrectSession
        ) {
        case let .evaluated(evaluation):
            if evaluation.expectedPitchClass != firstExpectedPitchClass {
                record("quarter-note trainer 错误作答时返回的 expectedPitchClass 与 session 首题不一致。")
            }
            if evaluation.answeredPitchClass != incorrectPitchClass {
                record("quarter-note trainer 错误作答时返回的 answeredPitchClass 不一致。")
            }
            if evaluation.isCorrect {
                record("quarter-note trainer 把错误答案误判成了正确。")
            }
            if evaluation.didAdvanceIndex {
                record("quarter-note trainer 错误作答后不应推进 currentIndex。")
            }
            if evaluation.answeredIndex != 0 || evaluation.nextIndex != 0 {
                record("quarter-note trainer 错误作答后的 answeredIndex / nextIndex 不正确。")
            }
            if evaluation.isSequenceCompleted {
                record("quarter-note trainer 错误作答后不应把序列标记为完成。")
            }
        default:
            record("quarter-note trainer 错误作答未返回 evaluated 结果。")
        }
        if incorrectSession.currentIndex != 0 {
            record("quarter-note trainer 错误作答后 session.currentIndex 不应变化。")
        }
        if incorrectSession.currentExpectedPitchClass != firstExpectedPitchClass {
            record("quarter-note trainer 错误作答后 currentExpectedPitchClass 不应变化。")
        }

        var completedSession = naturalSession
        for (index, expectedPitchClass) in naturalPrompt.expectedPitchClasses.enumerated() {
            switch naturalTrainer.handleQuarterNoteSequenceAnswer(
                expectedPitchClass,
                session: &completedSession
            ) {
            case let .evaluated(evaluation):
                let expectedNextIndex = index + 1
                let shouldComplete = expectedNextIndex == naturalPrompt.expectedPitchClasses.count
                if evaluation.expectedPitchClass != expectedPitchClass {
                    record("quarter-note trainer 正确作答时返回的 expectedPitchClass 与当前题目不一致。")
                }
                if evaluation.answeredPitchClass != expectedPitchClass {
                    record("quarter-note trainer 正确作答时返回的 answeredPitchClass 不一致。")
                }
                if !evaluation.isCorrect {
                    record("quarter-note trainer 未把正确答案判定为 correct。")
                }
                if !evaluation.didAdvanceIndex {
                    record("quarter-note trainer 正确作答后应推进 currentIndex。")
                }
                if evaluation.answeredIndex != index || evaluation.nextIndex != expectedNextIndex {
                    record("quarter-note trainer 正确作答后的 answeredIndex / nextIndex 不正确。")
                }
                if evaluation.isSequenceCompleted != shouldComplete {
                    record("quarter-note trainer 的完成态判断与最后一题边界不一致。")
                }
            default:
                record("quarter-note trainer 正确作答未返回 evaluated 结果。")
                return
            }

            if completedSession.currentIndex != index + 1 {
                record("quarter-note trainer 正确作答后 session.currentIndex 未同步推进。")
                return
            }
        }

        if !completedSession.isCompleted {
            record("quarter-note trainer 回答完整个序列后应进入 completed 状态。")
        }
        if completedSession.remainingCount != 0 {
            record("quarter-note trainer 完成序列后 remainingCount 应为 0。")
        }
        if completedSession.currentExpectedPitchClass != nil {
            record("quarter-note trainer 完成序列后 currentExpectedPitchClass 应为空。")
        }
        if naturalTrainer.handleQuarterNoteSequenceAnswer(
            firstExpectedPitchClass,
            session: &completedSession
        ) != .ignored(.completedSession) {
            record("quarter-note trainer 完成序列后继续作答应返回 ignored(.completedSession)。")
        }

        let accidentalSpec = FretboardNaturalNoteTrainerState.QuarterNoteSequenceSpec(
            clef: .bass,
            noteCount: 128,
            includesAccidentals: true
        )
        var accidentalTrainer = FretboardNaturalNoteTrainerState(targetPitchClass: .c)
        let accidentalPrompt = accidentalTrainer.generateQuarterNoteSequencePrompt(
            for: accidentalSpec
        )
        validateQuarterNoteSequencePrompt(
            accidentalPrompt,
            expectedSpec: accidentalSpec,
            requiresNaturalOnly: false,
            requiresAccidentalEvidence: true,
            record: record
        )
        guard case let .quarterNoteSequence(resolvedAccidentalSpec) = accidentalTrainer.mode else {
            record("quarter-note trainer 通过 generate(for:) 后 mode 应切换为 .quarterNoteSequence。")
            return
        }
        if resolvedAccidentalSpec != accidentalSpec {
            record("quarter-note trainer 的 accidental spec 与 generate(for:) 参数不一致。")
        }
        if accidentalTrainer.quarterNoteSequencePrompt != accidentalPrompt {
            record("quarter-note trainer 未保存最近一次生成的 accidental prompt。")
        }
    }

    static func validateQuarterNoteSequencePrompt(
        _ prompt: FretboardNaturalNoteTrainerState.QuarterNoteSequencePrompt,
        expectedSpec: FretboardNaturalNoteTrainerState.QuarterNoteSequenceSpec,
        requiresNaturalOnly: Bool,
        requiresAccidentalEvidence: Bool,
        record: (String) -> Void
    ) {
        if prompt.spec != expectedSpec {
            record("quarter-note trainer 生成的 prompt.spec 与期望 spec 不一致。")
        }

        if prompt.score.clef != expectedSpec.clef {
            record("quarter-note trainer 生成的 score clef 与 spec 不一致。")
        }

        if prompt.score.keySignature != .natural {
            record("quarter-note trainer 生成的 score key signature 应保持 natural。")
        }

        if prompt.notes.count != expectedSpec.noteCount {
            record("quarter-note trainer 生成的 note 数量错误，期望 \(expectedSpec.noteCount)，实际 \(prompt.notes.count)。")
        }

        if prompt.expectedPitchClasses.count != prompt.notes.count {
            record("quarter-note trainer 的 expectedPitchClasses 数量与 score.notes 不一致。")
        }

        if prompt.notes.contains(where: { $0.duration != .quarter }) {
            record("quarter-note trainer 生成了非四分音符时值。")
        }

        let expectedMeasureCount = (expectedSpec.noteCount + 3) / 4
        if prompt.score.measures.count != expectedMeasureCount {
            record(
                "quarter-note trainer 生成的 measure 数量错误，期望 \(expectedMeasureCount)，实际 \(prompt.score.measures.count)。"
            )
        }

        if prompt.score.measures.dropLast().contains(where: { $0.notes.count != 4 }) {
            record("quarter-note trainer 的非末尾 measure 未保持 4 个四分音。")
        }

        if let lastMeasure = prompt.score.measures.last {
            let expectedLastMeasureCount = expectedSpec.noteCount % 4 == 0
                ? 4
                : expectedSpec.noteCount % 4
            if lastMeasure.notes.count != expectedLastMeasureCount {
                record(
                    "quarter-note trainer 的末尾 measure 数量错误，期望 \(expectedLastMeasureCount)，实际 \(lastMeasure.notes.count)。"
                )
            }
        }

        let scorePitchClasses = prompt.notes.map(\.notePitch.pitchClass)
        if scorePitchClasses != prompt.expectedPitchClasses {
            record("quarter-note trainer 的 expectedPitchClasses 与 score.notes 派生结果不一致。")
        }

        if requiresNaturalOnly {
            if prompt.expectedPitchClasses.contains(where: \.isAccidental) {
                record("quarter-note trainer 在 natural-only 模式下生成了非自然音 pitchClass。")
            }
            if prompt.notes.contains(where: { $0.pitch.accidental != .natural }) {
                record("quarter-note trainer 在 natural-only 模式下生成了带临时记号的 StaffPitch。")
            }
        } else {
            if prompt.notes.contains(where: { $0.pitch.accidental == .flat }) {
                record("quarter-note trainer 在 includesAccidentals=true 模式下生成了 flat 拼写。")
            }
            if prompt.notes.contains(where: {
                $0.pitch.accidental != .natural && $0.pitch.accidental != .sharp
            }) {
                record("quarter-note trainer 在 includesAccidentals=true 模式下生成了非自然/升号的 accidental。")
            }
        }

        if requiresAccidentalEvidence && !prompt.notes.contains(where: { $0.pitch.accidental == .sharp }) {
            record("quarter-note trainer 在 includesAccidentals=true 模式下未生成任何升号音，无法证明候选池允许半音。")
        }
    }

    static func manualChecklist(for platform: FretboardValidationPlatform) -> [String] {
        var checklist = [
            "切换 Guitar 6 / Bass 4 / Bass 5，并在 Horizontal / Vertical 之间切换；确认 horizontal 视觉回归不变，vertical 为“左低右高、上空弦下高品、文字正立”。",
            "点击空弦区与普通品位区，确认控制台输出的 string / fret 与可见格子一致。",
            "观察页面加载后的控制台目标音日志；点击与目标同名但不同八度的音位，确认判定为 correct，并立即打印下一题目标音。",
            "当目标音为 C 时点击 C# 等升降音，确认控制台判定为 wrong，且当前目标音不切换。",
            "在 vertical 模式下拖动高度滑块，确认指板 host 高度立即跟随变化，滑块数值与页面可见占比一致。",
            "在 vertical 模式下改变窗口或设备高度，并在 Horizontal / Vertical 之间往返切换；确认指板宽度会自适应变化并保持水平居中，且切回 vertical 后沿用上次滑块值。"
        ]

        switch platform {
        case .iOS:
            checklist.append("在 iOS 上同时验证滚动与点击：轻点/短拖动仍命中，纵向拖动可平滑接管 scroll view。")
        case .macOS:
            checklist.append("在 macOS 上执行 live resize，确认 vertical 模式不闪烁，指板在 resize 过程中保持居中且命中仍正常。")
        case .commandLine:
            checklist.append("命令行只能覆盖共享层自动化夹具；iOS 滚动与 macOS live resize 需在 App 运行时手工回归。")
        }

        return checklist
    }

    static func midpoint(of segment: FretboardScene.StringSegment) -> CGPoint {
        CGPoint(
            x: (segment.start.x + segment.end.x) / 2,
            y: (segment.start.y + segment.end.y) / 2
        )
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

    static func contains(rect innerRect: CGRect, in outerRect: CGRect) -> Bool {
        innerRect.minX >= outerRect.minX - tolerance
            && innerRect.maxX <= outerRect.maxX + tolerance
            && innerRect.minY >= outerRect.minY - tolerance
            && innerRect.maxY <= outerRect.maxY + tolerance
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

    static func approximatelyEqual(rect lhs: CGRect, other rhs: CGRect) -> Bool {
        approximatelyEqual(lhs.minX, rhs.minX)
            && approximatelyEqual(lhs.minY, rhs.minY)
            && approximatelyEqual(lhs.width, rhs.width)
            && approximatelyEqual(lhs.height, rhs.height)
    }

    static func makeHitResult(
        phase: FretboardEventPhase,
        cell: FretboardCell?
    ) -> FretboardHitResult {
        FretboardHitResult(
            phase: phase,
            locationInView: .zero,
            cell: cell,
            isInsideDrawingRect: cell != nil,
            distanceToNearestString: nil
        )
    }
}
