# 20260415_150641_stage4_staff_to_piano_answer_surface_promotion

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260415_150641`
- 记录依据：基于当前工作区 `changes`、`git status --short`、`git diff --stat`、分组 `git diff --unified=20`、当前文件内容，以及本轮验证结果整理，不直接粘贴原始 `git diff`
- 记录范围：本次只记录“实施阶段 4”真实落地的代码改动；目标是新增 `staffToPiano` 组合，让 `piano` 进入正式 `ExerciseScene` 主场景，并补齐 accessory / legacy 回退合同
- 当前涉及文件相对 `HEAD` 的累计 diff 统计：`12 files changed, 378 insertions(+), 50 deletions(-)`
- 统计口径说明：
- 当前 `git status --short` 只包含下面这 12 个 `Swift` 文件，因此本次统计口径直接等同于阶段 4 本轮改动集
- 本记录文件本身是新增 markdown 记录，不计入上面的 `12 files changed`
- 本次实际代码修改文件：
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseLayoutPreferences.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseScene.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy+Normalization.swift`
- `NoteMaster_Ver_1/Shared/Exercise/LegacyPageLayoutAdapter.swift`
- `NoteMaster_Ver_1/Platform/iOS/Exercise/iOSExerciseSceneRenderer.swift`
- `NoteMaster_Ver_1/Platform/macOS/Exercise/macOSExerciseSceneRenderer.swift`
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidationSceneCore.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidationExercisePolicy.swift`
- 本次未改动但刻意保持不动的文件：
- `NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift`：阶段 4 只落内部 scene 能力，不提前把 `staffToPiano` 暴露到设置面板
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseSceneValidator.swift`：本轮没有新增专用 validator case，而是复用现有 duplicate-surface 校验，并用新的 validation fixture 锁合同
- `NoteMaster_Ver_1/Platform/iOS/Controls/iOSPianoSurfaceView.swift`：继续复用现有 piano surface 组件，不在阶段 4 提前改交互输入链路
- `NoteMaster_Ver_1/Platform/macOS/Controls/macOSPianoSurfaceView.swift`：同上，保持组件实现不动
- `NoteMaster_Ver_1/Shared/Controls/SettingsPanelStateContext.swift`：继续通过 `LegacyPageLayoutAdapter.reconcile(...)` 回写 accessory 显隐，不额外改 state context
- 验证结果：
- `ReadLints`：对本轮 12 个改动文件读取诊断，无错误
- `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "generic/platform=macOS" build`：构建通过
- `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "generic/platform=iOS Simulator" build`：构建通过
- 本次没做的事情：
- 没有开放 `TrainerExerciseMode.sr1` 的设置入口，也没有修改 `SettingsPanelModel` 把 `staffToPiano` 暴露到 UI
- 没有把 piano 输入事件桥接到答题链路；这仍属于阶段 5
- 没有修改 `.md` 计划文件本身
- 没有提交代码

## 本次结论

- `ExerciseCompositionPreset` 已新增 `staffToPiano`，`ExerciseSurfaceNode` 已新增 `pianoAnswer`
- `ExerciseCompositionPolicy` 已能正式构造 `staff -> piano` scene，且 `stacked` 下保持上方 `staff.fitContent`、下方 `piano.weighted(1)`
- `ExerciseCompositionPolicy.makePresentation(...)` 已封住“主场景 piano + accessory piano”重复出现的根因：当 preset 已使用主 `piano` answer surface 时，不再把 `pianoPanelState.isVisible` 回灌成 accessory
- `LegacyPageLayoutAdapter` 已明确对 `staffToPiano` 只做 legacy fallback，不尝试反投影出新的 `PageDisplayState`
- iOS / macOS renderer 与 controller 中的钢琴宿主命名已经从 accessory 语义去耦，统一收口为可复用的 `pianoSurfaceView`
- 自动化 validation 已新增两组阶段 4 合同：一组锁 `staffToPiano` 主 scene 结构，一组锁 legacy back-projection / reconcile 行为

## 修改 1：新增 `staffToPiano` preset，并给 preset 增加“主 answer surface”语义谓词

### 修改前

- `ExerciseCompositionPreset` 只有旧的 4 个组合
- shared policy 内部没有统一谓词可判断“某个 preset 是否已经占用主 `piano` / 主 `natural note strip` answer surface”

```swift
// NoteMaster_Ver_1/Shared/Exercise/ExerciseLayoutPreferences.swift
// 函数名/符号: enum ExerciseCompositionPreset
// 功能说明: 修改前只定义 staff/fretboard、target/fretboard、fretboard/strip、self-answer 四种组合；
// 还没有 staffToPiano，也没有主 answer-surface 语义谓词。
enum ExerciseCompositionPreset: String, CaseIterable, Equatable, Hashable, Sendable {
    case staffToFretboard
    case targetPromptToFretboard
    case fretboardToNaturalNoteStrip
    case fretboardSelfAnswer
}
```

### 修改后

- 新增 `case staffToPiano`
- 新增 `usesMainNaturalNoteStripAnswerSurface` / `usesMainPianoAnswerSurface`
- 后续 normalization / composition policy / accessory 组装统一消费这两个谓词，而不是散落硬编码

```swift
// NoteMaster_Ver_1/Shared/Exercise/ExerciseLayoutPreferences.swift
// 函数名/符号: enum ExerciseCompositionPreset / extension ExerciseCompositionPreset
// 功能说明: 修改后新增 staffToPiano，并把“谁占用主 answer surface”的判断收口成共享谓词；
// 后续可以避免在多个文件重复硬编码 `.fretboardToNaturalNoteStrip` / `.staffToPiano` 判断。
enum ExerciseCompositionPreset: String, CaseIterable, Equatable, Hashable, Sendable {
    case staffToFretboard
    case staffToPiano
    case targetPromptToFretboard
    case fretboardToNaturalNoteStrip
    case fretboardSelfAnswer
}

extension ExerciseCompositionPreset {
    var usesMainNaturalNoteStripAnswerSurface: Bool {
        self == .fretboardToNaturalNoteStrip
    }

    var usesMainPianoAnswerSurface: Bool {
        self == .staffToPiano
    }
}
```

## 修改 2：新增主场景 `pianoAnswer` surface，避免把正式答题钢琴继续伪装成 accessory

### 修改前

- `ExerciseSurfaceNode` 只有 `pianoAccessory`
- 即使 scene 中出现 `.piano`，它在共享语义上也只有 auxiliary 角色

```swift
// NoteMaster_Ver_1/Shared/Exercise/ExerciseScene.swift
// 函数名/符号: extension ExerciseSurfaceNode
// 功能说明: 修改前 shared surface 集合里只有 auxiliary 语义的 piano；
// piano 还不能作为正式 answer surface 进入主 scene。
static let naturalNoteStripAccessory = ExerciseSurfaceNode(
    id: .naturalNoteStrip,
    kind: .naturalNoteStrip,
    roles: [.auxiliary],
    presentationStyle: .horizontalStrip
)
static let pianoAccessory = ExerciseSurfaceNode(
    id: .piano,
    kind: .piano,
    roles: [.auxiliary]
)
```

### 修改后

- 新增 `pianoAnswer`
- `pianoAccessory` 保留，主 `piano` 与 accessory `piano` 的角色语义正式拆开

```swift
// NoteMaster_Ver_1/Shared/Exercise/ExerciseScene.swift
// 函数名/符号: extension ExerciseSurfaceNode.pianoAnswer
// 功能说明: 修改后 shared scene 语义里新增 answer-only 的主 piano surface；
// accessory piano 继续保留给三栏 / floating / collapsible 场景复用。
static let naturalNoteStripAccessory = ExerciseSurfaceNode(
    id: .naturalNoteStrip,
    kind: .naturalNoteStrip,
    roles: [.auxiliary],
    presentationStyle: .horizontalStrip
)
static let pianoAnswer = ExerciseSurfaceNode(
    id: .piano,
    kind: .piano,
    roles: [.answer]
)
static let pianoAccessory = ExerciseSurfaceNode(
    id: .piano,
    kind: .piano,
    roles: [.auxiliary]
)
```

## 修改 3：composition policy 现在正式支持 `staffToPiano`，并从根上阻止 duplicate `.piano`

### 修改前

- `makePresentation(...)` 会把 `pianoPanelState.isVisible` 无条件并回 `isPianoAccessoryVisible`
- `resolvedSceneSurfaces(for:)` 不认识 `staffToPiano`
- `sideBySide` 只支持 `staffToFretboard` / `targetPromptToFretboard`
- accessory subtree 是否挂 natural strip / piano 仍靠具体 preset 名称硬编码

```swift
// NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy.swift
// 函数名/符号: static func makePresentation(from:) / resolvedSceneSurfaces(for:) / makeSideBySideSceneNode(from:preferences:) / makeAccessorySceneNode(preferences:)
// 功能说明: 修改前 shared composition policy 还不知道 staffToPiano；
// 只要 piano panel 可见，就会把 accessory piano 挂回 scene。
static func makePresentation(
    from input: ExerciseCompositionPolicyInput
) -> ExercisePresentationState {
    var resolvedLayoutPreferences = ExerciseCompositionPolicy
        .normalizedPreferences(
            input.layoutPreferences,
            trainerDisplayState: input.trainerDisplayState
        )
    resolvedLayoutPreferences.isPianoAccessoryVisible = resolvedLayoutPreferences
        .isPianoAccessoryVisible
        || input.pianoPanelState.isVisible
    let scene = makeScene(
        preferences: resolvedLayoutPreferences
    )
    // ... 其余代码保持不变 ...
}

private static func resolvedSceneSurfaces(
    for preferences: ExerciseLayoutPreferences
) -> (prompt: ExerciseSurfaceNode, answer: ExerciseSurfaceNode) {
    switch preferences.compositionPreset {
    case .staffToFretboard:
        return (.staffPrompt, .fretboardAnswer)
    case .targetPromptToFretboard:
        return (.targetPrompt, .fretboardAnswer)
    case .fretboardToNaturalNoteStrip:
        return (.fretboardPrompt, .naturalNoteStripAnswer)
    case .fretboardSelfAnswer:
        return (.fretboardPromptAndAnswer, .fretboardPromptAndAnswer)
    }
}

// ... 省略未变代码 ...

case .staffToFretboard, .targetPromptToFretboard:
    return .makeSplit(
        axis: .horizontal,
        children: [
            ExerciseSceneSplitChild(node: .surface(sceneSurfaces.prompt), mainAxisSizing: .weighted(1)),
            ExerciseSceneSplitChild(node: .surface(sceneSurfaces.answer), mainAxisSizing: .weighted(1))
        ]
    )

if preferences.isNaturalNoteStripVisible,
   preferences.compositionPreset != .fretboardToNaturalNoteStrip {
    accessoryChildren.append(
        makeVerticalSceneChild(for: .naturalNoteStripAccessory, weight: 0.7)
    )
}

if preferences.isPianoAccessoryVisible {
    accessoryChildren.append(
        makeVerticalSceneChild(for: .pianoAccessory, weight: 1.3)
    )
}
```

### 修改后

- `makePresentation(...)` 只在“当前 preset 没有占用主 `piano` answer surface”时才把 `pianoPanelState.isVisible` 映射成 accessory piano
- `resolvedSceneSurfaces(for:)` 新增 `(.staffPrompt, .pianoAnswer)`
- `sideBySide` 的多 surface 路径也正式接受 `staffToPiano`
- accessory subtree 挂接统一改为通过谓词判断，避免把主 `piano` 或主 `natural note strip` 再重复拼成 accessory

```swift
// NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy.swift
// 函数名/符号: static func makePresentation(from:) / resolvedSceneSurfaces(for:) / makeSideBySideSceneNode(from:preferences:) / makeAccessorySceneNode(preferences:)
// 功能说明: 修改后 shared composition policy 已能构造 staff -> piano 主 scene，
// 同时在进入 makePresentation 时先把 accessory piano 的重复注入根因切断。
static func makePresentation(
    from input: ExerciseCompositionPolicyInput
) -> ExercisePresentationState {
    var resolvedLayoutPreferences = ExerciseCompositionPolicy
        .normalizedPreferences(
            input.layoutPreferences,
            trainerDisplayState: input.trainerDisplayState
        )
    resolvedLayoutPreferences.isPianoAccessoryVisible =
        resolvedLayoutPreferences.isPianoAccessoryVisible
        || (
            input.pianoPanelState.isVisible
                && !resolvedLayoutPreferences.compositionPreset
                .usesMainPianoAnswerSurface
        )
    let scene = makeScene(
        preferences: resolvedLayoutPreferences
    )
    // ... 其余代码保持不变 ...
}

private static func resolvedSceneSurfaces(
    for preferences: ExerciseLayoutPreferences
) -> (prompt: ExerciseSurfaceNode, answer: ExerciseSurfaceNode) {
    switch preferences.compositionPreset {
    case .staffToFretboard:
        return (.staffPrompt, .fretboardAnswer)
    case .staffToPiano:
        return (.staffPrompt, .pianoAnswer)
    case .targetPromptToFretboard:
        return (.targetPrompt, .fretboardAnswer)
    case .fretboardToNaturalNoteStrip:
        return (.fretboardPrompt, .naturalNoteStripAnswer)
    case .fretboardSelfAnswer:
        return (.fretboardPromptAndAnswer, .fretboardPromptAndAnswer)
    }
}

// ... 省略未变代码 ...

case .staffToFretboard, .staffToPiano, .targetPromptToFretboard:
    return .makeSplit(
        axis: .horizontal,
        children: [
            ExerciseSceneSplitChild(node: .surface(sceneSurfaces.prompt), mainAxisSizing: .weighted(1)),
            ExerciseSceneSplitChild(node: .surface(sceneSurfaces.answer), mainAxisSizing: .weighted(1))
        ]
    )

if preferences.isNaturalNoteStripVisible,
   !preferences.compositionPreset.usesMainNaturalNoteStripAnswerSurface {
    accessoryChildren.append(
        makeVerticalSceneChild(for: .naturalNoteStripAccessory, weight: 0.7)
    )
}

if preferences.isPianoAccessoryVisible,
   !preferences.compositionPreset.usesMainPianoAnswerSurface {
    accessoryChildren.append(
        makeVerticalSceneChild(for: .pianoAccessory, weight: 1.3)
    )
}
```

## 修改 4：normalization 现在允许 `staffToPiano`，并在 preset 层强制关闭 accessory piano

### 修改前

- normalization 只会为 `fretboardToNaturalNoteStrip` 强制打开 `isNaturalNoteStripVisible`
- `isCompositionPresetSupported(...)` 里 `single / sequence / sr1 / sr2` 仍不允许 `staffToPiano`
- layout 支持矩阵里也没有 `staffToPiano`

```swift
// NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy+Normalization.swift
// 函数名/符号: static func normalizedPreferences(_:trainerDisplayState:) / isCompositionPresetSupported(_:for:) / normalizedLayoutPreset(_:for:) / isLayoutPresetSupported(_:for:)
// 功能说明: 修改前 normalization 还不知道 staffToPiano；
// SR 相关 mode 仍只允许 staffToFretboard / targetPromptToFretboard。
if normalized.compositionPreset == .fretboardToNaturalNoteStrip {
    normalized.isNaturalNoteStripVisible = true
}

switch exerciseMode {
case .single, .sequence, .sr1, .sr2:
    switch preset {
    case .staffToFretboard, .targetPromptToFretboard:
        return true
    case .fretboardToNaturalNoteStrip, .fretboardSelfAnswer:
        return false
    }
case .positionPrompt:
    switch preset {
    case .fretboardToNaturalNoteStrip, .fretboardSelfAnswer:
        return true
    case .staffToFretboard, .targetPromptToFretboard:
        return false
    }
}

switch compositionPreset {
case .staffToFretboard,
     .targetPromptToFretboard,
     .fretboardToNaturalNoteStrip:
    return .stacked
case .fretboardSelfAnswer:
    return .singleSurface
}
```

### 修改后

- `staffToPiano` 进入 preset 支持矩阵
- 当 preset 使用主 `piano` answer surface 时，normalization 会强制把 `isPianoAccessoryVisible` 压回 `false`
- `staffToPiano` 继承 multi-surface layout 支持能力

```swift
// NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy+Normalization.swift
// 函数名/符号: static func normalizedPreferences(_:trainerDisplayState:) / isCompositionPresetSupported(_:for:) / normalizedLayoutPreset(_:for:) / isLayoutPresetSupported(_:for:)
// 功能说明: 修改后 normalization 已把 staffToPiano 纳入正式 preset 支持范围，
// 并在 preset 已占用主 piano answer surface 时强制关闭 accessory piano。
if normalized.compositionPreset.usesMainNaturalNoteStripAnswerSurface {
    normalized.isNaturalNoteStripVisible = true
}
if normalized.compositionPreset.usesMainPianoAnswerSurface {
    normalized.isPianoAccessoryVisible = false
}

switch exerciseMode {
case .single, .sequence, .sr1, .sr2:
    switch preset {
    case .staffToFretboard, .staffToPiano, .targetPromptToFretboard:
        return true
    case .fretboardToNaturalNoteStrip, .fretboardSelfAnswer:
        return false
    }
case .positionPrompt:
    switch preset {
    case .fretboardToNaturalNoteStrip, .fretboardSelfAnswer:
        return true
    case .staffToFretboard, .staffToPiano, .targetPromptToFretboard:
        return false
    }
}

switch compositionPreset {
case .staffToFretboard,
     .staffToPiano,
     .targetPromptToFretboard,
     .fretboardToNaturalNoteStrip:
    return .stacked
case .fretboardSelfAnswer:
    return .singleSurface
}
```

## 修改 5：legacy adapter 明确对 `staffToPiano` 只回退 legacy，不做伪造反投影

### 修改前

- `projectedPageDisplayState(...)` 会直接走 `makeLegacyCompatiblePresentation(...)`
- 没有 `staffToPiano` 的提前分流
- fallback page 的返回逻辑散落在函数尾部 `switch`

```swift
// NoteMaster_Ver_1/Shared/Exercise/LegacyPageLayoutAdapter.swift
// 函数名/符号: static func projectedPageDisplayState(from:trainerDisplayState:)
// 功能说明: 修改前 adapter 不区分 staffToPiano；
// 所有 preset 都会先尝试做 legacy-compatible presentation，再从 scene 反投影 page。
static func projectedPageDisplayState(
    from preferences: ExerciseLayoutPreferences,
    trainerDisplayState: TrainerDisplayState
) -> PageDisplayState {
    let presentationState = ExerciseCompositionPolicy
        .makeLegacyCompatiblePresentation(
            from: policyInput(
                trainerDisplayState: trainerDisplayState,
                pianoPanelState: .init(),
                layoutPreferences: preferences
            )
        )

    if let legacyPageDisplayState = presentationState.legacyPageDisplayState {
        return legacyPageDisplayState
    }

    switch trainerDisplayState.exerciseMode {
    case .single, .sequence, .sr1, .sr2:
        return .default
    case .positionPrompt:
        return .positionPrompt
    }
}
```

### 修改后

- 先做 `normalizedPreferences(...)`
- 如果是 `staffToPiano`，直接回落到 legacy baseline，不再尝试伪造新的 page 投影
- fallback page 逻辑收口到 `fallbackPageDisplayState(...)`

```swift
// NoteMaster_Ver_1/Shared/Exercise/LegacyPageLayoutAdapter.swift
// 函数名/符号: static func projectedPageDisplayState(from:trainerDisplayState:) / private static func fallbackPageDisplayState(for:)
// 功能说明: 修改后 adapter 对 staffToPiano 明确走“直接回退 legacy baseline”的路径；
// 这样 shared scene 可以保留 staffToPiano，而 legacy page 不会被迫伪造新组合。
static func projectedPageDisplayState(
    from preferences: ExerciseLayoutPreferences,
    trainerDisplayState: TrainerDisplayState
) -> PageDisplayState {
    let resolvedPreferences = normalizedPreferences(
        preferences,
        trainerDisplayState: trainerDisplayState
    )
    if resolvedPreferences.compositionPreset == .staffToPiano {
        return fallbackPageDisplayState(
            for: trainerDisplayState.exerciseMode
        )
    }

    let presentationState = ExerciseCompositionPolicy
        .makeLegacyCompatiblePresentation(
            from: policyInput(
                trainerDisplayState: trainerDisplayState,
                pianoPanelState: .init(),
                layoutPreferences: resolvedPreferences
            )
        )

    if let legacyPageDisplayState = presentationState.legacyPageDisplayState {
        return legacyPageDisplayState
    }

    return fallbackPageDisplayState(for: trainerDisplayState.exerciseMode)
}

private static func fallbackPageDisplayState(
    for exerciseMode: TrainerExerciseMode
) -> PageDisplayState {
    switch exerciseMode {
    case .single, .sequence, .sr1, .sr2:
        return .default
    case .positionPrompt:
        return .positionPrompt
    }
}
```

## 修改 6：平台 renderer / controller 去掉钢琴宿主上的 accessory 命名耦合

### 修改前

- iOS / macOS renderer 里 `.piano` surface 对应的成员名仍然叫 `pianoAccessoryView`
- 两端 controller 也都用 `pianoAccessorySurfaceView` 命名，把它传进 renderer

```swift
// NoteMaster_Ver_1/Platform/iOS/Exercise/iOSExerciseSceneRenderer.swift
// 函数名/符号: final class iOSExerciseSceneRenderer.init / setVisibility(of:isHidden:) / view(for:)
// 功能说明: 修改前 iOS renderer 虽然已经能渲染 `.piano` surface，
// 但宿主 view 名称仍然绑定 accessory 语义。
private let naturalNoteStripView: iOSNaturalNoteStripView
private let pianoAccessoryView: UIView
private let fretboardView: iOSFretboardView

init(
    safeAreaHeightAnchor: NSLayoutDimension,
    metrics: Metrics,
    sequenceRegenerateButton: UIButton,
    staffView: iOSStaffView,
    targetNotePromptView: iOSTargetNotePromptView,
    naturalNoteStripView: iOSNaturalNoteStripView,
    pianoAccessoryView: UIView,
    fretboardView: iOSFretboardView
) {
    self.naturalNoteStripView = naturalNoteStripView
    self.pianoAccessoryView = pianoAccessoryView
    self.fretboardView = fretboardView
}

case .piano:
    pianoAccessoryView.isHidden = isHidden

case .piano:
    return pianoAccessoryView
```

```swift
// NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名/符号: exerciseSceneRenderer / pianoAccessorySurfaceView / interruptActivePianoPlayback(reason:) / applyPianoAccessoryState()
// 功能说明: 修改前 iOS controller 也把统一 piano surface 继续叫做 accessory surface，
// 容易误导后续把主场景 piano 当成附属区域处理。
private lazy var exerciseSceneRenderer = iOSExerciseSceneRenderer(
    // ... 省略未变参数 ...
    naturalNoteStripView: naturalNoteStripView,
    pianoAccessoryView: pianoAccessorySurfaceView,
    fretboardView: fretboardView
)

private lazy var pianoAccessorySurfaceView: iOSPianoSurfaceView = {
    let pianoAccessorySurfaceView = iOSPianoSurfaceView(
        chromeStyle: .card,
        panelState: pianoPanelState
    )
    pianoAccessorySurfaceView.onPreviewStarted = { [weak self] preview in
        self?.handlePianoSemanticEvent(.previewStarted(preview))
    }
    return pianoAccessorySurfaceView
}()

pianoAccessorySurfaceView.interruptActiveInteraction()
pianoAccessorySurfaceView.applySharedSettings(pianoPanelState.settingsSlice)
pianoAccessorySurfaceView.showsComponentBoundsOverlay = false
```

### 修改后

- iOS / macOS renderer 统一重命名为 `pianoSurfaceView`
- 两端 controller 的统一钢琴 surface 也改名成 `pianoSurfaceView`
- 这一步只做语义去耦，不改变 piano 组件本身实现

```swift
// NoteMaster_Ver_1/Platform/iOS/Exercise/iOSExerciseSceneRenderer.swift
// 函数名/符号: final class iOSExerciseSceneRenderer.init / setVisibility(of:isHidden:) / view(for:)
// 功能说明: 修改后 iOS renderer 已把 `.piano` 对应的宿主 view 去 accessory 语义化；
// 同一个 surface view 可以既服务 accessory scene，也服务主 answer scene。
private let naturalNoteStripView: iOSNaturalNoteStripView
private let pianoSurfaceView: UIView
private let fretboardView: iOSFretboardView

init(
    safeAreaHeightAnchor: NSLayoutDimension,
    metrics: Metrics,
    sequenceRegenerateButton: UIButton,
    staffView: iOSStaffView,
    targetNotePromptView: iOSTargetNotePromptView,
    naturalNoteStripView: iOSNaturalNoteStripView,
    pianoSurfaceView: UIView,
    fretboardView: iOSFretboardView
) {
    self.naturalNoteStripView = naturalNoteStripView
    self.pianoSurfaceView = pianoSurfaceView
    self.fretboardView = fretboardView
}

case .piano:
    pianoSurfaceView.isHidden = isHidden

case .piano:
    return pianoSurfaceView
```

```swift
// NoteMaster_Ver_1/Platform/macOS/Exercise/macOSExerciseSceneRenderer.swift
// 函数名/符号: final class macOSExerciseSceneRenderer.init / configureStaticHierarchy() / setVisibility(of:isHidden:) / view(for:)
// 功能说明: 修改后 macOS renderer 与 iOS 同步改为中性命名；
// `.piano` 不再被 API 名称误导为“只能是 accessory view”。
private let naturalNoteStripView: macOSNaturalNoteStripView
private let pianoSurfaceView: NSView
private let fretboardView: macOSFretboardView

init(
    safeAreaHeightAnchor: NSLayoutDimension,
    metrics: Metrics,
    sequenceRegenerateButton: NSButton,
    staffView: macOSStaffView,
    targetNotePromptView: macOSTargetNotePromptView,
    naturalNoteStripView: macOSNaturalNoteStripView,
    pianoSurfaceView: NSView,
    fretboardView: macOSFretboardView
) {
    self.naturalNoteStripView = naturalNoteStripView
    self.pianoSurfaceView = pianoSurfaceView
    self.fretboardView = fretboardView
}

pianoSurfaceView.translatesAutoresizingMaskIntoConstraints = false

case .piano:
    pianoSurfaceView.isHidden = isHidden

case .piano:
    return pianoSurfaceView
```

```swift
// NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名/符号: exerciseSceneRenderer / pianoSurfaceView / interruptActivePianoPlayback(reason:) / applyPianoAccessoryState()
// 功能说明: 修改后 iOS controller 不再把共享钢琴 surface 命名为 accessory；
// 阶段 5 再把 SR-1 的答题输入接进来时，就不会和命名语义打架。
private lazy var exerciseSceneRenderer = iOSExerciseSceneRenderer(
    // ... 省略未变参数 ...
    naturalNoteStripView: naturalNoteStripView,
    pianoSurfaceView: pianoSurfaceView,
    fretboardView: fretboardView
)

private lazy var pianoSurfaceView: iOSPianoSurfaceView = {
    let pianoSurfaceView = iOSPianoSurfaceView(
        chromeStyle: .card,
        panelState: pianoPanelState
    )
    pianoSurfaceView.onPreviewStarted = { [weak self] preview in
        self?.handlePianoSemanticEvent(.previewStarted(preview))
    }
    return pianoSurfaceView
}()

pianoSurfaceView.interruptActiveInteraction()
pianoSurfaceView.applySharedSettings(pianoPanelState.settingsSlice)
pianoSurfaceView.showsComponentBoundsOverlay = false
```

```swift
// NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名/符号: exerciseSceneRenderer / pianoSurfaceView / interruptActivePianoPlayback(reason:) / applyPianoDemoState()
// 功能说明: 修改后 macOS controller 同步使用中性命名；
// 共享 piano surface 后续可以直接复用进主 scene answer 链路。
private lazy var exerciseSceneRenderer = macOSExerciseSceneRenderer(
    // ... 省略未变参数 ...
    naturalNoteStripView: naturalNoteStripView,
    pianoSurfaceView: pianoSurfaceView,
    fretboardView: fretboardView
)

private lazy var pianoSurfaceView: macOSPianoSurfaceView = {
    let pianoSurfaceView = macOSPianoSurfaceView(
        chromeStyle: .card,
        panelState: pianoPanelState
    )
    pianoSurfaceView.onPreviewStarted = { [weak self] preview in
        self?.handlePianoSemanticEvent(.previewStarted(preview))
    }
    return pianoSurfaceView
}()

pianoSurfaceView.interruptActiveInteraction()
pianoSurfaceView.applySharedSettings(pianoPanelState.settingsSlice)
pianoSurfaceView.showsComponentBoundsOverlay = false
```

## 修改 7：把阶段 4 的两个 validation fixture 注册进总入口

### 修改前

- validation runner 还没有 `staffToPiano` 相关 fixture

```swift
// NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数名/符号: static func makeFixtures()
// 功能说明: 修改前总 fixture 列表里没有阶段 4 的 staffToPiano scene / legacy back-projection 合同。
ExerciseCompositionValidationFixture(
    name: "composition_policy_projects_supported_presets_to_expected_scenes",
    validate: validateCompositionPolicyProjectsSupportedPresetsToExpectedScenes
),
ExerciseCompositionValidationFixture(
    name: "accessory_scene_nodes_follow_presentation_strategy",
    validate: validateAccessorySceneNodesFollowPresentationStrategy
),
ExerciseCompositionValidationFixture(
    name: "legacy_compatible_policy_falls_back_when_scene_exceeds_page_model",
    validate: validateLegacyCompatiblePolicyFallsBackWhenSceneExceedsPageModel
)
```

### 修改后

- 新注册 `staff_to_piano_scene_promotes_main_piano_answer_surface`
- 新注册 `staff_to_piano_skips_legacy_back_projection`

```swift
// NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数名/符号: static func makeFixtures()
// 功能说明: 修改后阶段 4 的 staffToPiano 结构合同和 legacy 合同都进入统一 validation runner，
// 不会出现“函数写了但 fixture 没有被执行”的空跑情况。
ExerciseCompositionValidationFixture(
    name: "composition_policy_projects_supported_presets_to_expected_scenes",
    validate: validateCompositionPolicyProjectsSupportedPresetsToExpectedScenes
),
ExerciseCompositionValidationFixture(
    name: "staff_to_piano_scene_promotes_main_piano_answer_surface",
    validate: validateStaffToPianoScenePromotesMainPianoAnswerSurface
),
ExerciseCompositionValidationFixture(
    name: "accessory_scene_nodes_follow_presentation_strategy",
    validate: validateAccessorySceneNodesFollowPresentationStrategy
),
ExerciseCompositionValidationFixture(
    name: "staff_to_piano_skips_legacy_back_projection",
    validate: validateStaffToPianoSkipsLegacyBackProjection
),
ExerciseCompositionValidationFixture(
    name: "legacy_compatible_policy_falls_back_when_scene_exceeds_page_model",
    validate: validateLegacyCompatiblePolicyFallsBackWhenSceneExceedsPageModel
)
```

## 修改 8：新增 shared scene validation，锁住 `staffToPiano` 的主场景合同

### 修改前

- `ExerciseCompositionValidationSceneCore.swift` 中还没有 `staffToPiano` 专用 fixture
- shared scene 层不会自动验证“请求显示 accessory piano 时，主 scene 仍只保留一个 `.piano`”

```swift
// NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidationSceneCore.swift
// 函数名/符号: validatePhaseZeroSideBySideInvariantsPreserveCompositionSpecificSurfacePairs() -> validateSharedSurfaceStateDefaultsFollowSurfaceRoles()
// 功能说明: 修改前 scene-core validation 在阶段 4 入口前没有 staffToPiano 专项合同。
static func validatePhaseZeroSideBySideInvariantsPreserveCompositionSpecificSurfacePairs()
    -> [ExerciseCompositionValidationIssue] {
    // ... 省略既有逻辑 ...
    return issues
}

static func validateSharedSurfaceStateDefaultsFollowSurfaceRoles()
    -> [ExerciseCompositionValidationIssue] {
    // ... 后续既有逻辑 ...
}
```

### 修改后

- 新增 `validateStaffToPianoScenePromotesMainPianoAnswerSurface()`
- 明确验证：
- `staffToPiano` raw scene 只保留 `staff` 与 `piano`
- `stacked` 下主轴尺寸保持 `fitContent + weighted(1)`
- `staff` 为 prompt-only，`piano` 为 answer-only
- `makePresentation(...)` 后 accessory piano 被压平
- `legacyPageDisplayState` 仍为 `nil`

```swift
// NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidationSceneCore.swift
// 函数名/符号: static func validateStaffToPianoScenePromotesMainPianoAnswerSurface()
// 功能说明: 修改后 scene-core validation 显式锁住 staffToPiano 的主 scene 合同，
// 包括 surface 数量、角色、布局尺寸，以及 duplicate piano 防线。
static func validateStaffToPianoScenePromotesMainPianoAnswerSurface()
    -> [ExerciseCompositionValidationIssue] {
    let fixtureName = "staff_to_piano_scene_promotes_main_piano_answer_surface"
    var issues: [ExerciseCompositionValidationIssue] = []

    let rawScene = ExerciseCompositionPolicy.makeScene(
        preferences: ExerciseLayoutPreferences(
            compositionPreset: .staffToPiano,
            layoutPreset: .stacked,
            accessoryPresentation: .docked,
            isNaturalNoteStripVisible: false,
            isPianoAccessoryVisible: true,
            isAccessoryExpanded: true
        )
    )
    let rawSurfaceIDs = rawScene.surfaceNodes.map(\.id)
    if rawSurfaceIDs.count != 2
        || Set(rawSurfaceIDs) != Set([.staff, .piano]) {
        issues.append(
            issue(
                fixtureName,
                "`staffToPiano` scene 应只保留主 `staff` 与主 `piano`，不应再把 accessory piano 混进来。"
            )
        )
    }

    // ... 省略中间未变断言 ...

    if presentation.projectedSurfaceState(for: .staff) != .promptOnly {
        issues.append(
            issue(
                fixtureName,
                "`staffToPiano` 中的 `staff` 应继续暴露 prompt-only surface state。"
            )
        )
    }
    if presentation.projectedSurfaceState(for: .piano) != .answerOnly {
        issues.append(
            issue(
                fixtureName,
                "`staffToPiano` 中的主 `piano` 应暴露 answer-only surface state。"
            )
        )
    }

    return issues
}
```

## 修改 9：新增 policy / legacy validation，锁住 `staffToPiano` 不反投影 page 的合同

### 修改前

- `ExerciseCompositionValidationExercisePolicy.swift` 还没有验证 `LegacyPageLayoutAdapter` 对 `staffToPiano` 的专门行为

```swift
// NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidationExercisePolicy.swift
// 函数名/符号: validateCompositionPolicyProjectsSupportedPresetsToExpectedScenes() -> validateLegacyCompatiblePolicyFallsBackWhenSceneExceedsPageModel()
// 功能说明: 修改前 policy validation 还没有 staffToPiano 的 legacy adapter / settings bridge 合同。
static func validateCompositionPolicyProjectsSupportedPresetsToExpectedScenes()
    -> [ExerciseCompositionValidationIssue] {
    // ... 省略既有逻辑 ...
    return issues
}

static func validateLegacyCompatiblePolicyFallsBackWhenSceneExceedsPageModel()
    -> [ExerciseCompositionValidationIssue] {
    // ... 后续既有逻辑 ...
}
```

### 修改后

- 新增 `validateStaffToPianoSkipsLegacyBackProjection()`
- 明确验证：
- normalize 后仍保留 `staffToPiano`
- accessory piano 会被压平
- `projectedPageDisplayState(...)` 直接回落 `.default`
- `reconcile(...)` 不伪造新 legacy page
- 显式请求 `makeLegacyCompatiblePresentation(...)` 时，仍回退到 `staffToFretboard + stacked`

```swift
// NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidationExercisePolicy.swift
// 函数名/符号: static func validateStaffToPianoSkipsLegacyBackProjection()
// 功能说明: 修改后 policy validation 把 staffToPiano 的 legacy 边界正式锁进回归链；
// shared scene 可以保留 staffToPiano，但 legacy page 和 settings bridge 都只能走受控 fallback。
static func validateStaffToPianoSkipsLegacyBackProjection()
    -> [ExerciseCompositionValidationIssue] {
    let fixtureName = "staff_to_piano_skips_legacy_back_projection"
    var issues: [ExerciseCompositionValidationIssue] = []

    let trainerDisplayState = TrainerDisplayState(exerciseMode: .single)
    let requestedPreferences = ExerciseLayoutPreferences(
        compositionPreset: .staffToPiano,
        layoutPreset: .stacked,
        accessoryPresentation: .docked,
        isNaturalNoteStripVisible: false,
        isPianoAccessoryVisible: true,
        isAccessoryExpanded: true
    )

    let normalizedPreferences = LegacyPageLayoutAdapter.normalizedPreferences(
        requestedPreferences,
        trainerDisplayState: trainerDisplayState
    )
    if normalizedPreferences.compositionPreset != .staffToPiano {
        issues.append(
            issue(
                fixtureName,
                "`staffToPiano` 在 legacy adapter 的 normalize 阶段不应被提前改写成 legacy preset。"
            )
        )
    }

    // ... 省略中间未变断言 ...

    let legacyCompatiblePresentation = ExerciseCompositionPolicy
        .makeLegacyCompatiblePresentation(
            from: ExerciseCompositionPolicyInput(
                trainerDisplayState: trainerDisplayState,
                fretboardTrainerState: .init(),
                fretboardDisplayState: .default,
                staffDisplayState: .default,
                pianoPanelState: PianoPanelState(isVisible: true),
                layoutPreferences: requestedPreferences
            )
        )
    if legacyCompatiblePresentation.resolvedLayoutPreferences.compositionPreset
        != .staffToFretboard
        || legacyCompatiblePresentation.resolvedLayoutPreferences.layoutPreset
        != .stacked {
        issues.append(
            issue(
                fixtureName,
                "显式请求 legacy-compatible presentation 时，`staffToPiano` 应回退到 legacy 可表达的 `staffToFretboard + stacked`。"
            )
        )
    }

    return issues
}
```

## 本次与阶段 4 计划的对应关系

- 已完成：`staffToPiano` preset
- 已完成：`pianoAnswer` surface
- 已完成：`resolvedSceneSurfaces(for:)` 支持 `(.staffPrompt, .pianoAnswer)`
- 已完成：`stacked` 下沿用 `staff.fitContent + piano.weighted(1)`
- 已完成：平台 renderer 把 `pianoAccessoryView` 去语义化为可复用 `pianoSurfaceView`
- 已完成：normalization / presentation 阶段压平 `staffToPiano` 下的 accessory piano，避免 duplicate `.piano`
- 已完成：legacy adapter 不尝试把 `staffToPiano` 反投影成新的 `PageDisplayState`
- 已完成：自动化 validation 覆盖主 scene 合同与 legacy back-projection 合同
- 未完成：`SR-1` mode 暴露、settings 隐藏/禁用、controller guard 从 `isSequenceMode` 迁移到 `usesQuarterNoteSequenceKernel`、piano 输入接答题链路，这些仍属于阶段 5

## 当前工作区状态说明

- 当前未提交改动仍然是上述 12 个 `Swift` 文件
- 新增了本记录文件：`commit_records/20260415_150641_stage4_staff_to_piano_answer_surface_promotion.md`
- 本次没有做 git 提交，也没有改动计划 `.md` 文件
