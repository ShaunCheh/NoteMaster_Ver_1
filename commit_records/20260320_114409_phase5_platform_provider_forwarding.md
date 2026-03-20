20260320_114409_phase5_platform_provider_forwarding

# 阶段 5 修改记录

## 本次变更范围

- 修改 `NoteMaster_Ver_1/Platform/iOS/iOSFretboardView.swift`
- 修改 `NoteMaster_Ver_1/Platform/macOS/macOSFretboardView.swift`
- 未修改 `FretboardLayer.swift`
- 未修改 `FretboardContentProvider.swift`
- 未修改 `NoteNameContentProvider.swift`
- 未修改 `iOSViewController.swift`
- 未修改 `macOSViewController.swift`

## 修改前

### iOS 包装视图只透传 `configuration`

```swift
// 文件路径：NoteMaster_Ver_1/Platform/iOS/iOSFretboardView.swift
// 函数名：configuration, applyConfiguration()
// 功能说明：修改前 iOS 包装视图只负责把 configuration 传给 FretboardLayer，还没有 contentProvider 这一层的透传能力。
final class iOSFretboardView: UIView {
    var configuration: FretboardConfiguration {
        didSet {
            guard oldValue != configuration else {
                return
            }

            applyConfiguration()
        }
    }

    private func applyConfiguration() {
        fretboardLayer.configuration = configuration
        updateContentsScale()
        invalidateIntrinsicContentSize()
    }
}
```

### macOS 包装视图只透传 `configuration`

```swift
// 文件路径：NoteMaster_Ver_1/Platform/macOS/macOSFretboardView.swift
// 函数名：configuration, applyConfiguration()
// 功能说明：修改前 macOS 包装视图也只负责把 configuration 传给 FretboardLayer，还没有 contentProvider 的同步入口。
final class macOSFretboardView: NSView {
    var configuration: FretboardConfiguration {
        didSet {
            guard oldValue != configuration else {
                return
            }

            applyConfiguration()
        }
    }

    private func applyConfiguration() {
        fretboardLayer.configuration = configuration
        updateContentsScale()
        invalidateIntrinsicContentSize()
    }
}
```

## 修改后

### iOS 包装视图新增 provider 透传

```swift
// 文件路径：NoteMaster_Ver_1/Platform/iOS/iOSFretboardView.swift
// 函数名：contentProvider, applyConfiguration()
// 功能说明：iOS 包装视图新增 contentProvider 属性，并在 didSet 和 applyConfiguration() 中把它同步给共享 FretboardLayer。
final class iOSFretboardView: UIView {
    var configuration: FretboardConfiguration {
        didSet {
            guard oldValue != configuration else {
                return
            }

            applyConfiguration()
        }
    }

    var contentProvider: (any FretboardContentProviding)? {
        didSet {
            fretboardLayer.contentProvider = contentProvider
        }
    }

    private func applyConfiguration() {
        fretboardLayer.configuration = configuration
        fretboardLayer.contentProvider = contentProvider
        updateContentsScale()
        invalidateIntrinsicContentSize()
    }
}
```

### macOS 包装视图新增 provider 透传

```swift
// 文件路径：NoteMaster_Ver_1/Platform/macOS/macOSFretboardView.swift
// 函数名：contentProvider, applyConfiguration()
// 功能说明：macOS 包装视图同样新增 contentProvider 属性，并在 didSet 和 applyConfiguration() 中把它同步给共享 FretboardLayer。
final class macOSFretboardView: NSView {
    var configuration: FretboardConfiguration {
        didSet {
            guard oldValue != configuration else {
                return
            }

            applyConfiguration()
        }
    }

    var contentProvider: (any FretboardContentProviding)? {
        didSet {
            fretboardLayer.contentProvider = contentProvider
        }
    }

    private func applyConfiguration() {
        fretboardLayer.configuration = configuration
        fretboardLayer.contentProvider = contentProvider
        updateContentsScale()
        invalidateIntrinsicContentSize()
    }
}
```

### 平台包装层职责变化

```swift
// 文件路径：NoteMaster_Ver_1/Platform/iOS/iOSFretboardView.swift, NoteMaster_Ver_1/Platform/macOS/macOSFretboardView.swift
// 函数名：contentProvider, applyConfiguration()
// 功能说明：阶段 5 后，平台包装视图不参与音名推导，只增加 provider 透传职责，保持“平台层极薄、共享层负责逻辑”的边界。
var contentProvider: (any FretboardContentProviding)? {
    didSet {
        fretboardLayer.contentProvider = contentProvider
    }
}

private func applyConfiguration() {
    fretboardLayer.configuration = configuration
    fretboardLayer.contentProvider = contentProvider
    updateContentsScale()
    invalidateIntrinsicContentSize()
}
```

## 结果说明

- 阶段 5 的核心结果是让 iOS 和 macOS 的包装视图都具备了 `contentProvider` 透传能力。
- 平台包装层继续保持极薄：既不参与音名计算，也不参与 marker 绘制，只做 configuration 和 provider 的下发。
- 这样下一阶段控制器只需要持有一个 `NoteNameContentProvider` 并赋值给包装视图，就能把音名显示完整接通。
- 本次没有修改 `FretboardLayer`、provider 本身或控制器逻辑。
