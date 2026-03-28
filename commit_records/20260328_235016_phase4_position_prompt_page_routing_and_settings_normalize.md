# 20260328_235016_phase4_position_prompt_page_routing_and_settings_normalize

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260328_235016`
- 记录范围：实施“位置音名模式”计划的阶段 4，聚焦 iOS/macOS 控制器中的页面编排、trainer 同步与 settings normalize 收敛；不涉及按钮作答接线、错误红闪时序、正确后 1 秒推进和 macOS/iOS 的完整交互闭环
- 本次目标：让“第三训练模式 == 上指板、下自然音按钮”成为控制器与 settings 的统一不变量，并让同一个 `fretboardHostView` 能根据页面状态在 `top` / `main` 两个槽位之间切换
- 本次实际修改文件：
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`

## 根因结论

- 阶段 1 已经让 shared 层可以表达 `PageDisplayState.positionPrompt`，阶段 3 也让 shared overlay 能绘制白圈/红闪/绿停留，但控制器仍然保留着旧前提：指板只能显示在 `mainContent`
- 这个旧前提具体体现在三个地方：
- 指板可见判断仍然是 `mainContentMode == .fretboard`
- `applyTopContentMode()` 仍然只会在 `staff / targetPrompt` 间切换
- `.positionPrompt` 仍然走 `synchronizeSingleTrainerPresentation(reason:)` 的占位分支
- 如果只补 settings normalize 而不改页面路由，第三模式即使把状态面收敛到 `top=fretboard, main=naturalNoteStrip`，界面仍会继续显示旧的 top prompt / main strip 组合，控制器与页面状态会互相打架
- 因此阶段 4 的根因级修复，是把双端控制器里的“指板位置假设”升级为“指板可位于任一槽位”的通用路由，再让 trainer 同步与 settings normalize 一起围绕 `PageDisplayState.positionPrompt` 收口

## 修改 1：iOS 控制器从“主区域固定指板”升级为按页面状态分流

### 修改前

- iOS 控制器只用 `isShowingFretboardMainContent`
- `applyTopContentMode()` 只支持 `staff / targetPrompt`
- `applyMainContentMode()` 固定在 `fretboard / naturalNoteStrip` 间切换，默认认为 `fretboardHostView` 永远属于主区域
- `.positionPrompt` 仍然复用 single 占位逻辑
- settings normalize 只对 sequence 生效

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名: isShowingFretboardMainContent, applyTopContentMode(), applyMainContentMode(),
// synchronizeTrainerPresentationState(reason:), normalizeSettingsPanelStateContextForTrainerMode(_:)
// 功能说明: 修改前 iOS 控制器把“指板显示”近似成“mainContent == fretboard”；
// 这会让 top=fretboard 的页面状态无法真正落到布局和 trainer 同步。
private var isShowingFretboardMainContent: Bool {
    pageDisplayState.mainContentMode == .fretboard
}

private var isShowingStaffTopContent: Bool {
    pageDisplayState.topContentMode == .staff
}

private func applyTopContentMode() {
    let showsStaff = pageDisplayState.topContentMode == .staff
    let activeConstraints = showsStaff
        ? topContentStaffConstraints
        : topContentTargetPromptConstraints
    let inactiveConstraints = showsStaff
        ? topContentTargetPromptConstraints
        : topContentStaffConstraints

    staffView.isHidden = !showsStaff
    targetNotePromptView.isHidden = showsStaff
    NSLayoutConstraint.deactivate(inactiveConstraints)
    NSLayoutConstraint.activate(activeConstraints)
}

private func applyMainContentMode() {
    let showsFretboard = isShowingFretboardMainContent
    let activeConstraints = showsFretboard
        ? mainContentFretboardConstraints
        : mainContentNaturalNoteStripConstraints
    let inactiveConstraints = showsFretboard
        ? mainContentNaturalNoteStripConstraints
        : mainContentFretboardConstraints

    fretboardHostView.isHidden = !showsFretboard
    naturalNoteStripView.isHidden = showsFretboard
    NSLayoutConstraint.deactivate(inactiveConstraints)
    NSLayoutConstraint.activate(activeConstraints)
    rebuildVerticalFretboardHostHeightConstraint()
    updateFretboardLayoutModeConstraints()
}

private func synchronizeTrainerPresentationState(reason: String) {
    switch trainerDisplayState.exerciseMode {
    case .single:
        synchronizeSingleTrainerPresentation(reason: reason)
    case .sequence:
        synchronizeQuarterNoteSequencePresentation(reason: reason)
    case .positionPrompt:
        // Phase 1 先只打通状态面；布局与按钮判题在后续阶段接入前，
        // 暂时沿用 single 投影，避免新模式被选中后落入未定义 UI 状态。
        synchronizeSingleTrainerPresentation(reason: reason)
    }
}

private func normalizeSettingsPanelStateContextForTrainerMode(
    _ stateContext: inout SettingsPanelStateContext
) {
    guard stateContext.trainerDisplayState.isSequenceMode else {
        return
    }

    stateContext.pageDisplayState.mainContentMode = .fretboard
}
```

### 修改后

- 新增 `isShowingFretboard` / `isShowingFretboardTopContent` / `isShowingTargetPromptTopContent` / `isShowingNaturalNoteStripMainContent`
- 新增 `topContentFretboardConstraints` 与 `activeFretboardHostConstraints`
- 新增 `applyFretboardHostPlacement()`，让同一个 `fretboardHostView` 根据 `pageDisplayState` 在 `topContentHostView` 与 `mainContentHostView` 之间切换
- `applyTopContentMode()` 不再硬编码“top 只能 staff/targetPrompt”
- `applyMainContentMode()` 只负责自然音按钮条本身，指板位置路由交给 `applyFretboardHostPlacement()`
- `.positionPrompt` 新增专门同步入口 `synchronizePositionPromptPresentation(reason:)`
- settings normalize 改成对 `single / sequence / positionPrompt` 三种模式统一收敛

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名: isShowingFretboard, isShowingFretboardTopContent,
// applyFretboardHostPlacement(), applyTopContentMode(), applyMainContentMode(),
// synchronizePositionPromptPresentation(reason:),
// normalizeSettingsPanelStateContextForTrainerMode(_:)
// 功能说明: 修改后 iOS 控制器已经把“指板可能位于顶部或主区域”收敛成统一路由，
// 并让第三模式稳定落到 top=fretboard / main=naturalNoteStrip。
private var isShowingFretboard: Bool {
    pageDisplayState.showsFretboard
}

private var isShowingFretboardTopContent: Bool {
    pageDisplayState.showsFretboardInTopContent
}

private var isShowingFretboardMainContent: Bool {
    pageDisplayState.showsFretboardInMainContent
}

private var isShowingTargetPromptTopContent: Bool {
    pageDisplayState.topContentMode == .targetPrompt
}

private var isShowingNaturalNoteStripMainContent: Bool {
    pageDisplayState.mainContentMode == .naturalNoteStrip
}

private func applyPageDisplayState() {
    applyFretboardHostPlacement()
    applyTopContentMode()
    applyMainContentMode()
    applySettingsPanelState()
    updateLayoutIfNeeded()

    if isShowingFretboard {
        syncVerticalFretboardContentWidthConstraint()
        updateLayoutIfNeeded()
    }

    updateFretboardViewportPresentation()
}

private func applyFretboardHostPlacement() {
    let desiredSuperview = isShowingFretboardTopContent
        ? topContentHostView
        : mainContentHostView
    if fretboardHostView.superview !== desiredSuperview {
        NSLayoutConstraint.deactivate(activeFretboardHostConstraints)
        activeFretboardHostConstraints = []
        fretboardHostView.removeFromSuperview()
        desiredSuperview.addSubview(fretboardHostView)
        fretboardHostView.translatesAutoresizingMaskIntoConstraints = false
    }

    let desiredConstraints: [NSLayoutConstraint]
    if isShowingFretboardTopContent {
        desiredConstraints = topContentFretboardConstraints
    } else if isShowingFretboardMainContent {
        desiredConstraints = mainContentFretboardConstraints
    } else {
        desiredConstraints = []
    }

    NSLayoutConstraint.deactivate(activeFretboardHostConstraints)
    if !desiredConstraints.isEmpty {
        NSLayoutConstraint.activate(desiredConstraints)
    }
    activeFretboardHostConstraints = desiredConstraints
    fretboardHostView.isHidden = !isShowingFretboard
}

private func applyTopContentMode() {
    let activeConstraints: [NSLayoutConstraint]
    if isShowingStaffTopContent {
        activeConstraints = topContentStaffConstraints
    } else if isShowingTargetPromptTopContent {
        activeConstraints = topContentTargetPromptConstraints
    } else {
        activeConstraints = []
    }

    staffView.isHidden = !isShowingStaffTopContent
    targetNotePromptView.isHidden = !isShowingTargetPromptTopContent
    NSLayoutConstraint.deactivate(
        topContentStaffConstraints + topContentTargetPromptConstraints
    )
    if !activeConstraints.isEmpty {
        NSLayoutConstraint.activate(activeConstraints)
    }
}

private func applyMainContentMode() {
    naturalNoteStripView.isHidden = !isShowingNaturalNoteStripMainContent
    NSLayoutConstraint.deactivate(mainContentNaturalNoteStripConstraints)
    if isShowingNaturalNoteStripMainContent {
        NSLayoutConstraint.activate(mainContentNaturalNoteStripConstraints)
    }
    rebuildVerticalFretboardHostHeightConstraint()
    updateFretboardLayoutModeConstraints()
}

private func synchronizeTrainerPresentationState(reason: String) {
    switch trainerDisplayState.exerciseMode {
    case .single:
        synchronizeSingleTrainerPresentation(reason: reason)
    case .sequence:
        synchronizeQuarterNoteSequencePresentation(reason: reason)
    case .positionPrompt:
        synchronizePositionPromptPresentation(reason: reason)
    }
}

private func synchronizePositionPromptPresentation(reason: String) {
    resetSingleCoverageInteractionState()
    resetQuarterNoteSequenceInteractionState()

    if pageDisplayState != .positionPrompt {
        pageDisplayState = .positionPrompt
    }

    if staffDisplayState != baseStaffDisplayState {
        staffDisplayState = baseStaffDisplayState
    }

    if case .positionPrompt = fretboardTrainerState.mode {
        // 阶段 4 这里只先切通 mode 与页面不变量；
        // 具体 session 与按钮作答接线放到下一阶段。
    } else {
        fretboardTrainerState = FretboardNaturalNoteTrainerState(
            positionPromptMode: ()
        )
    }

    applyCurrentFretboardFeedbackOverlayState()
}

private func normalizeSettingsPanelStateContextForTrainerMode(
    _ stateContext: inout SettingsPanelStateContext
) {
    switch stateContext.trainerDisplayState.exerciseMode {
    case .single:
        if stateContext.pageDisplayState == .positionPrompt {
            stateContext.pageDisplayState.setMainContentMode(.fretboard)
        }
    case .sequence:
        stateContext.pageDisplayState.setMainContentMode(.fretboard)
    case .positionPrompt:
        stateContext.pageDisplayState = .positionPrompt
    }
}
```

## 修改 2：macOS 控制器同步建立对称的页面路由与 normalize 闭环

### 修改前

- macOS 控制器与 iOS 一样，把“指板可见”写死成 `mainContentMode == .fretboard`
- `topContent` 仍然只能是 `staff / targetPrompt`
- `.positionPrompt` 仍然走 single 占位
- `normalizeSettingsPanelStateContextForTrainerMode(_:)` 仍然只处理 sequence

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名: isShowingFretboardMainContent, applyTopContentMode(), applyMainContentMode(),
// synchronizeTrainerPresentationState(reason:), normalizeSettingsPanelStateContextForTrainerMode(_:)
// 功能说明: 修改前 macOS 控制器与 iOS 同样保留了“指板只能在主区域”的假设；
// 因此第三模式的页面状态无法真正投影到 macOS 布局层。
private var isShowingFretboardMainContent: Bool {
    pageDisplayState.mainContentMode == .fretboard
}

private var isShowingStaffTopContent: Bool {
    pageDisplayState.topContentMode == .staff
}

private func applyTopContentMode() {
    let showsStaff = pageDisplayState.topContentMode == .staff
    let activeConstraints = showsStaff
        ? topContentStaffConstraints
        : topContentTargetPromptConstraints
    let inactiveConstraints = showsStaff
        ? topContentTargetPromptConstraints
        : topContentStaffConstraints

    staffView.isHidden = !showsStaff
    targetNotePromptView.isHidden = showsStaff
    NSLayoutConstraint.deactivate(inactiveConstraints)
    NSLayoutConstraint.activate(activeConstraints)
}

private func applyMainContentMode() {
    let showsFretboard = isShowingFretboardMainContent
    let activeConstraints = showsFretboard
        ? mainContentFretboardConstraints
        : mainContentNaturalNoteStripConstraints
    let inactiveConstraints = showsFretboard
        ? mainContentNaturalNoteStripConstraints
        : mainContentFretboardConstraints

    fretboardHostView.isHidden = !showsFretboard
    naturalNoteStripView.isHidden = showsFretboard
    NSLayoutConstraint.deactivate(inactiveConstraints)
    NSLayoutConstraint.activate(activeConstraints)
    rebuildVerticalFretboardHostHeightConstraint()
    updateFretboardLayoutModeConstraints()
}

private func synchronizeTrainerPresentationState(reason: String) {
    switch trainerDisplayState.exerciseMode {
    case .single:
        synchronizeSingleTrainerPresentation(reason: reason)
    case .sequence:
        synchronizeQuarterNoteSequencePresentation(reason: reason)
    case .positionPrompt:
        // Phase 1 先只打通状态面；布局与按钮判题在后续阶段接入前，
        // 暂时沿用 single 投影，避免新模式被选中后落入未定义 UI 状态。
        synchronizeSingleTrainerPresentation(reason: reason)
    }
}

private func normalizeSettingsPanelStateContextForTrainerMode(
    _ stateContext: inout SettingsPanelStateContext
) {
    guard stateContext.trainerDisplayState.isSequenceMode else {
        return
    }

    stateContext.pageDisplayState.mainContentMode = .fretboard
}
```

### 修改后

- macOS 也新增了与 iOS 镜像的 `isShowingFretboard*` helper
- 同步新增 `topContentFretboardConstraints` 与 `activeFretboardHostConstraints`
- 同步新增 `applyFretboardHostPlacement()`
- 同步把 `.positionPrompt` 接入 `synchronizePositionPromptPresentation(reason:)`
- 同步把 settings normalize 扩展为三模式统一收敛

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名: isShowingFretboard, isShowingFretboardTopContent,
// applyFretboardHostPlacement(), applyTopContentMode(), applyMainContentMode(),
// synchronizePositionPromptPresentation(reason:),
// normalizeSettingsPanelStateContextForTrainerMode(_:)
// 功能说明: 修改后 macOS 控制器与 iOS 保持镜像结构；
// 第三模式的页面编排、trainer mode 与 settings normalize 已经在 macOS 端形成闭环。
private var isShowingFretboard: Bool {
    pageDisplayState.showsFretboard
}

private var isShowingFretboardTopContent: Bool {
    pageDisplayState.showsFretboardInTopContent
}

private var isShowingFretboardMainContent: Bool {
    pageDisplayState.showsFretboardInMainContent
}

private var isShowingTargetPromptTopContent: Bool {
    pageDisplayState.topContentMode == .targetPrompt
}

private var isShowingNaturalNoteStripMainContent: Bool {
    pageDisplayState.mainContentMode == .naturalNoteStrip
}

private func applyPageDisplayState() {
    applyFretboardHostPlacement()
    applyTopContentMode()
    applyMainContentMode()
    applySettingsPanelState()
    updateLayoutIfNeeded()

    if isShowingFretboard {
        syncVerticalFretboardContentSizeConstraints()
        updateLayoutIfNeeded()
    }

    updateFretboardViewportPresentation()
}

private func applyFretboardHostPlacement() {
    let desiredSuperview = isShowingFretboardTopContent
        ? topContentHostView
        : mainContentHostView
    if fretboardHostView.superview !== desiredSuperview {
        NSLayoutConstraint.deactivate(activeFretboardHostConstraints)
        activeFretboardHostConstraints = []
        fretboardHostView.removeFromSuperview()
        desiredSuperview.addSubview(fretboardHostView)
        fretboardHostView.translatesAutoresizingMaskIntoConstraints = false
    }

    let desiredConstraints: [NSLayoutConstraint]
    if isShowingFretboardTopContent {
        desiredConstraints = topContentFretboardConstraints
    } else if isShowingFretboardMainContent {
        desiredConstraints = mainContentFretboardConstraints
    } else {
        desiredConstraints = []
    }

    NSLayoutConstraint.deactivate(activeFretboardHostConstraints)
    if !desiredConstraints.isEmpty {
        NSLayoutConstraint.activate(desiredConstraints)
    }
    activeFretboardHostConstraints = desiredConstraints
    fretboardHostView.isHidden = !isShowingFretboard
}

private func applyTopContentMode() {
    let activeConstraints: [NSLayoutConstraint]
    if isShowingStaffTopContent {
        activeConstraints = topContentStaffConstraints
    } else if isShowingTargetPromptTopContent {
        activeConstraints = topContentTargetPromptConstraints
    } else {
        activeConstraints = []
    }

    staffView.isHidden = !isShowingStaffTopContent
    targetNotePromptView.isHidden = !isShowingTargetPromptTopContent
    NSLayoutConstraint.deactivate(
        topContentStaffConstraints + topContentTargetPromptConstraints
    )
    if !activeConstraints.isEmpty {
        NSLayoutConstraint.activate(activeConstraints)
    }
}

private func applyMainContentMode() {
    naturalNoteStripView.isHidden = !isShowingNaturalNoteStripMainContent
    NSLayoutConstraint.deactivate(mainContentNaturalNoteStripConstraints)
    if isShowingNaturalNoteStripMainContent {
        NSLayoutConstraint.activate(mainContentNaturalNoteStripConstraints)
    }
    rebuildVerticalFretboardHostHeightConstraint()
    updateFretboardLayoutModeConstraints()
}

private func synchronizeTrainerPresentationState(reason: String) {
    switch trainerDisplayState.exerciseMode {
    case .single:
        synchronizeSingleTrainerPresentation(reason: reason)
    case .sequence:
        synchronizeQuarterNoteSequencePresentation(reason: reason)
    case .positionPrompt:
        synchronizePositionPromptPresentation(reason: reason)
    }
}

private func synchronizePositionPromptPresentation(reason: String) {
    resetSingleCoverageInteractionState()
    resetQuarterNoteSequenceInteractionState()

    if pageDisplayState != .positionPrompt {
        pageDisplayState = .positionPrompt
    }

    if staffDisplayState != baseStaffDisplayState {
        staffDisplayState = baseStaffDisplayState
    }

    if case .positionPrompt = fretboardTrainerState.mode {
        // 阶段 4 先只建立 mode 与页面组合的不变量；
        // 具体 session 与按钮作答接线放到后续平台集成阶段。
    } else {
        fretboardTrainerState = FretboardNaturalNoteTrainerState(
            positionPromptMode: ()
        )
    }

    applyCurrentFretboardFeedbackOverlayState()
}

private func normalizeSettingsPanelStateContextForTrainerMode(
    _ stateContext: inout SettingsPanelStateContext
) {
    switch stateContext.trainerDisplayState.exerciseMode {
    case .single:
        if stateContext.pageDisplayState == .positionPrompt {
            stateContext.pageDisplayState.setMainContentMode(.fretboard)
        }
    case .sequence:
        stateContext.pageDisplayState.setMainContentMode(.fretboard)
    case .positionPrompt:
        stateContext.pageDisplayState = .positionPrompt
    }
}
```

## 结果说明

- iOS/macOS 双端控制器都不再把“指板显示”写死成 `mainContent == .fretboard`
- `fretboardHostView` 现在可按 `pageDisplayState` 在顶部与主区域之间切换，第三模式的“上指板、下按钮”页面组合已经能被真实布局承载
- `.positionPrompt` 不再走 single 占位分支，而是进入单独的 trainer/page 同步入口
- settings 面板中的 page state 与 trainer mode 现在会统一收敛到第三模式的不变量，不会出现模式与布局互相打架
- 本阶段仍未接入：
- iOS 的按钮作答入口与 `PositionPromptSession`
- 白圈/红闪/绿停留的控制器相位调度
- 正确后 1 秒自动推进与错误后恢复白圈
- 自然音按钮组件的事件绑定

## 验证说明

- 已对 `iOSViewController.swift` 与 `macOSViewController.swift` 运行 `ReadLints`
- 本次改动未发现新增 lint 问题
- 未运行完整 `xcodebuild`
