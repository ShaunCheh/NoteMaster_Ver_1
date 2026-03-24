20260324_150346_staff_scene_provider_coregraphics_import_fix

# StaffSceneProvider `CoreGraphics` 导入修复记录

## 本次变更范围

- 修改 `NoteMaster_Ver_1/Shared/Staff/StaffSceneProvider.swift`
- 未修改其他 `Staff` 几何、场景、渲染器或平台包装文件

## 修改前

### 修改前文件里直接访问了 `geometry.drawingRect.isNull`，但当前文件没有显式导入 `CoreGraphics`

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Staff/StaffSceneProvider.swift
// 函数名：makeScene(geometry:)
// 功能说明：修改前 `makeScene(geometry:)` 会读取 `CGRect.isNull`，但文件没有 `import CoreGraphics`，在当前编译环境下会报缺少定义模块的错误。
//
//  StaffSceneProvider.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/24.
//

// provider 只负责把共享状态投影成语义场景，不处理字体度量和绘制细节。
struct StaffSceneProvider: Equatable, Sendable {
    var clef: StaffClef
    var glyphTintColor: StaffSceneColor

    init(
        clef: StaffClef = .treble,
        glyphTintColor: StaffSceneColor = .primaryInk
    ) {
        self.clef = clef
        self.glyphTintColor = glyphTintColor
    }

    func makeScene(geometry: StaffGeometry) -> StaffScene {
        guard !geometry.drawingRect.isNull else {
            return .empty
        }

        let glyphs = [
            StaffGlyphItem(
                symbolID: symbolID(for: clef),
                placement: .anchor(geometry.clefAnchor(for: clef)),
                tintColor: glyphTintColor,
                renderHint: .staffClef
            )
        ]

        return StaffScene(
            lineSegments: geometry.staffLineSegments,
            glyphs: glyphs
        )
    }
}
```

## 修改后

### 修改后在文件顶部显式补上 `import CoreGraphics`，使 `CGRect.isNull` 的访问在当前文件内可见

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Staff/StaffSceneProvider.swift
// 函数名：makeScene(geometry:)
// 功能说明：修改后通过显式导入 `CoreGraphics`，修复 `geometry.drawingRect.isNull` 在当前文件中的模块可见性问题。
//
//  StaffSceneProvider.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/24.
//

import CoreGraphics

// provider 只负责把共享状态投影成语义场景，不处理字体度量和绘制细节。
struct StaffSceneProvider: Equatable, Sendable {
    var clef: StaffClef
    var glyphTintColor: StaffSceneColor

    init(
        clef: StaffClef = .treble,
        glyphTintColor: StaffSceneColor = .primaryInk
    ) {
        self.clef = clef
        self.glyphTintColor = glyphTintColor
    }

    func makeScene(geometry: StaffGeometry) -> StaffScene {
        guard !geometry.drawingRect.isNull else {
            return .empty
        }

        let glyphs = [
            StaffGlyphItem(
                symbolID: symbolID(for: clef),
                placement: .anchor(geometry.clefAnchor(for: clef)),
                tintColor: glyphTintColor,
                renderHint: .staffClef
            )
        ]

        return StaffScene(
            lineSegments: geometry.staffLineSegments,
            glyphs: glyphs
        )
    }
}
```

## 结果与影响

- 修复了 `StaffSceneProvider.swift` 中 `Property 'isNull' is not available due to missing import of defining module 'CoreGraphics'` 的编译问题。
- 这次修改只影响文件级模块导入，不改变 `StaffSceneProvider` 的行为、数据流或对外接口。
- `makeScene(geometry:)` 的场景生成逻辑保持不变，仍然只负责把共享状态投影成 `StaffScene`。

## 验证情况

- `ReadLints` 检查 `NoteMaster_Ver_1/Shared/Staff/StaffSceneProvider.swift` 后，没有新增诊断。
- 使用 `swiftc -typecheck` 对以下文件进行了静态类型检查，并已通过：
  - `NoteMaster_Ver_1/Shared/Staff/StaffCanvasOrientation.swift`
  - `NoteMaster_Ver_1/Shared/Staff/StaffConfiguration.swift`
  - `NoteMaster_Ver_1/Shared/Staff/StaffScene.swift`
  - `NoteMaster_Ver_1/Shared/Staff/StaffGeometry.swift`
  - `NoteMaster_Ver_1/Shared/Staff/StaffSceneProvider.swift`
