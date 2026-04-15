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
        print("[FretboardValidation][\(platform.displayName)] begin fixtures=\(fixtures.count)")

        for fixture in fixtures {
            print("[FretboardValidation][\(platform.displayName)] fixture begin name=\(fixture.name)")
            let fixtureIssues = validate(fixture)
            print(
                "[FretboardValidation][\(platform.displayName)] fixture end name=\(fixture.name) issues=\(fixtureIssues.count)"
            )
            if fixtureIssues.isEmpty {
                passedFixtureNames.append(fixture.name)
            } else {
                issues.append(contentsOf: fixtureIssues)
            }
        }

        print("[FretboardValidation][\(platform.displayName)] end totalIssues=\(issues.count)")

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
        print("[FretboardValidation][\(platform.displayName)] runAndReportIfNeeded begin")
        let report = run(platform: platform)
        let summary = report.debugSummary()
        print(summary)
        print("[FretboardValidation][\(platform.displayName)] runAndReportIfNeeded end passing=\(report.isPassing)")

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

// 避免固定返回 0 触发标准库随机取样的拒绝采样死循环；
// 递增序列仍然是可重复的，且对 validation 足够稳定。
private struct DeterministicRandomNumberGenerator: RandomNumberGenerator {
    private var value: UInt64 = 0

    mutating func next() -> UInt64 {
        defer { value &+= 1 }
        return value
    }
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
        var issues: [FretboardValidationIssue] = []

        func logStep(_ phase: String, _ name: String) {
            print("[FretboardValidation][fixture=\(fixture.name)] step \(phase) name=\(name)")
        }

        func runStep(_ name: String, _ body: () -> Void) {
            logStep("begin", name)
            body()
            logStep("end", name)
        }

        logStep("begin", "makeScene")
        let scene = sceneBuilder.makeScene(bounds: fixture.bounds)
        logStep("end", "makeScene")

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

        runStep("validateBoundsContainment") {
            validateBoundsContainment(
                scene: scene,
                fixture: fixture,
                record: record
            )
        }
        runStep("validateVerticalHeightConsumption") {
            validateVerticalHeightConsumption(
                scene: scene,
                fixture: fixture,
                record: record
            )
        }
        runStep("validateSceneCounts") {
            validateSceneCounts(
                scene: scene,
                fixture: fixture,
                record: record
            )
        }
        runStep("validateCellAndAnchorMapping") {
            validateCellAndAnchorMapping(
                scene: scene,
                fixture: fixture,
                record: record
            )
        }
        runStep("validateCellAspectRatio") {
            validateCellAspectRatio(
                scene: scene,
                fixture: fixture,
                record: record
            )
        }
        runStep("validateAxisOrientation") {
            validateAxisOrientation(
                scene: scene,
                fixture: fixture,
                record: record
            )
        }
        runStep("validateMarkerPlacements") {
            validateMarkerPlacements(
                scene: scene,
                fixture: fixture,
                record: record
            )
        }
        runStep("validateHitTesting") {
            validateHitTesting(
                scene: scene,
                fixture: fixture,
                sceneBuilder: sceneBuilder,
                record: record
            )
        }
        runStep("validatePitchResolution") {
            validatePitchResolution(
                fixture: fixture,
                record: record
            )
        }
        runStep("validatePitchClassCellEnumeration") {
            validatePitchClassCellEnumeration(
                fixture: fixture,
                record: record
            )
        }
        runStep("validateLabelVisibilityModes") {
            validateLabelVisibilityModes(
                fixture: fixture,
                scene: scene,
                record: record
            )
        }
        runStep("validateNaturalNoteTrainer") {
            validateNaturalNoteTrainer(
                fixture: fixture,
                record: record
            )
        }
        runStep("validateSingleCoverageTrainer") {
            validateSingleCoverageTrainer(
                fixture: fixture,
                record: record
            )
        }
        runStep("validatePositionPromptTrainer") {
            validatePositionPromptTrainer(
                fixture: fixture,
                record: record
            )
        }
        runStep("validateQuarterNoteSequenceTrainer") {
            validateQuarterNoteSequenceTrainer(
                fixture: fixture,
                record: record
            )
        }
        runStep("validateLegacyLayoutBaselines") {
            validateLegacyLayoutBaselines(
                fixture: fixture,
                record: record
            )
        }

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
        print(
            "[FretboardValidation][fixture=\(fixture.name)][validateHitTesting] stage=centerAnchors count=\(scene.labelAnchors.count)"
        )
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

        if fixture.configuration.displayMode == .vertical {
            print(
                "[FretboardValidation][fixture=\(fixture.name)][validateHitTesting] stage=verticalNormalization count=\(scene.labelAnchors.count)"
            )
            for anchor in scene.labelAnchors {
                let expectedCell = FretboardCell(
                    stringIndex: anchor.stringIndex,
                    fret: anchor.fret
                )
                let mirroredDisplayPoint = CGPoint(
                    x: anchor.center.x,
                    y: fixture.bounds.minY + fixture.bounds.maxY - anchor.center.y
                )
                let normalizedPoint = FretboardContextNormalizationMode.flipYToTopLeft
                    .normalizedPoint(
                        mirroredDisplayPoint,
                        in: fixture.bounds
                    )

                if !approximatelyEqual(normalizedPoint.x, anchor.center.x)
                    || !approximatelyEqual(normalizedPoint.y, anchor.center.y) {
                    record("vertical 模式下坐标归一化后未回到 anchor(\(anchor.stringIndex), \(anchor.fret)) 的共享几何中心。")
                }

                let normalizedHit = sceneBuilder.hitTest(
                    normalizedPoint,
                    phase: .began,
                    scene: scene
                )
                if normalizedHit.cell != expectedCell {
                    record("vertical 模式下归一化后的命中测试未命中 (\(anchor.stringIndex), \(anchor.fret))，实际 \(String(describing: normalizedHit.cell))。")
                }
            }
        }

        print("[FretboardValidation][fixture=\(fixture.name)][validateHitTesting] stage=outsidePoint")
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

    static func validatePitchClassCellEnumeration(
        fixture: FretboardValidationFixture,
        record: (String) -> Void
    ) {
        let configuration = fixture.configuration
        let allCells = (0..<configuration.stringCount).flatMap { stringIndex in
            configuration.fretRange.map { fret in
                FretboardCell(
                    stringIndex: stringIndex,
                    fret: fret
                )
            }
        }

        for pitchClass in PitchClass.allCases {
            let enumeratedCells = configuration.cells(for: pitchClass)
            let expectedCells = allCells.filter {
                configuration.pitchClass(for: $0) == pitchClass
            }

            if enumeratedCells != expectedCells {
                record(
                    "configuration.cells(for: \(pitchClass.displayText())) 未与逐格 pitchClass 解析结果保持一致。"
                )
            }

            if Set(enumeratedCells).count != enumeratedCells.count {
                record(
                    "configuration.cells(for: \(pitchClass.displayText())) 返回了重复 cell。"
                )
            }

            if enumeratedCells.contains(where: {
                configuration.pitchClass(for: $0) != pitchClass
            }) {
                record(
                    "configuration.cells(for: \(pitchClass.displayText())) 包含了错误的 pitchClass cell。"
                )
            }
        }

        let totalEnumeratedCellCount = PitchClass.allCases.reduce(0) { partialResult, pitchClass in
            partialResult + configuration.cells(for: pitchClass).count
        }
        let expectedTotalCellCount = configuration.stringCount * configuration.displayPositionCount
        if totalEnumeratedCellCount != expectedTotalCellCount {
            record(
                "按 pitchClass 汇总的 cell 总数错误，期望 \(expectedTotalCellCount)，实际 \(totalEnumeratedCellCount)。"
            )
        }
    }

    static func validateLabelVisibilityModes(
        fixture: FretboardValidationFixture,
        scene: FretboardScene,
        record: (String) -> Void
    ) {
        let configuration = fixture.configuration
        let allCells = (0..<configuration.stringCount).flatMap { stringIndex in
            configuration.fretRange.map { fret in
                FretboardCell(
                    stringIndex: stringIndex,
                    fret: fret
                )
            }
        }
        let visibilityFixtures: [(String, NoteLabelVisibility, Set<PitchClass>)] = [
            ("all", .all, Set(PitchClass.allCases)),
            ("naturalOnly", .naturalOnly, Set(PitchClass.naturalCasesInOrder)),
            ("bcefOnly", .bcefOnly, Set([.b, .c, .e, .f])),
            ("accidentalOnly", .accidentalOnly, Set(PitchClass.allCases.filter(\.isAccidental))),
            ("none", .none, Set<PitchClass>())
        ]

        for (modeName, visibility, expectedPitchClasses) in visibilityFixtures {
            let labels = NoteNameContentProvider(
                visibility: visibility,
                spelling: .sharp,
                showsOctave: false
            ).makeLabels(
                configuration: configuration,
                scene: scene
            )
            let actualCells = Set(labels.map {
                FretboardCell(
                    stringIndex: $0.stringIndex,
                    fret: $0.fret
                )
            })
            let expectedCells = Set(
                allCells.filter { cell in
                    guard let pitchClass = configuration.pitchClass(for: cell) else {
                        return false
                    }
                    return expectedPitchClasses.contains(pitchClass)
                }
            )

            if labels.count != actualCells.count {
                record("visibility=\(modeName) 生成了重复 label，labels.count=\(labels.count)，uniqueCells=\(actualCells.count)。")
            }
            if actualCells != expectedCells {
                record("visibility=\(modeName) 的 label cells 不正确，期望 \(expectedCells.count) 个，实际 \(actualCells.count) 个。")
            }
            if let unexpectedLabel = labels.first(where: { label in
                let cell = FretboardCell(
                    stringIndex: label.stringIndex,
                    fret: label.fret
                )
                guard let pitchClass = configuration.pitchClass(for: cell) else {
                    return true
                }
                return !expectedPitchClasses.contains(pitchClass)
            }) {
                record(
                    "visibility=\(modeName) 错误显示了 cell(\(unexpectedLabel.stringIndex), \(unexpectedLabel.fret))。"
                )
            }
        }
    }

    static func validateNaturalNoteTrainer(
        fixture: FretboardValidationFixture,
        record: (String) -> Void
    ) {
        guard fixture.name == "horizontal-guitar6-reference" else {
            return
        }

        func logStage(_ name: String) {
            print("[FretboardValidation][fixture=\(fixture.name)][validateNaturalNoteTrainer] stage=\(name)")
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

        logStage("ignoredPhase")
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

        logStage("missingHit")
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

        logStage("unresolvedHit")
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

        logStage("wrongAnswer")
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

        logStage("correctAnswer")
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

    static func validateSingleCoverageTrainer(
        fixture: FretboardValidationFixture,
        record: (String) -> Void
    ) {
        guard fixture.name == "horizontal-guitar6-reference" else {
            return
        }

        func logStage(_ name: String) {
            print("[FretboardValidation][fixture=\(fixture.name)][validateSingleCoverageTrainer] stage=\(name)")
        }

        let configuration = fixture.configuration
        let correctCells = configuration.cells(for: .c)
        guard correctCells.count >= 2 else {
            record("single coverage trainer 缺少至少两个 C 位置，无法覆盖 partial / repeat 语义。")
            return
        }

        let firstCorrectCell = correctCells[0]
        let lastCorrectCell = correctCells[correctCells.count - 1]
        let invalidCell = FretboardCell(
            stringIndex: configuration.stringCount,
            fret: 0
        )
        let wrongCell = configuration.cells(for: .cSharp).first
            ?? configuration.cells(for: .d).first
        guard let wrongCell else {
            record("single coverage trainer 无法构造非 C 的错误命中 cell。")
            return
        }

        guard let firstCorrectPitch = configuration.notePitch(for: firstCorrectCell) else {
            record("single coverage trainer 首个正确 cell 无法解析 NotePitch。")
            return
        }
        guard let wrongPitch = configuration.notePitch(for: wrongCell) else {
            record("single coverage trainer 错误 cell 无法解析 NotePitch。")
            return
        }

        logStage("initialSession")
        var initialTrainer = FretboardNaturalNoteTrainerState(targetPitchClass: .c)
        let initialSession = initialTrainer.makeSingleCoverageSession(
            configuration: configuration
        )
        if initialSession.targetPitchClass != .c {
            record("single coverage trainer 新建 session 的 targetPitchClass 应为当前目标音 C。")
        }
        if initialSession.requiredCells != Set(correctCells) {
            record("single coverage trainer 新建 session 的 requiredCells 未对齐 configuration.cells(for: .c)。")
        }
        if !initialSession.visitedCells.isEmpty {
            record("single coverage trainer 新建 session 的 visitedCells 初始应为空。")
        }
        if initialSession.totalCount != correctCells.count {
            record("single coverage trainer 新建 session 的 totalCount 与目标 cell 数量不一致。")
        }
        if initialSession.visitedCount != 0 || initialSession.remainingCount != correctCells.count {
            record("single coverage trainer 新建 session 的 visitedCount / remainingCount 初始值错误。")
        }
        if initialSession.isCompleted {
            record("single coverage trainer 新建 session 不应直接处于 completed 状态。")
        }

        logStage("ignoredPhase")
        var ignoredPhaseTrainer = FretboardNaturalNoteTrainerState(targetPitchClass: .c)
        var ignoredPhaseSession = ignoredPhaseTrainer.makeSingleCoverageSession(
            configuration: configuration
        )
        let ignoredPhaseSnapshot = ignoredPhaseSession
        let ignoredPhaseResult = ignoredPhaseTrainer.handleSingleCoverageHit(
            makeHitResult(
                phase: .began,
                cell: firstCorrectCell
            ),
            configuration: configuration,
            session: &ignoredPhaseSession
        )
        if ignoredPhaseResult != .ignored(.nonEndedPhase(.began)) {
            record("single coverage trainer 对非 ended 事件未返回 ignored(.nonEndedPhase(.began))。")
        }
        if ignoredPhaseSession != ignoredPhaseSnapshot {
            record("single coverage trainer 在忽略非 ended 事件后不应修改 session。")
        }
        if ignoredPhaseTrainer.targetPitchClass != .c {
            record("single coverage trainer 在忽略非 ended 事件后不应推进目标音。")
        }

        logStage("missingHit")
        var missingHitTrainer = FretboardNaturalNoteTrainerState(targetPitchClass: .c)
        var missingHitSession = missingHitTrainer.makeSingleCoverageSession(
            configuration: configuration
        )
        let missingHitSnapshot = missingHitSession
        let missingHitResult = missingHitTrainer.handleSingleCoverageHit(
            makeHitResult(
                phase: .ended,
                cell: nil
            ),
            configuration: configuration,
            session: &missingHitSession
        )
        if missingHitResult != .ignored(.missingHitCell) {
            record("single coverage trainer 对空命中事件未返回 ignored(.missingHitCell)。")
        }
        if missingHitSession != missingHitSnapshot {
            record("single coverage trainer 在忽略空命中事件后不应修改 session。")
        }
        if missingHitTrainer.targetPitchClass != .c {
            record("single coverage trainer 在忽略空命中事件后不应推进目标音。")
        }

        logStage("unresolvedHit")
        var unresolvedHitTrainer = FretboardNaturalNoteTrainerState(targetPitchClass: .c)
        var unresolvedHitSession = unresolvedHitTrainer.makeSingleCoverageSession(
            configuration: configuration
        )
        let unresolvedHitSnapshot = unresolvedHitSession
        let unresolvedHitResult = unresolvedHitTrainer.handleSingleCoverageHit(
            makeHitResult(
                phase: .ended,
                cell: invalidCell
            ),
            configuration: configuration,
            session: &unresolvedHitSession
        )
        if unresolvedHitResult != .ignored(.unresolvedHitPitch(invalidCell)) {
            record("single coverage trainer 对不可解析 cell 未返回 ignored(.unresolvedHitPitch)。")
        }
        if unresolvedHitSession != unresolvedHitSnapshot {
            record("single coverage trainer 在忽略不可解析 cell 后不应修改 session。")
        }
        if unresolvedHitTrainer.targetPitchClass != .c {
            record("single coverage trainer 在忽略不可解析 cell 后不应推进目标音。")
        }

        logStage("wrongAnswer")
        var wrongTrainer = FretboardNaturalNoteTrainerState(targetPitchClass: .c)
        var wrongSession = wrongTrainer.makeSingleCoverageSession(
            configuration: configuration
        )
        switch wrongTrainer.handleSingleCoverageHit(
            makeHitResult(
                phase: .ended,
                cell: wrongCell
            ),
            configuration: configuration,
            session: &wrongSession
        ) {
        case let .evaluated(evaluation):
            if evaluation.selectedPitch != wrongPitch {
                record("single coverage trainer 错误命中时返回的 selectedPitch 与配置解析结果不一致。")
            }
            if evaluation.hitKind != .wrong {
                record("single coverage trainer 错误命中时 hitKind 应为 .wrong。")
            }
            if evaluation.isCorrect {
                record("single coverage trainer 把错误命中误判成了 correct。")
            }
            if evaluation.didIncreaseCoverage {
                record("single coverage trainer 错误命中后不应增加 coverage。")
            }
            if evaluation.didAdvanceTarget {
                record("single coverage trainer 错误命中后不应推进目标音。")
            }
            if evaluation.visitedCount != 0 || evaluation.remainingCount != wrongSession.totalCount {
                record("single coverage trainer 错误命中后的 progress 计数错误。")
            }
            if evaluation.nextTargetPitchClass != .c {
                record("single coverage trainer 错误命中后 nextTargetPitchClass 不应改变。")
            }
        default:
            record("single coverage trainer 对错误命中未返回 evaluated 结果。")
        }
        if !wrongSession.visitedCells.isEmpty {
            record("single coverage trainer 错误命中后 session.visitedCells 不应变化。")
        }
        if wrongTrainer.targetPitchClass != .c {
            record("single coverage trainer 错误命中后 trainer.targetPitchClass 不应变化。")
        }

        logStage("partialAndRepeat")
        var partialTrainer = FretboardNaturalNoteTrainerState(targetPitchClass: .c)
        var partialSession = partialTrainer.makeSingleCoverageSession(
            configuration: configuration
        )
        switch partialTrainer.handleSingleCoverageHit(
            makeHitResult(
                phase: .ended,
                cell: firstCorrectCell
            ),
            configuration: configuration,
            session: &partialSession
        ) {
        case let .evaluated(evaluation):
            if evaluation.selectedPitch != firstCorrectPitch {
                record("single coverage trainer 首次正确命中时返回的 selectedPitch 与配置解析结果不一致。")
            }
            if evaluation.hitKind != .correctNew {
                record("single coverage trainer 首次正确命中时 hitKind 应为 .correctNew。")
            }
            if !evaluation.isCorrect {
                record("single coverage trainer 首次正确命中应判定为 correct。")
            }
            if !evaluation.didIncreaseCoverage {
                record("single coverage trainer 首次正确命中应增加 coverage。")
            }
            if evaluation.didAdvanceTarget {
                record("single coverage trainer 在未覆盖完全部位置前不应推进目标音。")
            }
            if evaluation.visitedCount != 1 || evaluation.remainingCount != partialSession.totalCount - 1 {
                record("single coverage trainer 首次正确命中后的 progress 计数错误。")
            }
            if evaluation.nextTargetPitchClass != .c {
                record("single coverage trainer 首次正确命中后 nextTargetPitchClass 不应改变。")
            }
        default:
            record("single coverage trainer 对首次正确命中未返回 evaluated 结果。")
        }
        if !partialSession.visitedCells.contains(firstCorrectCell) || partialSession.visitedCount != 1 {
            record("single coverage trainer 首次正确命中后 session.visitedCells 未正确记录。")
        }
        if partialTrainer.targetPitchClass != .c {
            record("single coverage trainer 在 partial coverage 阶段不应推进 trainer.targetPitchClass。")
        }

        switch partialTrainer.handleSingleCoverageHit(
            makeHitResult(
                phase: .ended,
                cell: firstCorrectCell
            ),
            configuration: configuration,
            session: &partialSession
        ) {
        case let .evaluated(evaluation):
            if evaluation.hitKind != .correctRepeat {
                record("single coverage trainer 重复命中已完成 cell 时 hitKind 应为 .correctRepeat。")
            }
            if !evaluation.isCorrect {
                record("single coverage trainer 重复命中已完成 cell 仍应视为 correct。")
            }
            if evaluation.didIncreaseCoverage {
                record("single coverage trainer 重复命中已完成 cell 不应增加 coverage。")
            }
            if evaluation.visitedCount != 1 || evaluation.remainingCount != partialSession.totalCount - 1 {
                record("single coverage trainer 重复命中后的 progress 计数错误。")
            }
            if evaluation.didAdvanceTarget {
                record("single coverage trainer 重复命中已完成 cell 后不应推进目标音。")
            }
            if evaluation.nextTargetPitchClass != .c {
                record("single coverage trainer 重复命中后 nextTargetPitchClass 不应改变。")
            }
        default:
            record("single coverage trainer 对重复命中未返回 evaluated 结果。")
        }
        if partialSession.visitedCount != 1 {
            record("single coverage trainer 重复命中已完成 cell 后 session.visitedCount 不应增加。")
        }

        logStage("completedFlow")
        var completedTrainer = FretboardNaturalNoteTrainerState(targetPitchClass: .c)
        var completedSession = completedTrainer.makeSingleCoverageSession(
            configuration: configuration
        )
        for (index, correctCell) in correctCells.enumerated() {
            switch completedTrainer.handleSingleCoverageHit(
                makeHitResult(
                    phase: .ended,
                    cell: correctCell
                ),
                configuration: configuration,
                session: &completedSession
            ) {
            case let .evaluated(evaluation):
                let expectedVisitedCount = index + 1
                let shouldAdvance = expectedVisitedCount == correctCells.count
                if evaluation.hitKind != .correctNew {
                    record("single coverage trainer 在完整覆盖流程中每个新 cell 都应返回 .correctNew。")
                }
                if !evaluation.isCorrect {
                    record("single coverage trainer 在完整覆盖流程中的正确命中被误判。")
                }
                if !evaluation.didIncreaseCoverage {
                    record("single coverage trainer 在完整覆盖流程中的新 cell 应增加 coverage。")
                }
                if evaluation.visitedCount != expectedVisitedCount {
                    record("single coverage trainer 完整覆盖流程中的 visitedCount 未与 session 同步。")
                }
                if evaluation.remainingCount != correctCells.count - expectedVisitedCount {
                    record("single coverage trainer 完整覆盖流程中的 remainingCount 错误。")
                }
                if evaluation.isCoverageCompleted != shouldAdvance {
                    record("single coverage trainer 的 coverage completed 判断与最后一题边界不一致。")
                }
                if evaluation.didAdvanceTarget != shouldAdvance {
                    record("single coverage trainer 的 didAdvanceTarget 判断与最后一题边界不一致。")
                }
                if shouldAdvance {
                    if evaluation.nextTargetPitchClass == .c {
                        record("single coverage trainer 覆盖完成后未切换到新的目标音。")
                    }
                    if evaluation.nextTargetPitchClass.isAccidental {
                        record("single coverage trainer 覆盖完成后切换到了非自然音目标。")
                    }
                    if completedTrainer.targetPitchClass != evaluation.nextTargetPitchClass {
                        record("single coverage trainer 内部 targetPitchClass 与 evaluation.nextTargetPitchClass 未同步。")
                    }
                } else {
                    if evaluation.nextTargetPitchClass != .c {
                        record("single coverage trainer 在未完成前不应修改 nextTargetPitchClass。")
                    }
                    if completedTrainer.targetPitchClass != .c {
                        record("single coverage trainer 在未完成前不应推进 trainer.targetPitchClass。")
                    }
                }
            default:
                record("single coverage trainer 在完整覆盖流程中未返回 evaluated 结果。")
                return
            }

            if completedSession.visitedCount != index + 1 {
                record("single coverage trainer 在完整覆盖流程中 session.visitedCount 未同步增加。")
                return
            }
        }

        if !completedSession.isCompleted {
            record("single coverage trainer 完成全部目标位置后 session 应进入 completed 状态。")
        }
        if completedSession.remainingCount != 0 {
            record("single coverage trainer 完成全部目标位置后 remainingCount 应为 0。")
        }

        if completedTrainer.handleSingleCoverageHit(
            makeHitResult(
                phase: .ended,
                cell: lastCorrectCell
            ),
            configuration: configuration,
            session: &completedSession
        ) != .ignored(.completedSession) {
            record("single coverage trainer 在 completed session 上继续命中应返回 ignored(.completedSession)。")
        }
    }

    static func validatePositionPromptTrainer(
        fixture: FretboardValidationFixture,
        record: (String) -> Void
    ) {
        guard fixture.name == "horizontal-guitar6-reference" else {
            return
        }

        func logStage(_ name: String) {
            print("[FretboardValidation][fixture=\(fixture.name)][validatePositionPromptTrainer] stage=\(name)")
        }

        let configuration = fixture.configuration

        func matchesPositionPromptFilter(
            _ cell: FretboardCell,
            filter: PositionPromptCandidateFilter
        ) -> Bool {
            guard let pitchClass = configuration.pitchClass(for: cell),
                  pitchClass.isNatural else {
                return false
            }

            switch Self.normalizedPositionPromptFilter(filter) {
            case let .noteNames(selectedPitchClasses):
                return selectedPitchClasses.contains(pitchClass)
            case let .frets(selectedFrets):
                return selectedFrets.contains(cell.fret)
            }
        }

        typealias PositionPromptCandidatePoolSignature =
            FretboardNaturalNoteTrainerState.PositionPromptSession.SchedulingState.CandidatePoolSignature

        func positionPromptCandidateCellsByString(
            _ candidateCells: [FretboardCell]
        ) -> [Int: [FretboardCell]] {
            var cellsByString: [Int: [FretboardCell]] = [:]
            cellsByString.reserveCapacity(candidateCells.count)

            for cell in candidateCells {
                cellsByString[cell.stringIndex, default: []].append(cell)
            }

            return cellsByString
        }

        func positionPromptCandidateCellsByStringAndPitchClass(
            _ candidateCells: [FretboardCell]
        ) -> [Int: [PitchClass: [FretboardCell]]] {
            var cellsByStringAndPitchClass: [Int: [PitchClass: [FretboardCell]]] = [:]
            cellsByStringAndPitchClass.reserveCapacity(candidateCells.count)

            for cell in candidateCells {
                guard let pitchClass = configuration.pitchClass(for: cell) else {
                    record("position prompt trainer 候选格子无法解析为 pitchClass。")
                    continue
                }
                var cellsByPitchClass = cellsByStringAndPitchClass[cell.stringIndex] ?? [:]
                cellsByPitchClass[pitchClass, default: []].append(cell)
                cellsByStringAndPitchClass[cell.stringIndex] = cellsByPitchClass
            }

            return cellsByStringAndPitchClass
        }

        func validatePositionPromptSessionState(
            scenario name: String,
            stage: String,
            session: FretboardNaturalNoteTrainerState.PositionPromptSession,
            filter: PositionPromptCandidateFilter,
            candidateCellSet: Set<FretboardCell>,
            candidateCellsByString: [Int: [FretboardCell]],
            candidateCellsByStringAndPitchClass: [Int: [PitchClass: [FretboardCell]]],
            expectedSignature: PositionPromptCandidatePoolSignature
        ) {
            if !session.promptPitchClass.isNatural {
                record("position prompt trainer \(name) \(stage) 的 promptPitchClass 应保持自然音。")
            }
            if !candidateCellSet.contains(session.promptCell) {
                record("position prompt trainer \(name) \(stage) 的 promptCell 未落在当前候选池内。")
            }
            if !matchesPositionPromptFilter(session.promptCell, filter: filter) {
                record("position prompt trainer \(name) \(stage) 的 promptCell 未命中当前 active filter。")
            }
            if configuration.pitchClass(for: session.promptCell) != session.promptPitchClass {
                record("position prompt trainer \(name) \(stage) 的 promptPitchClass 未与 configuration 对齐。")
            }
            if session.schedulingState.candidatePoolSignature != expectedSignature {
                record("position prompt trainer \(name) \(stage) 的 candidatePoolSignature 未对齐当前候选池身份。")
            }
            if session.schedulingState.remainingStringsInRound.contains(
                session.promptCell.stringIndex
            ) {
                record("position prompt trainer \(name) \(stage) 的当前弦不应仍保留在 remainingStringsInRound 中。")
            }
            if !session.schedulingState.remainingStringsInRound.isSubset(
                of: expectedSignature.availableStringIndices
            ) {
                record("position prompt trainer \(name) \(stage) 的 remainingStringsInRound 超出了当前候选弦集合。")
            }
            if !Set(session.schedulingState.noteHitCountsByString.keys).isSubset(
                of: expectedSignature.availableStringIndices
            ) {
                record("position prompt trainer \(name) \(stage) 的 noteHitCountsByString 包含了候选池之外的弦。")
            }
            if !session.schedulingState.noteHitCountsByString.values.allSatisfy({
                !$0.isEmpty
                    && $0.keys.allSatisfy(\.isNatural)
                    && $0.values.allSatisfy { $0 > 0 }
            }) {
                record("position prompt trainer \(name) \(stage) 的 noteHitCountsByString 应全部为自然音正数。")
            }
            for (stringIndex, noteHitCounts) in session.schedulingState.noteHitCountsByString {
                guard let candidatePitchGroups =
                    candidateCellsByStringAndPitchClass[stringIndex] else {
                    record("position prompt trainer \(name) \(stage) 的 noteHitCountsByString 包含了缺少候选分组的弦。")
                    continue
                }
                if !Set(noteHitCounts.keys).isSubset(of: Set(candidatePitchGroups.keys)) {
                    record("position prompt trainer \(name) \(stage) 的 noteHitCountsByString 包含了候选池之外的音名。")
                }
            }
            let trackedCells = Set(session.schedulingState.cellHitCounts.keys)
            if !trackedCells.isSubset(of: candidateCellSet) {
                record("position prompt trainer \(name) \(stage) 的 cellHitCounts 包含了候选池之外的格子。")
            }
            if !session.schedulingState.cellHitCounts.values.allSatisfy({ $0 > 0 }) {
                record("position prompt trainer \(name) \(stage) 的 cellHitCounts 应全部为正数。")
            }
            if session.schedulingState.hitCount(for: session.promptCell) <= 0 {
                record("position prompt trainer \(name) \(stage) 的当前 promptCell 应已有命中记录。")
            }
            if session.schedulingState.noteHitCount(
                forStringIndex: session.promptCell.stringIndex,
                pitchClass: session.promptPitchClass
            ) <= 0 {
                record("position prompt trainer \(name) \(stage) 的当前 promptPitchClass 应已有同弦命中记录。")
            }
            if candidateCellsByString[session.promptCell.stringIndex] == nil {
                record("position prompt trainer \(name) \(stage) 的 promptCell 所在弦缺少按弦分组候选。")
            }
            if candidateCellsByStringAndPitchClass[session.promptCell.stringIndex]?[session.promptPitchClass] == nil {
                record("position prompt trainer \(name) \(stage) 的 promptCell 所在弦缺少按音名分组候选。")
            }
        }

        func validateCorrectAdvance(
            scenario name: String,
            from previousSession: FretboardNaturalNoteTrainerState.PositionPromptSession,
            evaluation: FretboardNaturalNoteTrainerState.PositionPromptEvaluation,
            to nextSession: FretboardNaturalNoteTrainerState.PositionPromptSession,
            filter: PositionPromptCandidateFilter,
            candidateCellSet: Set<FretboardCell>,
            candidateCellsByString: [Int: [FretboardCell]],
            candidateCellsByStringAndPitchClass: [Int: [PitchClass: [FretboardCell]]],
            expectedSignature: PositionPromptCandidatePoolSignature
        ) {
            validatePositionPromptSessionState(
                scenario: name,
                stage: "correctAdvance-nextSession",
                session: nextSession,
                filter: filter,
                candidateCellSet: candidateCellSet,
                candidateCellsByString: candidateCellsByString,
                candidateCellsByStringAndPitchClass: candidateCellsByStringAndPitchClass,
                expectedSignature: expectedSignature
            )
            if evaluation.promptCell != previousSession.promptCell {
                record("position prompt trainer \(name) 正确作答时 evaluation.promptCell 未对齐旧题。")
            }
            if evaluation.expectedPitchClass != previousSession.promptPitchClass {
                record("position prompt trainer \(name) 正确作答时 expectedPitchClass 未对齐旧题。")
            }
            if evaluation.answeredPitchClass != previousSession.promptPitchClass {
                record("position prompt trainer \(name) 正确作答时 answeredPitchClass 未保留正确按钮输入。")
            }
            if !evaluation.isCorrect {
                record("position prompt trainer \(name) 未把正确按钮输入判定为 correct。")
            }
            if !evaluation.didAdvancePrompt {
                record("position prompt trainer \(name) 正确作答后应推进到下一题。")
            }
            if evaluation.nextPromptCell != nextSession.promptCell {
                record("position prompt trainer \(name) 正确作答后 evaluation.nextPromptCell 未与 session.promptCell 同步。")
            }
            if evaluation.nextPromptPitchClass != nextSession.promptPitchClass {
                record("position prompt trainer \(name) 正确作答后 evaluation.nextPromptPitchClass 未与 session.promptPitchClass 同步。")
            }
            if !evaluation.nextPromptPitchClass.isNatural {
                record("position prompt trainer \(name) 正确作答后切换到了非自然音题目。")
            }
            if !matchesPositionPromptFilter(
                evaluation.nextPromptCell,
                filter: filter
            ) {
                record("position prompt trainer \(name) 正确作答后 nextPromptCell 应继续命中当前 active filter。")
            }

            let availableStrings = expectedSignature.availableStringIndices
            let remainingStringsBeforeSelection = previousSession
                .schedulingState
                .remainingStringsInRound
                .isEmpty
                ? availableStrings
                : previousSession.schedulingState.remainingStringsInRound
            let nextStringIndex = nextSession.promptCell.stringIndex
            if !remainingStringsBeforeSelection.contains(nextStringIndex) {
                record("position prompt trainer \(name) 正确作答后 nextPromptCell 所在弦未遵循当前轮剩余弦集合。")
            }
            let expectedRemainingStrings = remainingStringsBeforeSelection.subtracting(
                [nextStringIndex]
            )
            if nextSession.schedulingState.remainingStringsInRound != expectedRemainingStrings {
                record("position prompt trainer \(name) 正确作答后 remainingStringsInRound 未按轮巡语义更新。")
            }

            guard candidateCellsByString[nextStringIndex] != nil else {
                record("position prompt trainer \(name) 正确作答后缺少 nextPromptCell 所在弦的候选分组。")
                return
            }
            guard let stringCandidatesByPitchClass =
                candidateCellsByStringAndPitchClass[nextStringIndex] else {
                record("position prompt trainer \(name) 正确作答后缺少 nextPromptCell 所在弦的音名候选分组。")
                return
            }
            let availablePitchClasses = Set(stringCandidatesByPitchClass.keys)
            let orderedPitchClasses = PitchClass.naturalCasesInOrder.filter {
                availablePitchClasses.contains($0)
            }
            let minimumNoteHitCount = orderedPitchClasses.map {
                previousSession.schedulingState.noteHitCount(
                    forStringIndex: nextStringIndex,
                    pitchClass: $0
                )
            }.min() ?? 0
            let preferredPitchClasses = orderedPitchClasses.filter {
                previousSession.schedulingState.noteHitCount(
                    forStringIndex: nextStringIndex,
                    pitchClass: $0
                ) == minimumNoteHitCount
            }
            if !preferredPitchClasses.contains(nextSession.promptPitchClass) {
                record("position prompt trainer \(name) 正确作答后 nextPromptPitchClass 未遵循同弦最低音名命中优先规则。")
            }

            guard let pitchCandidates =
                stringCandidatesByPitchClass[nextSession.promptPitchClass] else {
                record("position prompt trainer \(name) 正确作答后缺少 nextPromptPitchClass 对应的格子候选分组。")
                return
            }
            let minimumHitCount = pitchCandidates.map {
                previousSession.schedulingState.hitCount(for: $0)
            }.min() ?? 0
            let preferredCandidates = pitchCandidates.filter {
                previousSession.schedulingState.hitCount(for: $0) == minimumHitCount
            }
            let filteredPreferredCandidates = preferredCandidates.filter {
                $0 != previousSession.promptCell
            }
            let allowedCandidates = filteredPreferredCandidates.isEmpty
                ? preferredCandidates
                : filteredPreferredCandidates
            if !allowedCandidates.contains(nextSession.promptCell) {
                record("position prompt trainer \(name) 正确作答后 nextPromptCell 未遵循同音格子的最低命中优先或排除当前格规则。")
            }

            for (stringIndex, pitchGroups) in candidateCellsByStringAndPitchClass {
                for pitchClass in pitchGroups.keys {
                    let previousNoteHitCount = previousSession.schedulingState.noteHitCount(
                        forStringIndex: stringIndex,
                        pitchClass: pitchClass
                    )
                    let nextNoteHitCount = nextSession.schedulingState.noteHitCount(
                        forStringIndex: stringIndex,
                        pitchClass: pitchClass
                    )
                    if stringIndex == nextSession.promptCell.stringIndex,
                       pitchClass == nextSession.promptPitchClass {
                        if nextNoteHitCount != previousNoteHitCount + 1 {
                            record("position prompt trainer \(name) 正确作答后新题音名的 noteHitCount 未按预期加一。")
                            break
                        }
                    } else if nextNoteHitCount != previousNoteHitCount {
                        record("position prompt trainer \(name) 正确作答后非新题音名的 noteHitCount 不应变化。")
                        break
                    }
                }
            }

            for cell in candidateCellSet {
                let previousHitCount = previousSession.schedulingState.hitCount(for: cell)
                let nextHitCount = nextSession.schedulingState.hitCount(for: cell)
                if cell == nextSession.promptCell {
                    if nextHitCount != previousHitCount + 1 {
                        record("position prompt trainer \(name) 正确作答后新题格子的 hitCount 未按预期加一。")
                        break
                    }
                } else if nextHitCount != previousHitCount {
                    record("position prompt trainer \(name) 正确作答后非新题格子的 hitCount 不应变化。")
                    break
                }
            }
        }

        func validateFilterScenario(
            name: String,
            filter: PositionPromptCandidateFilter,
            requiresNoOpenStrings: Bool
        ) {
            let normalizedFilter = Self.normalizedPositionPromptFilter(filter)

            logStage("\(name)-candidateEnumeration")
            let candidateCells = positionPromptCandidateCells(
                configuration: configuration,
                filter: normalizedFilter
            )
            guard candidateCells.count >= 2 else {
                record("position prompt trainer \(name) 缺少至少两个自然音位置，无法验证换题语义。")
                return
            }

            if !candidateCells.allSatisfy({
                matchesPositionPromptFilter($0, filter: normalizedFilter)
            }) {
                record("position prompt trainer \(name) 的候选池包含了未命中当前 active filter 的位置。")
            }
            if requiresNoOpenStrings,
               candidateCells.contains(where: { $0.fret == 0 }) {
                record("position prompt trainer \(name) 候选池不应包含空弦。")
            }
            let candidateCellSet = Set(candidateCells)
            let candidateCellsByString = positionPromptCandidateCellsByString(
                candidateCells
            )
            let candidateCellsByStringAndPitchClass =
                positionPromptCandidateCellsByStringAndPitchClass(
                    candidateCells
                )
            let expectedSignature =
                FretboardNaturalNoteTrainerState
                .positionPromptCandidatePoolSignature(
                    in: configuration,
                    filter: normalizedFilter
                )
            if expectedSignature.availableStringIndices
                != Set(candidateCellsByString.keys) {
                record("position prompt trainer \(name) 的 candidatePoolSignature 候选弦集合未对齐按弦分组结果。")
            }

            logStage("\(name)-initialSession")
            var initialGenerator = DeterministicRandomNumberGenerator()
            let initialTrainer = FretboardNaturalNoteTrainerState(
                positionPromptMode: ()
            )
            let initialSession = initialTrainer.makePositionPromptSession(
                configuration: configuration,
                filter: normalizedFilter,
                using: &initialGenerator
            )
            print(
                "[FretboardValidation][fixture=\(fixture.name)][validatePositionPromptTrainer] scenario=\(name) initialSessionCreated cell=string=\(initialSession.promptCell.stringIndex) fret=\(initialSession.promptCell.fret) pitch=\(initialSession.promptPitchClass.displayText())"
            )
            validatePositionPromptSessionState(
                scenario: name,
                stage: "initialSession",
                session: initialSession,
                filter: normalizedFilter,
                candidateCellSet: candidateCellSet,
                candidateCellsByString: candidateCellsByString,
                candidateCellsByStringAndPitchClass: candidateCellsByStringAndPitchClass,
                expectedSignature: expectedSignature
            )
            let expectedInitialRemainingStrings =
                expectedSignature.availableStringIndices.subtracting([
                    initialSession.promptCell.stringIndex
                ])
            if initialSession.schedulingState.remainingStringsInRound
                != expectedInitialRemainingStrings {
                record("position prompt trainer \(name) 新建 session 的 remainingStringsInRound 未对齐首题后的剩余弦集合。")
            }
            if initialSession.schedulingState.cellHitCounts
                != [initialSession.promptCell: 1] {
                record("position prompt trainer \(name) 新建 session 的 cellHitCounts 未对齐首题初始化语义。")
            }
            if initialSession.schedulingState.noteHitCountsByString
                != [
                    initialSession.promptCell.stringIndex: [
                        initialSession.promptPitchClass: 1
                    ]
                ] {
                record("position prompt trainer \(name) 新建 session 的 noteHitCountsByString 未对齐首题初始化语义。")
            }

            logStage("\(name)-wrongAnswer")
            var wrongGenerator = DeterministicRandomNumberGenerator()
            var wrongTrainer = FretboardNaturalNoteTrainerState(
                positionPromptMode: ()
            )
            var wrongSession = wrongTrainer.makePositionPromptSession(
                configuration: configuration,
                filter: normalizedFilter,
                using: &wrongGenerator
            )
            validatePositionPromptSessionState(
                scenario: name,
                stage: "wrongAnswer-sessionBeforeAnswer",
                session: wrongSession,
                filter: normalizedFilter,
                candidateCellSet: candidateCellSet,
                candidateCellsByString: candidateCellsByString,
                candidateCellsByStringAndPitchClass: candidateCellsByStringAndPitchClass,
                expectedSignature: expectedSignature
            )
            guard let wrongAnswer = PitchClass.naturalCasesInOrder.first(where: {
                $0 != wrongSession.promptPitchClass
            }) else {
                record("position prompt trainer \(name) 无法构造不同于当前题答案的自然音错误按钮。")
                return
            }
            print(
                "[FretboardValidation][fixture=\(fixture.name)][validatePositionPromptTrainer] scenario=\(name) wrongAnswerResolved pitch=\(wrongAnswer.displayText())"
            )
            let wrongSessionSnapshot = wrongSession
            switch wrongTrainer.handlePositionPromptAnswer(
                wrongAnswer,
                configuration: configuration,
                filter: normalizedFilter,
                session: &wrongSession,
                using: &wrongGenerator
            ) {
            case let .evaluated(evaluation):
                if evaluation.promptCell != wrongSessionSnapshot.promptCell {
                    record("position prompt trainer \(name) 错误作答时 promptCell 未对齐当前题目。")
                }
                if evaluation.expectedPitchClass != wrongSessionSnapshot.promptPitchClass {
                    record("position prompt trainer \(name) 错误作答时 expectedPitchClass 与当前题目不一致。")
                }
                if evaluation.answeredPitchClass != wrongAnswer {
                    record("position prompt trainer \(name) 错误作答时 answeredPitchClass 未保留按钮输入。")
                }
                if evaluation.isCorrect {
                    record("position prompt trainer \(name) 把错误按钮输入误判成了正确。")
                }
                if evaluation.didAdvancePrompt {
                    record("position prompt trainer \(name) 错误作答后不应推进题目。")
                }
                if evaluation.didChangePromptCell {
                    record("position prompt trainer \(name) 错误作答后不应切换 promptCell。")
                }
                if evaluation.nextPromptCell != wrongSessionSnapshot.promptCell {
                    record("position prompt trainer \(name) 错误作答后 nextPromptCell 不应改变。")
                }
                if evaluation.nextPromptPitchClass != wrongSessionSnapshot.promptPitchClass {
                    record("position prompt trainer \(name) 错误作答后 nextPromptPitchClass 不应改变。")
                }
                if !matchesPositionPromptFilter(
                    evaluation.nextPromptCell,
                    filter: normalizedFilter
                ) {
                    record("position prompt trainer \(name) 错误作答后 nextPromptCell 仍应命中当前 active filter。")
                }
            }
            if wrongSession != wrongSessionSnapshot {
                record("position prompt trainer \(name) 错误作答后 session 不应变化。")
            }
            validatePositionPromptSessionState(
                scenario: name,
                stage: "wrongAnswer-sessionAfterAnswer",
                session: wrongSession,
                filter: normalizedFilter,
                candidateCellSet: candidateCellSet,
                candidateCellsByString: candidateCellsByString,
                candidateCellsByStringAndPitchClass: candidateCellsByStringAndPitchClass,
                expectedSignature: expectedSignature
            )

            logStage("\(name)-roundRobinSequence")
            var sequenceGenerator = DeterministicRandomNumberGenerator()
            var sequenceTrainer = FretboardNaturalNoteTrainerState(
                positionPromptMode: ()
            )
            var sequenceSession = sequenceTrainer.makePositionPromptSession(
                configuration: configuration,
                filter: normalizedFilter,
                using: &sequenceGenerator
            )
            let roundLength = max(
                expectedSignature.availableStringIndices.count,
                1
            )
            let observedPromptCount = max(roundLength * 4, 8)
            var observedStringsByPrompt: [Int] = []
            observedStringsByPrompt.reserveCapacity(observedPromptCount)
            var observedPitchClassesByString: [Int: [PitchClass]] = [:]

            for promptIndex in 0..<observedPromptCount {
                validatePositionPromptSessionState(
                    scenario: name,
                    stage: "roundSequence-step\(promptIndex + 1)",
                    session: sequenceSession,
                    filter: normalizedFilter,
                    candidateCellSet: candidateCellSet,
                    candidateCellsByString: candidateCellsByString,
                    candidateCellsByStringAndPitchClass: candidateCellsByStringAndPitchClass,
                    expectedSignature: expectedSignature
                )
                observedStringsByPrompt.append(
                    sequenceSession.promptCell.stringIndex
                )
                observedPitchClassesByString[
                    sequenceSession.promptCell.stringIndex,
                    default: []
                ].append(sequenceSession.promptPitchClass)

                guard promptIndex < observedPromptCount - 1 else {
                    break
                }

                let previousSession = sequenceSession
                switch sequenceTrainer.handlePositionPromptAnswer(
                    previousSession.promptPitchClass,
                    configuration: configuration,
                    filter: normalizedFilter,
                    session: &sequenceSession,
                    using: &sequenceGenerator
                ) {
                case let .evaluated(evaluation):
                    validateCorrectAdvance(
                        scenario: name,
                        from: previousSession,
                        evaluation: evaluation,
                        to: sequenceSession,
                        filter: normalizedFilter,
                        candidateCellSet: candidateCellSet,
                        candidateCellsByString: candidateCellsByString,
                        candidateCellsByStringAndPitchClass: candidateCellsByStringAndPitchClass,
                        expectedSignature: expectedSignature
                    )
                }
            }

            let completeRoundCount = observedPromptCount / roundLength
            for roundIndex in 0..<completeRoundCount {
                let start = roundIndex * roundLength
                let end = start + roundLength
                let roundStrings = Array(observedStringsByPrompt[start..<end])
                if Set(roundStrings) != expectedSignature.availableStringIndices {
                    record("position prompt trainer \(name) 第 \(roundIndex + 1) 轮未完整覆盖当前候选弦集合。")
                }
                if Set(roundStrings).count != roundStrings.count {
                    record("position prompt trainer \(name) 第 \(roundIndex + 1) 轮出现了重复弦，未遵循每轮每弦一次的语义。")
                }
            }

            for stringIndex in expectedSignature.availableStringIndices {
                guard let pitchGroups =
                    candidateCellsByStringAndPitchClass[stringIndex] else {
                    record("position prompt trainer \(name) 缺少某条候选弦的音名分组，无法验证音名公平。")
                    continue
                }
                if observedPitchClassesByString[stringIndex]?.isEmpty ?? true {
                    record("position prompt trainer \(name) 在观察序列中遗漏了候选弦 \(stringIndex) 的题目。")
                }
                let candidatePitchClasses = PitchClass.naturalCasesInOrder.filter {
                    pitchGroups[$0] != nil
                }
                let noteHitCounts = candidatePitchClasses.map {
                    sequenceSession.schedulingState.noteHitCount(
                        forStringIndex: stringIndex,
                        pitchClass: $0
                    )
                }
                if let minimumNoteHitCount = noteHitCounts.min(),
                   let maximumNoteHitCount = noteHitCounts.max(),
                   maximumNoteHitCount - minimumNoteHitCount > 1 {
                    record("position prompt trainer \(name) 在弦 \(stringIndex) 上的音名命中分布差值超过 1，未遵循最低音名命中优先语义。")
                }
            }
        }

        func resolveChoiceRow(
            _ rowID: SettingsChoiceRowID,
            in section: SettingsSection
        ) -> SettingsChoiceRow? {
            for row in section.rows {
                guard case let .choice(choiceRow) = row,
                      choiceRow.id == rowID else {
                    continue
                }
                return choiceRow
            }
            return nil
        }

        func resolvePositionFilterRow(
            _ rowID: SettingsPositionFilterRowID,
            in section: SettingsSection
        ) -> SettingsPositionFilterRow? {
            for row in section.rows {
                guard case let .positionFilter(positionFilterRow) = row,
                      positionFilterRow.id == rowID else {
                    continue
                }
                return positionFilterRow
            }
            return nil
        }

        logStage("defaultConfiguration")
        let defaultPositionQuestionConfiguration =
            TrainerPositionQuestionConfiguration.default
        if TrainerDisplayState.default.exerciseMode != .positionPrompt {
            record("TrainerDisplayState.default 应继续默认进入 .positionPrompt。")
        }
        if defaultPositionQuestionConfiguration.selectedPitchClasses
            != TrainerPositionQuestionConfiguration.defaultSelectedPitchClasses {
            record("position question 默认 selectedPitchClasses 未对齐 C/E/F/B。")
        }
        switch TrainerDisplayState.default.positionQuestionCandidateFilter {
        case let .noteNames(selectedPitchClasses):
            if selectedPitchClasses
                != TrainerPositionQuestionConfiguration.defaultSelectedPitchClasses {
                record("position question 默认 activeFilter 未对齐默认音名集合。")
            }
        case .frets:
            record("position question 默认 activeFilter 不应落在 fret 模式。")
        }

        logStage("startupSettingsProjection")
        let startupSettingsModel = SettingsPanelSnapshotBuilder.makeModel(
            from: SettingsPanelStateContext(
                pageDisplayState: .positionPrompt,
                trainerDisplayState: .default
            )
        )
        if let startupExerciseSection = startupSettingsModel.sections.first(where: {
            $0.id == .exercise
        }) {
            let expectedStartupExerciseRowIDs: [SettingsRowID] = [
                .choice(.exerciseMode),
                .positionFilter(.positionQuestionPitchClasses),
                .choice(.compositionPreset),
                .choice(.layoutPreset)
            ]
            if startupExerciseSection.rows.map(\.id) != expectedStartupExerciseRowIDs {
                record("startup settings model 的 Exercise row 顺序未对齐 Exercise Mode / Position Note Names / Composition Preset / Layout Preset。")
            }
            if let exerciseModeRow = resolveChoiceRow(
                .exerciseMode,
                in: startupExerciseSection
            ) {
                if let positionPromptChoice = exerciseModeRow.choices.first(where: {
                    $0.id == .setExerciseModePositionPrompt
                }) {
                    if !positionPromptChoice.isSelected {
                        record("startup settings model 的 Exercise Mode 默认不应偏离 Position Prompt。")
                    }
                } else {
                    record("startup settings model 的 Exercise Mode row 缺少 Position Prompt 选项。")
                }
            } else {
                record("startup settings model 缺少 Exercise Mode row。")
            }

            if let compositionRow = resolveChoiceRow(
                .compositionPreset,
                in: startupExerciseSection
            ) {
                if let stripChoice = compositionRow.choices.first(where: {
                    $0.id == .setCompositionPresetFretboardToNaturalNoteStrip
                }) {
                    if !stripChoice.isSelected {
                        record("startup settings model 的 Composition Preset 默认应选中 Fretboard -> Natural Note Strip。")
                    }
                } else {
                    record("startup settings model 的 Composition Preset row 缺少 Strip 选项。")
                }
            } else {
                record("startup settings model 缺少 Composition Preset row。")
            }
            if let positionQuestionRow = resolvePositionFilterRow(
                .positionQuestionPitchClasses,
                in: startupExerciseSection
            ) {
                if positionQuestionRow.title != "Note Names" {
                    record("startup settings model 的 Position question row 默认标题应为 Note Names。")
                }
                let expectedOptionIDs = TrainerPositionQuestionConfiguration
                    .supportedPitchClasses.map {
                        SettingsPositionFilterOptionID.pitchClass($0)
                    }
                if positionQuestionRow.options.map(\.id) != expectedOptionIDs {
                    record("startup settings model 的出题音名按钮顺序未对齐 C/D/E/F/G/A/B。")
                }
                let expectedSelectedOptionIDs = Set(
                    TrainerPositionQuestionConfiguration
                        .defaultSelectedPitchClasses.map {
                            SettingsPositionFilterOptionID.pitchClass($0)
                        }
                )
                let actualSelectedOptionIDs = Set(
                    positionQuestionRow.options
                        .filter(\.isSelected)
                        .map(\.id)
                )
                if actualSelectedOptionIDs != expectedSelectedOptionIDs {
                    record("startup settings model 的出题音名按钮默认选中集合未对齐 C/E/F/B。")
                }
            } else {
                record("startup settings model 缺少 Position question 音名选择行。")
            }
        } else {
            record("startup settings model 缺少 Exercise section，无法验证 position prompt 默认回显。")
        }

        logStage("lastSelectedPitchClassGuard")
        let lockedPitchClassConfiguration = TrainerPositionPromptConfiguration(
            selectedPitchClasses: [.c]
        )
        if lockedPitchClassConfiguration.canDeselect(.c) {
            record("position prompt 配置在只剩最后一个已选音名时不应允许 canDeselect 返回 true。")
        }
        if lockedPitchClassConfiguration.toggled(pitchClass: .c).selectedPitchClasses
            != Set<PitchClass>([.c]) {
            record("position prompt 配置在只剩最后一个已选音名时，不应允许 toggled(pitchClass:) 取消该音名。")
        }

        logStage("lastSelectedFretGuard")
        let lockedFretConfiguration = TrainerPositionPromptConfiguration(
            selectedFrets: [7]
        )
        if lockedFretConfiguration.canDeselect(7) {
            record("position prompt 配置在只剩最后一个已选品位时不应允许 canDeselect 返回 true。")
        }
        if lockedFretConfiguration.toggled(fret: 7).selectedFrets != Set([7]) {
            record("position prompt 配置在只剩最后一个已选品位时，不应允许 toggled(fret:) 取消该品位。")
        }

        validateFilterScenario(
            name: "defaultNoteNames",
            filter: defaultPositionQuestionConfiguration.activeFilter,
            requiresNoOpenStrings: false
        )
        validateFilterScenario(
            name: "subset_C_E",
            filter: TrainerPositionPromptConfiguration(
                filterMode: .noteName,
                selectedPitchClasses: [.c, .e]
            ).activeFilter,
            requiresNoOpenStrings: false
        )
        validateFilterScenario(
            name: "defaultNoteNamesPlusD",
            filter: TrainerPositionPromptConfiguration(
                filterMode: .noteName,
                selectedPitchClasses: [.c, .d, .e, .f, .b]
            ).activeFilter,
            requiresNoOpenStrings: false
        )
        validateFilterScenario(
            name: "defaultSelectedFrets",
            filter: TrainerPositionPromptConfiguration(
                filterMode: .fret,
                selectedFrets: TrainerPositionPromptConfiguration.defaultSelectedFrets
            ).activeFilter,
            requiresNoOpenStrings: true
        )
        validateFilterScenario(
            name: "subset_1_3_5_7",
            filter: TrainerPositionPromptConfiguration(
                filterMode: .fret,
                selectedFrets: [1, 3, 5, 7]
            ).activeFilter,
            requiresNoOpenStrings: true
        )
    }

    static func validateQuarterNoteSequenceTrainer(
        fixture: FretboardValidationFixture,
        record: (String) -> Void
    ) {
        guard fixture.name == "horizontal-guitar6-reference" else {
            return
        }

        func logStage(_ name: String) {
            print("[FretboardValidation][fixture=\(fixture.name)][validateQuarterNoteSequenceTrainer] stage=\(name)")
        }

        logStage("naturalPrompt")
        let naturalSpec = FretboardNaturalNoteTrainerState.QuarterNoteSequenceSpec(
            clef: .treble,
            noteCount: 7,
            includesAccidentals: false,
            answerPolicy: .pitchClass
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
        if naturalTrainer.generatedQuarterNoteSequence != naturalPrompt.generatedSequence {
            record("quarter-note trainer 未保存最近一次生成的 natural shared sequence。")
        }

        logStage("naturalSession")
        let naturalSession = naturalTrainer.makeQuarterNoteSequenceSession()
        if naturalSession.generatedSequence != naturalPrompt.generatedSequence {
            record("quarter-note trainer 生成的 session sequence 与最近一次 shared sequence 不一致。")
        }
        if naturalSession.currentIndex != 0 {
            record("quarter-note trainer 新建 session 的 currentIndex 应为 0。")
        }
        if naturalSession.totalCount != naturalPrompt.generatedSequence.noteCount {
            record("quarter-note trainer 新建 session 的 totalCount 与 shared sequence 不一致。")
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
        if naturalSession.targetPromptContent() != naturalPrompt.generatedSequence.targetPromptContent(
            currentIndex: naturalSession.currentIndex
        ) {
            record("quarter-note trainer 新建 session 的 targetPromptContent 未对齐 shared sequence/currentIndex。")
        }
        if let initialStaffPresentation = StaffSequencePresentation.fromProgress(
            totalCount: naturalSession.totalCount,
            currentIndex: naturalSession.currentIndex
        ) {
            if initialStaffPresentation != .idle(cursorIndex: naturalSession.currentIndex) {
                record("quarter-note trainer 新建 session 的 staff sequence presentation 未映射为 idle(cursorIndex: currentIndex)。")
            }
        } else {
            record("quarter-note trainer 新建 session 的 staff sequence presentation 不应为 nil。")
        }

        guard let firstExpectedPitchClass = naturalPrompt.generatedSequence.answerPitchClasses.first else {
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

        logStage("incorrectAnswer")
        var incorrectSession = naturalSession
        switch naturalTrainer.handleQuarterNoteSequenceAnswer(
            incorrectPitchClass,
            session: &incorrectSession
        ) {
        case let .evaluated(evaluation):
            if evaluation.expectedPitchClass != firstExpectedPitchClass {
                record("quarter-note trainer 错误作答时返回的 expectedPitchClass 与 session 首题不一致。")
            }
            if evaluation.comparisonPolicy != naturalSpec.answerPolicy {
                record("quarter-note trainer 错误作答时返回的 comparisonPolicy 未对齐当前 spec.answerPolicy。")
            }
            if evaluation.expectedNotePitch != evaluation.expectedWrittenPitch.notePitch {
                record("quarter-note trainer 错误作答时返回的 expectedNotePitch 未正确投影自 expectedWrittenPitch.notePitch。")
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
            if let incorrectStaffPresentation = StaffSequencePresentation.fromProgress(
                totalCount: incorrectSession.totalCount,
                currentIndex: incorrectSession.currentIndex,
                lastEvaluatedIndex: evaluation.answeredIndex,
                lastEvaluationResult: .incorrect
            ) {
                if incorrectStaffPresentation != .wrong(
                    cursorIndex: incorrectSession.currentIndex,
                    evaluatedIndex: evaluation.answeredIndex
                ) {
                    record("quarter-note trainer 错误作答后的 staff sequence presentation 未与 session/evaluation 对齐。")
                }
            } else {
                record("quarter-note trainer 错误作答后的 staff sequence presentation 不应为 nil。")
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
        if incorrectSession.targetPromptContent() != naturalPrompt.generatedSequence.targetPromptContent(
            currentIndex: incorrectSession.currentIndex
        ) {
            record("quarter-note trainer 错误作答后 targetPromptContent 未与当前 session.currentIndex 同步。")
        }

        logStage("completedFlow")
        var completedSession = naturalSession
        for (index, expectedPitchClass) in naturalPrompt.generatedSequence.answerPitchClasses.enumerated() {
            switch naturalTrainer.handleQuarterNoteSequenceAnswer(
                expectedPitchClass,
                session: &completedSession
            ) {
            case let .evaluated(evaluation):
                let expectedNextIndex = index + 1
                let shouldComplete = expectedNextIndex == naturalPrompt.generatedSequence.noteCount
                if evaluation.expectedPitchClass != expectedPitchClass {
                    record("quarter-note trainer 正确作答时返回的 expectedPitchClass 与当前题目不一致。")
                }
                if evaluation.comparisonPolicy != naturalSpec.answerPolicy {
                    record("quarter-note trainer 正确作答时返回的 comparisonPolicy 未对齐当前 spec.answerPolicy。")
                }
                if evaluation.expectedNotePitch != evaluation.expectedWrittenPitch.notePitch {
                    record("quarter-note trainer 正确作答时返回的 expectedNotePitch 未正确投影自 expectedWrittenPitch.notePitch。")
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
                if let correctStaffPresentation = StaffSequencePresentation.fromProgress(
                    totalCount: completedSession.totalCount,
                    currentIndex: evaluation.nextIndex,
                    lastEvaluatedIndex: evaluation.answeredIndex,
                    lastEvaluationResult: .correct
                ) {
                    let expectedStaffPresentation: StaffSequencePresentation
                    if shouldComplete {
                        expectedStaffPresentation = .completed(
                            lastEvaluatedIndex: evaluation.answeredIndex,
                            lastEvaluationResult: .correct
                        )
                    } else {
                        expectedStaffPresentation = .correct(
                            cursorIndex: evaluation.nextIndex,
                            evaluatedIndex: evaluation.answeredIndex
                        )
                    }

                    if correctStaffPresentation != expectedStaffPresentation {
                        record("quarter-note trainer 正确作答后的 staff sequence presentation 未与 session/evaluation 对齐。")
                    }
                } else {
                    record("quarter-note trainer 正确作答后的 staff sequence presentation 不应为 nil。")
                }
            default:
                record("quarter-note trainer 正确作答未返回 evaluated 结果。")
                return
            }

            if completedSession.currentIndex != index + 1 {
                record("quarter-note trainer 正确作答后 session.currentIndex 未同步推进。")
                return
            }
            if completedSession.targetPromptContent() != naturalPrompt.generatedSequence.targetPromptContent(
                currentIndex: completedSession.currentIndex
            ) {
                record("quarter-note trainer 正确作答后 targetPromptContent 未与当前 session.currentIndex 同步。")
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

        logStage("accidentalPrompt")
        let accidentalSpec = FretboardNaturalNoteTrainerState.QuarterNoteSequenceSpec(
            clef: .bass,
            noteCount: 128,
            includesAccidentals: true,
            answerPolicy: .pitchClass
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
        if accidentalTrainer.generatedQuarterNoteSequence != accidentalPrompt.generatedSequence {
            record("quarter-note trainer 未保存最近一次生成的 accidental shared sequence。")
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

    static func normalizedPositionPromptFilter(
        _ filter: PositionPromptCandidateFilter
    ) -> PositionPromptCandidateFilter {
        switch filter {
        case let .noteNames(selectedPitchClasses):
            return TrainerPositionPromptConfiguration(
                filterMode: .noteName,
                selectedPitchClasses: selectedPitchClasses
            ).activeFilter
        case let .frets(selectedFrets):
            return TrainerPositionPromptConfiguration(
                filterMode: .fret,
                selectedFrets: selectedFrets
            ).activeFilter
        }
    }

    static func positionPromptCandidateCells(
        configuration: FretboardConfiguration,
        filter: PositionPromptCandidateFilter = TrainerPositionQuestionConfiguration.default.activeFilter
    ) -> [FretboardCell] {
        let normalizedFilter = normalizedPositionPromptFilter(filter)
        var cells: [FretboardCell] = []
        cells.reserveCapacity(configuration.stringCount * configuration.displayPositionCount)

        for stringIndex in 0..<configuration.stringCount {
            for fret in configuration.fretRange {
                let cell = FretboardCell(
                    stringIndex: stringIndex,
                    fret: fret
                )
                guard let pitchClass = configuration.pitchClass(for: cell),
                      pitchClass.isNatural else {
                    continue
                }
                switch normalizedFilter {
                case let .noteNames(selectedPitchClasses):
                    guard selectedPitchClasses.contains(pitchClass) else {
                        continue
                    }
                case let .frets(selectedFrets):
                    guard selectedFrets.contains(fret) else {
                        continue
                    }
                }
                cells.append(cell)
            }
        }

        return cells
    }

    static func manualChecklist(for platform: FretboardValidationPlatform) -> [String] {
        var checklist = [
            "切换 Guitar 6 / Bass 4 / Bass 5，并在 Horizontal / Vertical 之间切换；确认 horizontal 视觉回归不变，vertical 为“左低右高、上空弦下高品、文字正立”。",
            "在设置面板的 `Labels` 中切到 `BCEF`，确认指板只显示 `B / C / E / F`；再切回 `All / Natural / Accidental / None`，确认不会残留错误标签。",
            "点击空弦区与普通品位区，确认控制台输出的 string / fret 与可见格子一致。",
            "观察页面加载后的控制台目标音日志；点击与目标同名但不同八度的音位，确认判定为 correct，并立即打印下一题目标音。",
            "当目标音为 C 时点击 C# 等升降音，确认控制台判定为 wrong，且当前目标音不切换。",
            "在 vertical 模式下拖动高度滑块，确认指板 host 高度立即跟随变化，滑块数值与页面可见占比一致。",
            "在 vertical 模式下改变窗口或设备高度，并在 Horizontal / Vertical 之间往返切换；确认指板宽度会自适应变化并保持水平居中，且切回 vertical 后沿用上次滑块值。",
            "在 `single` 与 `sequence` 模式下确认页面继续保持上方 `staff`、下方 `fretboard`；切回 `positionPrompt` 后确认恢复为上方 `fretboard`、下方 `natural note strip`，且不受 `pianoAccessoryVisible` 与 viewport 调整影响。",
            "应用启动后不做额外切换，直接打开设置面板；确认 `Exercise > Mode` 页面除了 `Exercise Mode = Position` 之外，还会显示 `Note Names` 多选按钮，并默认回显 `C / E / F / B`。",
            "在 `single` 与 `sequence` 模式下打开 `Exercise > Mode`，确认不会显示 Position 专用的 `Note Names` 多选行；切到 `positionPrompt` 后该行出现，且默认选中 `C / E / F / B`。",
            "在 `positionPrompt` 默认 `C / E / F / B` 状态下连续答对至少 6 次，确认当前题与下一题都只落在这些音名；若当前有 6 根候选弦，则一轮 6 题内 6 根弦各出现 1 次，再进入下一轮时重新开始轮巡。",
            "在 `Exercise > Mode` 里只保留 `C / E` 这两个音名后连续观察至少两轮，确认当前题与下一题都只落在 `C / E`；同一根弦上会优先出现此前命中次数更少的格子。",
            "再次切回 `C / E / F / B`，确认候选池与轮巡调度会立即按新的音名集合重新开始。",
            "观察控制台里的 `[PositionPrompt][Trainer]` 日志，确认会打印 `poolStrings`、`activeRoundStrings`、`selectedString`、`minimumHitCount`、`minimumHitCandidateCount`、`roundProgress` 等字段；切换 `Note Names` 或指板配置后，这些字段会按新的候选池重新开始。",
            "尝试连续取消音名直到只剩最后一个已选音名，再继续点击该音名；确认 UI 仍保持至少一个音名被选中。",
            "尝试连续取消品位直到只剩最后一个已选格子，再继续点击该格子；确认 UI 仍保持至少一个品位被选中。",
            "在 `wrongFlash` 或 `correctHold` 期间切换过滤模式或当前激活模式下的过滤选项；若当前可见题目已变成非法题，确认界面会平滑切换到新题，不残留错误 overlay 或延时切题任务。"
        ]

        switch platform {
        case .iOS:
            checklist.append("在 iOS 上同时验证滚动与点击：轻点/短拖动仍命中，纵向拖动可平滑接管 scroll view。")
        case .macOS:
            checklist.append("在 macOS 上执行 live resize，确认 vertical 模式不闪烁，指板在 resize 过程中保持居中且命中仍正常。")
            checklist.append("在 macOS 的 vertical 模式下分别点击顶部空弦区与底部高品区，确认可见格子与控制台 string / fret 一致，不再出现上下反向。")
        case .commandLine:
            checklist.append("命令行只能覆盖共享层自动化夹具；iOS 滚动与 macOS live resize 需在 App 运行时手工回归。")
        }

        return checklist
    }

    static func validateLegacyLayoutBaselines(
        fixture: FretboardValidationFixture,
        record: (String) -> Void
    ) {
        guard fixture.name == "horizontal-guitar6-reference" else {
            return
        }

        let defaultPageDisplayState = PageDisplayState.default
        if defaultPageDisplayState.topContentMode != .staff
            || defaultPageDisplayState.mainContentMode != .fretboard {
            record("legacy default page baseline 应继续保持 staff -> fretboard。")
        }
        if defaultPageDisplayState.showsFretboardInTopContent
            || !defaultPageDisplayState.showsFretboardInMainContent
            || !defaultPageDisplayState.hasValidFretboardPlacement {
            record("legacy default page baseline 应继续只在 mainContent 承载 fretboard。")
        }

        let positionPromptPageDisplayState = PageDisplayState.positionPrompt
        if positionPromptPageDisplayState.topContentMode != .fretboard
            || positionPromptPageDisplayState.mainContentMode != .naturalNoteStrip {
            record("legacy positionPrompt baseline 应继续保持 fretboard -> naturalNoteStrip。")
        }
        if !positionPromptPageDisplayState.showsFretboardInTopContent
            || positionPromptPageDisplayState.showsFretboardInMainContent
            || !positionPromptPageDisplayState.hasValidFretboardPlacement {
            record("legacy positionPrompt baseline 应继续只在 topContent 承载 fretboard。")
        }

        if FretboardDisplayState.default.displayMode != .vertical {
            record("迁移前 default fretboard displayMode 应继续保持 vertical。")
        }
        if !approximatelyEqual(
            FretboardDisplayState.default.verticalHostHeightRatio,
            FretboardDisplayState.defaultVerticalHostHeightRatio
        ) {
            record("迁移前 default verticalHostHeightRatio 应继续对齐 defaultVerticalHostHeightRatio。")
        }
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
