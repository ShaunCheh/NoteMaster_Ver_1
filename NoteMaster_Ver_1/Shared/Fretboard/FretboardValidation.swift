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
                widthOverride: 220
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

    static func manualChecklist(for platform: FretboardValidationPlatform) -> [String] {
        var checklist = [
            "切换 Guitar 6 / Bass 4 / Bass 5，并在 Horizontal / Vertical 之间切换；确认 horizontal 视觉回归不变，vertical 为“左低右高、上空弦下高品、文字正立”。",
            "点击空弦区与普通品位区，确认控制台输出的 string / fret 与可见格子一致。",
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
}
