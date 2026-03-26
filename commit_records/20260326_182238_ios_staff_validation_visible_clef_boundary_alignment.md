# 20260326_182238_ios_staff_validation_visible_clef_boundary_alignment

- 时间戳来源：系统命令 `date +%Y%m%d_%H%M%S`，结果为 `20260326_182238`
- 记录范围：`iOS` 平台 `StaffValidation` 在 clef 可见边界修复后的误报对齐
- 本次目标：修复 `StaffValidationRunner.runAndReportIfNeeded(platform: .iOS)` 在 DEBUG 下对正确布局结果的误判，保持验证语义与最新几何真相源一致
- 根因结论：上一轮已经把 `clef -> key signature` 的内容起点从 `geometry.clefAreaRect.maxX` 改成了 `geometry.clefVisibleMaxX(for:)`，这会让 note/调号在几何上更贴近 clef 的实际可见边界。但 `StaffValidation.validateNoteheadLayout(...)` 仍然沿用旧规则 `frame.minX > geometry.clefAreaRect.maxX`。于是 iOS 侧真实字体度量生效后，notehead 合理地进入 `clefAreaRect` 的空白预留区，却没有侵入 clef 实际字形；旧验证仍把它误判成失败，并在 `assertionFailure(summary)` 处触发崩溃
- 本次实际改动：
- 修改 `NoteMaster_Ver_1/Shared/Staff/StaffValidation.swift`

## 本次完成的修改

1. `validateNoteheadLayout(...)` 的 notehead 左边界检查，从 `geometry.clefAreaRect.maxX` 改成了 `geometry.clefVisibleMaxX(for: fixture.configuration.clef) + tolerance`。
2. 验证报错文案同步从“侵入 clefAreaRect”更新为“侵入 clef 可见边界”，让错误语义与当前共享层几何模型一致。
3. 保持布局实现不变，本次只修验证语义，不回退上一轮已经完成的 clef 间距根因修复。

## 修改 1：旧验证仍然按整块 `clefAreaRect` 判定 notehead 越界

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffValidation.swift
// 函数/成员: StaffValidationRunner.validateNoteheadLayout(scene:geometry:fixture:record:)
// 功能说明: 修改前 notehead 的左边界验证仍然绑定 clefAreaRect.maxX；
// 这会把 clef 预留区里的空白部分也当成“不可进入区域”，与最新的 clef 可见边界语义不一致。
static func validateNoteheadLayout(
    scene: StaffScene,
    geometry: StaffGeometry,
    fixture: StaffValidationFixture,
    record: (String) -> Void
) {
    let noteheadGlyphs = scene.glyphs.filter(\.symbolID.isNotehead)
    let noteheadFrames = noteheadGlyphs.compactMap { frame(of: $0) }

    for (noteIndex, frame) in noteheadFrames.enumerated() {
        if frame.width <= 0 || frame.height <= 0 {
            record("notehead[\(noteIndex)] 尺寸非法。")
            continue
        }

        if frame.minX <= geometry.clefAreaRect.maxX {
            record("notehead[\(noteIndex)] 侵入 clefAreaRect。")
        }

        if !contains(point: CGPoint(x: frame.midX, y: frame.midY), in: fixture.bounds) {
            record("notehead[\(noteIndex)] 的中心点超出 fixture bounds。")
        }
    }
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffValidation.swift
// 函数/成员: StaffValidationRunner.validateNoteheadLayout(scene:geometry:fixture:record:)
// 功能说明: 修改后 notehead 左边界验证改为基于 clef 实际可见右边界；
// 只要 notehead 没有侵入 clef 可见字形，就允许它进入 clefAreaRect 的空白预留区。
static func validateNoteheadLayout(
    scene: StaffScene,
    geometry: StaffGeometry,
    fixture: StaffValidationFixture,
    record: (String) -> Void
) {
    let noteheadGlyphs = scene.glyphs.filter(\.symbolID.isNotehead)
    let noteheadFrames = noteheadGlyphs.compactMap { frame(of: $0) }

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
    }
}
```

## 这次修复与上一轮根因修复的关系

- 上一轮修的是布局根因：把 `clef -> key signature` 的起点从“整块 clef 预留区右边界”改成“clef 实际可见右边界”。
- 这一次修的是验证根因：把 `StaffValidation` 的 notehead 越界判定也同步切到“clef 实际可见右边界”。
- 两次修改的关系是“布局真相源更新后，验证语义同步对齐”，不是推翻上一轮布局修复。

## 本次明确未修改的边界

- 未修改 `NoteMaster_Ver_1/Shared/Staff/StaffGeometry.swift`
- 未修改 `NoteMaster_Ver_1/Shared/Staff/StaffSceneBuilder.swift`
- 未修改 `NoteMaster_Ver_1/Shared/Staff/StaffClefLayoutGuide.swift`
- 未修改 `NoteMaster_Ver_1/Shared/Staff/CoreTextMusicGlyphRenderer.swift`
- 未修改任何平台控制器或视图

## 验证结果

### 静态检查

- `ReadLints` 检查 `NoteMaster_Ver_1/Shared/Staff/StaffValidation.swift`，结果为无错误

### 类型检查

```bash
# 执行位置: /Users/shaun/Library/Mobile Documents/com~apple~CloudDocs/Develop/NoteMaster_Ver_1
# 命令说明: 共享层 Swift 类型检查，确认验证语义对齐没有引入新的编译问题。
xcrun swiftc -typecheck \
  NoteMaster_Ver_1/Shared/Fretboard/*.swift \
  NoteMaster_Ver_1/Shared/Staff/*.swift \
  NoteMaster_Ver_1/Shared/Controls/*.swift
```

- 结果：通过

### 命令行验证

```bash
# 执行位置: /Users/shaun/Library/Mobile Documents/com~apple~CloudDocs/Develop/NoteMaster_Ver_1
# 命令说明: 编译并执行 StaffValidationRunner.run(platform: .commandLine)，确认本次只修验证误报，不影响既有 53 个共享层回归夹具。
xcrun swiftc -o /tmp/staff_validation_ios_fix_check \
  NoteMaster_Ver_1/Shared/Fretboard/NotePitch.swift \
  NoteMaster_Ver_1/Shared/Staff/*.swift \
  /tmp/staff_phase2_check.swift && \
/tmp/staff_validation_ios_fix_check
```

- 结果：`[StaffValidation][commandLine] automated=PASS fixtures=53`
- 结论：本次修改后，`StaffValidation` 的 notehead 越界语义已经与 clef 可见边界对齐；命名调号 decode、major circle-of-fifths、G/A/Bb accidental context、以及上一轮 clef 间距修复的共享层回归均保持通过
