# 20260330_110428_phase2_piano_shared_geometry_and_scene

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260330_110428`
- 记录范围：实施“钢琴键盘组件”计划的阶段 2，只落 `Shared/Piano` 的几何、场景与命中模型，并补齐对应 validation 夹具
- 本次目标：在不接入 `iOS/macOS` 平台视图、不实现 reducer、不实现 layer 绘制的前提下，先把钢琴组件的场景结构、布局几何、命中测试和吸附计算在 Shared 层建立起来
- 本次实际新增/修改文件：
- `NoteMaster_Ver_1/Shared/Piano/PianoScene.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoSceneBuilder.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoGeometry.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift`
- 本次未改动内容：
- `PianoInteractionReducer`
- `PianoKeyboardLayer` / `PianoRowLayer`
- `iOSPianoKeyboardView` / `macOSPianoKeyboardView`
- `iOSAppDelegate.swift` / `macOSAppDelegate.swift`

## 本次结论

- 修改前，`Shared/Piano` 只有阶段 1 的基础模型：`PianoConfiguration`、`PianoState`、`PianoInteraction`、`PianoValidation`
- 修改后，`Shared/Piano` 已经具备阶段 2 需要的四块几何能力：
- `PianoScene`：承接每一行 `A/B/C` 子区域、可见白键/黑键、自然音刻度 marker
- `PianoSceneBuilder`：把 `bounds + configuration + state` 投影成稳定的行场景
- `PianoGeometry`：提供命中测试、note rect 查询、snap 目标计算、归一化辅助
- `PianoValidation`：追加几何与命中的自动化夹具，覆盖行 frame、刻度、黑键命中优先、黑键起始左边界、snap 与锁区判断
- 这一轮仍然严格停留在 Shared 几何层，没有提前进入 reducer、平台壳层或 layer 绘制

## 修改前总体现状

- 修改前，`Shared/Piano` 只有状态和交互语义，没有可绘制场景，也没有命中几何
- 这意味着虽然可以表达“每行独立 `startNote + offsetX + movementScope`”，但还不能回答下面这些问题：
- 某一行的 `A/B/C` 区域分别在哪
- 当前可视白键和黑键有哪些
- `B` 区应该显示哪些自然音刻度
- 某个点命中了按钮、刻度还是某个键
- 当前 `offsetX` 应该吸附到哪个音边界

```text
// 文件路径: NoteMaster_Ver_1/Shared/Piano/
// 函数名/符号: 不适用（阶段 2 目标文件尚不存在）
// 功能说明: 修改前 Shared/Piano 还没有场景对象、SceneBuilder、Geometry，也没有几何级 validation 夹具。
(无代码)
```

## 修改 1：新增 `PianoScene.swift`

### 修改前

- 修改前没有场景对象
- 因此还没有一层稳定的 Shared 结构去承接：
- 每行 frame
- `A/B/C` 区域 rect
- 可见白键、黑键
- 自然音刻度 marker

```text
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoScene.swift
// 函数名/符号: 文件不存在
// 功能说明: 修改前没有钢琴场景对象，Geometry 和 Layer 之间缺少共享的场景中间层。
(无代码)
```

### 修改后

- 新增 `PianoScene`
- 新增 `PianoScene.RowScene`
- `RowScene` 里继续细分了：
- `WhiteKey`
- `BlackKey`
- `ScaleMarker`
- 这样后续几何层、绘制层和命中层都可以围绕同一个场景对象协作，而不是各自重复算一遍布局

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoScene.swift
// 函数名/符号: PianoScene.RowScene.noteRect(for:), PianoScene.RowScene.scaleMarker(for:), PianoScene.rowScene(at:)
// 功能说明: 为钢琴组件引入共享场景层，统一承接每行的区域布局、可见键集合与自然音刻度标记。
struct PianoScene: Equatable, Sendable {
    struct RowScene: Equatable, Sendable {
        struct WhiteKey: Equatable, Sendable {
            var note: NotePitch
            var rect: CGRect
        }

        struct BlackKey: Equatable, Sendable {
            var note: NotePitch
            var rect: CGRect
        }

        struct ScaleMarker: Equatable, Sendable {
            var note: NotePitch
            var x: CGFloat
            var labelText: String
        }

        var rowIndex: Int
        var frame: CGRect
        var controlStripRect: CGRect
        var buttonLeftRect: CGRect
        var buttonRightRect: CGRect
        var scaleRect: CGRect
        var keysRect: CGRect
        var whiteKeys: [WhiteKey]
        var blackKeys: [BlackKey]
        var scaleMarkers: [ScaleMarker]
    }
}
```

## 修改 2：新增 `PianoSceneBuilder.swift`

### 修改前

- 修改前没有 `SceneBuilder`
- 也就是说，哪怕已有 `PianoRowState` 和 `PianoConfiguration`，也还没有“把状态投影成场景”的统一入口
- 后续如果 Geometry、Reducer、Layer 都各自从 `state` 直接推布局，会很快分叉

```text
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoSceneBuilder.swift
// 函数名/符号: 文件不存在
// 功能说明: 修改前没有从 state/configuration 构建钢琴场景的统一入口。
(无代码)
```

### 修改后

- 新增 `PianoSceneBuilder`
- 入口是 `makeScene(bounds:)`
- 内部通过 `makeRowScene(...)` 按行构建：
- `controlStripRect`
- `buttonLeftRect`
- `buttonRightRect`
- `scaleRect`
- `keysRect`
- `visibleKeys`
- `scaleMarkers`
- 这让“多行 bounds -> 行场景数组”的构建过程固定下来，后续 `PianoGeometry` 和 `PianoKeyboardLayer` 都能复用

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoSceneBuilder.swift
// 函数名/符号: makeScene(bounds:), makeRowScene(rowIndex:rowState:bounds:)
// 功能说明: 把组件 state/configuration/bounds 投影成稳定的 PianoScene，为 Geometry 与后续 Layer 提供统一场景输入。
struct PianoSceneBuilder: Equatable, Sendable {
    var configuration: PianoConfiguration
    var state: PianoComponentState

    func makeScene(bounds: CGRect) -> PianoScene {
        let normalizedBounds = bounds.standardized
        guard !normalizedBounds.isNull, !state.rows.isEmpty else {
            return .empty
        }

        let rows = state.rows.enumerated().map { rowIndex, rowState in
            makeRowScene(
                rowIndex: rowIndex,
                rowState: rowState,
                bounds: normalizedBounds
            )
        }

        return PianoScene(
            bounds: normalizedBounds,
            contentRect: contentRect,
            rows: rows
        )
    }
}
```

## 修改 3：新增 `PianoGeometry.swift`

### 修改前

- 修改前没有 Geometry 层
- 因此还无法做这些阶段 2 需要的 Shared 能力：
- 根据点位判断命中了 `A/B/C` 哪个区域
- 根据点位命中某个白键或黑键
- 让 `C` 区黑键命中优先于白键
- 根据 `offsetX` 求最近吸附目标
- 把连续偏移归一化成新的 `startNote + offsetX`

```text
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoGeometry.swift
// 函数名/符号: 文件不存在
// 功能说明: 修改前没有钢琴几何层，平台壳层和 reducer 还没有统一的 hitTest/snap/layout 计算入口。
(无代码)
```

### 修改后

- 新增 `PianoSnapTarget`
- 新增 `PianoGeometry`
- 新增 `PianoLayoutMath`
- `PianoGeometry` 提供了 3 组核心入口：
- 场景读取：`rowScene(at:)`、`rowFrame(at:)`、`noteRect(for:rowIndex:)`
- 命中：`hitTest(_:phase:)`
- 吸附：`nearestSnapTarget(for:)`、`snappedOffsetX(for:)`、`normalizedSnappedRowState(_:)`
- `PianoLayoutMath` 提供了几何细节：
- 行 frame 计算
- 按钮区 / 刻度区 / 键区 rect
- 白键/黑键尺寸
- 音高到几何 x 的映射
- 可见白键/黑键枚举
- 自然音 marker 生成
- snap 搜索

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoGeometry.swift
// 函数名/符号: hitTest(_:phase:), nearestSnapTarget(for:), normalizedSnappedRowState(_:)
// 功能说明: 提供钢琴组件阶段 2 的核心几何入口，统一负责命中、吸附和场景查询。
struct PianoGeometry: Equatable, Sendable {
    func hitTest(
        _ point: CGPoint,
        phase: PianoEventPhase
    ) -> PianoHitResult {
        for rowScene in scene.rows {
            if PianoLayoutMath.contains(point, inInclusiveBoundsOf: rowScene.buttonLeftRect) {
                return makeHitResult(
                    phase: phase,
                    location: point,
                    rowIndex: rowScene.rowIndex,
                    zone: .buttonLeft,
                    note: nil
                )
            }

            if PianoLayoutMath.contains(point, inInclusiveBoundsOf: rowScene.scaleRect) {
                return makeHitResult(
                    phase: phase,
                    location: point,
                    rowIndex: rowScene.rowIndex,
                    zone: .scale,
                    note: nearestScaleMarkerNote(toX: point.x, in: rowScene)
                )
            }

            if PianoLayoutMath.contains(point, inInclusiveBoundsOf: rowScene.keysRect) {
                return makeHitResult(
                    phase: phase,
                    location: point,
                    rowIndex: rowScene.rowIndex,
                    zone: .keys,
                    note: noteHit(at: point, in: rowScene)
                )
            }
        }

        return PianoHitResult(
            phase: phase,
            locationInView: point,
            rowIndex: nil,
            zone: .outside,
            note: nil,
            isInsideActiveZone: false
        )
    }

    func nearestSnapTarget(
        for rowState: PianoRowState
    ) -> PianoSnapTarget {
        PianoLayoutMath.nearestSnapTarget(
            for: rowState,
            configuration: configuration
        )
    }

    func normalizedSnappedRowState(
        _ rowState: PianoRowState
    ) -> PianoRowState {
        let snapTarget = nearestSnapTarget(for: rowState)
        return PianoRowState(
            startNote: snapTarget.note,
            offsetX: 0,
            movementScope: rowState.movementScope
        )
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoGeometry.swift
// 函数名/符号: PianoLayoutMath.noteLeadingX(_:configuration:), keyRect(for:rowState:keysRect:configuration:), visibleKeys(...), scaleMarkers(...)
// 功能说明: 把音高映射到白键/黑键几何位置，并生成当前可视范围内的键集合与自然音刻度。
enum PianoLayoutMath {
    static func noteLeadingX(
        _ note: NotePitch,
        configuration: PianoConfiguration
    ) -> CGFloat {
        if let naturalWhiteIndex = naturalWhiteIndex(for: note.pitchClass) {
            let totalWhiteIndex = (note.octave * 7) + naturalWhiteIndex
            return CGFloat(totalWhiteIndex) * configuration.resolvedWhiteKeyWidth
        }

        let blackKeyWidth = blackKeyWidth(configuration: configuration)
        let leftWhiteIndex = (note.octave * 7)
            + leftNaturalWhiteIndex(for: note.pitchClass)
        return (CGFloat(leftWhiteIndex + 1) * configuration.resolvedWhiteKeyWidth)
            - (blackKeyWidth / 2)
    }

    static func keyRect(
        for note: NotePitch,
        rowState: PianoRowState,
        keysRect: CGRect,
        configuration: PianoConfiguration
    ) -> CGRect {
        let originX = keysRect.minX
            + noteLeadingX(note, configuration: configuration)
            - noteLeadingX(rowState.startNote, configuration: configuration)
            - rowState.offsetX

        if note.pitchClass.isNatural {
            return CGRect(
                x: originX,
                y: keysRect.minY,
                width: configuration.resolvedWhiteKeyWidth,
                height: keysRect.height
            )
        }

        return CGRect(
            x: originX,
            y: keysRect.minY,
            width: blackKeyWidth(configuration: configuration),
            height: blackKeyHeight(configuration: configuration)
        )
    }
}
```

## 修改 4：扩展 `PianoValidation.swift`

### 修改前

- 修改前 `PianoValidationRunner` 只覆盖阶段 1 的基础模型夹具
- `makeFixtures()` 只有：
- 配置钳制
- 黑键起始音保留
- 混合作用域状态
- scale drag 会话基线数据
- 语义事件载荷
- 按钮方向映射
- 还没有几何与命中层的自动化夹具

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift
// 函数名/符号: makeFixtures()
// 功能说明: 修改前只覆盖阶段 1 的模型与事件夹具，尚未进入几何、命中、吸附验证。
static func makeFixtures() -> [PianoValidationFixture] {
    [
        PianoValidationFixture(
            name: "configuration_resolves_safe_metrics",
            validate: validateConfigurationResolvesSafeMetrics
        ),
        PianoValidationFixture(
            name: "accidental_start_note_is_preserved",
            validate: validateAccidentalStartNote
        ),
        PianoValidationFixture(
            name: "component_state_supports_mixed_scopes",
            validate: validateComponentStateSupportsMixedScopes
        ),
        PianoValidationFixture(
            name: "scale_drag_interaction_preserves_parallel_rows",
            validate: validateScaleDragInteraction
        ),
        PianoValidationFixture(
            name: "semantic_events_keep_preview_payload",
            validate: validateSemanticEvents
        ),
        PianoValidationFixture(
            name: "hit_result_maps_button_direction",
            validate: validateHitResultButtonDirection
        )
    ]
}
```

### 修改后

- `makeFixtures()` 追加了 6 个阶段 2 夹具：
- `scene_row_frames_and_zones_are_stable`
- `scale_markers_are_natural_only`
- `accidental_anchor_aligns_start_note_left_edge`
- `keys_hit_test_prioritizes_black_keys`
- `snap_target_and_normalization_follow_note_edges`
- `active_zone_tracking_respects_locked_mode`
- 这样阶段 2 的几何关键路径已经有 Shared 层自动化断言，不需要等平台壳层接入后才发现几何错误

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift
// 函数名/符号: makeFixtures()
// 功能说明: 修改后把几何、命中、吸附和锁区判断补进 validation runner，覆盖阶段 2 的核心 Shared 能力。
static func makeFixtures() -> [PianoValidationFixture] {
    [
        // ... 阶段 1 基础夹具 ...
        PianoValidationFixture(
            name: "scene_row_frames_and_zones_are_stable",
            validate: validateSceneRowFramesAndZones
        ),
        PianoValidationFixture(
            name: "scale_markers_are_natural_only",
            validate: validateScaleMarkersUseNaturalNotesOnly
        ),
        PianoValidationFixture(
            name: "accidental_anchor_aligns_start_note_left_edge",
            validate: validateAccidentalAnchorAlignment
        ),
        PianoValidationFixture(
            name: "keys_hit_test_prioritizes_black_keys",
            validate: validateHitTestPrioritizesBlackKeys
        ),
        PianoValidationFixture(
            name: "snap_target_and_normalization_follow_note_edges",
            validate: validateSnapTargetAndNormalization
        ),
        PianoValidationFixture(
            name: "active_zone_tracking_respects_locked_mode",
            validate: validateActiveZoneTracking
        )
    ]
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift
// 函数名/符号: validateSceneRowFramesAndZones(), validateHitTestPrioritizesBlackKeys(), validateSnapTargetAndNormalization()
// 功能说明: 对阶段 2 最容易出错的几何细节做自动化断言，包括行 frame、黑键优先命中以及 snap/归一化结果。
static func validateSceneRowFramesAndZones() -> [PianoValidationIssue] {
    // 校验 rowFrame、button rect、scale rect、keys rect、contentRect.height
}

static func validateHitTestPrioritizesBlackKeys() -> [PianoValidationIssue] {
    // 校验同一位置上黑键命中优先于底下白键
}

static func validateSnapTargetAndNormalization() -> [PianoValidationIssue] {
    // 校验 offsetX 对应的 snap note，以及归一化后的 startNote/offsetX
}
```

## 验证情况

- 本次阶段 2 做了以下验证：
- `ReadLints`：`Shared/Piano` 目录无 lint 错误
- `xcrun swiftc -typecheck`：对 `NotePitch.swift` + `Shared/Piano` 全量文件做了类型检查，结果通过
- 本次没有跑整工程 `xcodebuild`；当前收口依据是 Shared 层 lint 与 `swiftc` 类型检查通过

```text
// 验证命令: xcrun swiftc -typecheck ...
// 功能说明: 对阶段 1 + 阶段 2 的 Shared/Piano 文件做语法/类型级校验。
xcrun swiftc -typecheck \
  "NoteMaster_Ver_1/Shared/Fretboard/NotePitch.swift" \
  "NoteMaster_Ver_1/Shared/Piano/PianoConfiguration.swift" \
  "NoteMaster_Ver_1/Shared/Piano/PianoState.swift" \
  "NoteMaster_Ver_1/Shared/Piano/PianoInteraction.swift" \
  "NoteMaster_Ver_1/Shared/Piano/PianoScene.swift" \
  "NoteMaster_Ver_1/Shared/Piano/PianoSceneBuilder.swift" \
  "NoteMaster_Ver_1/Shared/Piano/PianoGeometry.swift" \
  "NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift"

// 结果: 通过
```

## 本次明确没有做的事

- 没有新增 `PianoInteractionReducer.swift`
- 没有新增 `PianoKeyboardLayer.swift` / `PianoRowLayer.swift`
- 没有实现 `iOSPianoKeyboardView.swift`
- 没有实现 `macOSPianoKeyboardView.swift`
- 没有把 `PianoValidationRunner` 挂到 `iOS/macOS AppDelegate`

## 对后续阶段的影响

- 阶段 3 可以直接基于 `PianoHitResult`、`PianoScene`、`isInsideActiveZone` 和 `nearestSnapTarget(...)` 来写 reducer
- 阶段 4 的 layer 绘制不需要再重复推导白键/黑键/刻度布局，只需要消费 `PianoScene`
- 阶段 5/6 的平台壳层也不需要自行判断 `A/B/C` 区域和键命中，可以直接走 `PianoGeometry.hitTest(...)`
