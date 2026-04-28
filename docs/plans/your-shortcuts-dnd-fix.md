# Your Shortcuts 拖拽修复方案

## Context

PR #239（commit 6a21631，2026-04-27）刚刚把 `Your Shortcuts` 的拖拽重排从原来的 `.draggable` + `.dropDestination` 改成了「grip 把手 + 自定义 `DragGesture` + 行 frame 映射」的方案，原因是系统级的 drop-target 在自定义 `ScrollView` 内不会触发。改完之后用户反馈：**还是基本拖不动**。

目标：定位「为什么仍然几乎拖不动」，对照 Apple 官方文档与最佳实践，制定一个最小改动、能稳定工作的修复方案，同时保留 PR #239 引入的「filter / import 预览下禁用重排」「按可见列表映射」等正确行为。

关键文件位置:
- `Sources/Wink/UI/ShortcutsTabView.swift:494-558`（GeometryReader / ScrollView / LazyVStack / 行 frame 读取）
- `Sources/Wink/UI/ShortcutsTabView.swift:529-585`（`reorderableRow` / `completeReorderDrag` / `ShortcutReorderPlanner`）
- `Sources/Wink/UI/ShortcutsTabView.swift:823-840`（`gripHandle` 的 `DragGesture` 绑定）
- `Sources/Wink/Services/ShortcutEditorState.swift:168-196`（`reorderShortcut(draggedID:toVisibleOffset:visibleShortcutIDs:)`）
- `Tests/WinkTests/ShortcutEditorStateTests.swift:177-246`（既有 reorder 测试 + planner 单测）
- `build/validation/settings-dnd-titlebar-2026-04-27/RESULTS.md`（PR #239 的 Computer Use DnD 报告）

父级布局：`SettingsView.swift:60` 是 `NavigationSplitView` + `GeometryReader`，detail 区域**没有**外层 `ScrollView`，所以唯一与 DragGesture 竞争的是 `ShortcutsTabView` 内部的本地 `ScrollView`。

## 根因分析（三因叠加）

### Root Cause 1（主因）— `DragGesture` vs `ScrollView` 的 pan 手势冲突

`gripHandle` 用的是 `.gesture(DragGesture(minimumDistance: 3))`，而把手位于一个 SwiftUI `ScrollView` 之内。SwiftUI 的 `ScrollView` 自身持有竖直 pan 识别器，竖向拖动时两者**抢同一个手势**。`.gesture(...)` 优先级与父 ScrollView 的 pan 大体并列：
- 鼠标稍快下拽：ScrollView 直接接管 → 整个列表滚动 → DragGesture 永远不进入 `onChanged` → 表现就是「拖不动」
- 鼠标特别慢、且垂直分量极小：偶尔 DragGesture 抢到 → 表现就是「偶尔能拖一下」

这是 SwiftUI 自定义 ScrollView 列表里**最经典的「拖不动」场景**（参考 Apple 文档与 swiftui-lab、hackingwithswift 论坛）。修复要点：把 `.gesture(...)` 换成 `.simultaneousGesture(...)`（让 DragGesture 与 ScrollView 的 pan 同时识别），或在拖拽期间禁用本地 ScrollView 的滚动（`.scrollDisabled(...)`）。

### Root Cause 2 — 命中区域只有 12pt，且没有 hover 反馈

`ShortcutRowMetrics.gripColumnWidth = 12`，icon 实际是 11pt。即便加了 `.contentShape(Rectangle())`，整个把手的可点击宽度也只有 12pt 左右。这远小于 macOS 推荐的 ~24pt 抓手区，并且没有 `NSCursor.openHand` 之类的视觉反馈，用户根本不知道哪 12pt 是抓手 → 加上 RC1 的滑出概率极高，体验进一步劣化为「几乎拖不到」。

### Root Cause 3 — `DragGesture` 坐标空间反馈环

当前实现：

```swift
DragGesture(minimumDistance: 3)               // 默认 .local
    .onChanged { value in
        draggingShortcutID = shortcut.id
        dragTranslationY = value.translation.height
    }
```

行视图被 `.offset(y: draggingShortcutID == shortcut.id ? dragTranslationY : 0)` 跟随光标移动。`DragGesture` 默认坐标空间是 `.local`（手势所在视图自身），当行随 offset 移动时，"local 系" 也跟着位移 → 下一帧的 `value.translation.height` 包含被自身移动量污染的反馈 → 拖动出现「滞涩、抽搐、自动跳回」的迹象，进一步降低用户「能拖动」的感知。

`ShortcutRowFramePreferenceKey` 已经存了行在 `.named(ShortcutListCoordinateSpace.name)` 命名坐标空间下的 frame，但 `DragGesture` 没用上同一个坐标空间，是个明显遗漏。

## Apple 官方文档 / 最佳实践对照

来源（皆已读过）：
- [`draggable(_:)`](https://developer.apple.com/documentation/swiftui/view/draggable(_:))
- [`dropDestination(for:action:)`](https://developer.apple.com/documentation/swiftui/view/dropdestination(for:action:istargeted:))
- [`onMove(perform:)`](https://developer.apple.com/documentation/swiftui/dynamicviewcontent/onmove(perform:))
- swiftui-lab、hackingwithswift、nilcoalescing 上的 macOS list 重排实战帖
- PR #239 自身的 RESULTS.md

要点：
1. **List 内部首选 `List + ForEach.onMove`**。但 Wink 这套自绘行（交替底色、自绘分隔线、accessoryGroup 列宽固定）切到 `List` 会大改样式，并且 PR #239 的「本地 scroller 把宽度收住」也得重做。**不推荐为这次回归切到 `List`**。
2. **自定义容器内首选 `.draggable` + `.dropDestination`** + `Transferable`。但 PR #239 已经实测过：在 `GeometryReader { ScrollView { LazyVStack } }` 容器里 `dropDestination` 不触发。**回到这条路径不可行**。
3. **走自定义 `DragGesture` 时，Apple/社区一致建议**：
   - 用 `.simultaneousGesture` 而非 `.gesture`，避免与父 ScrollView pan 冲突
   - 给 `DragGesture` 显式传命名坐标空间
   - 抓手要够大（≥24pt），并配合 `.onHover` 切 `NSCursor.openHand` / `.closedHand`
   - 拖动时禁掉所在 ScrollView 的滚动，或在边缘做 auto-scroll
   - 必要时在拖动开始之后用 `moveDisabled(...)` 暂时屏蔽其它行的交互手势

PR #239 的实现里第 3 条只勉强落了「contentShape」，其它三条全都缺，所以表现为「基本拖不动」。

## 修复方案（推荐）

保持 PR #239 的整体架构（grip 把手 + DragGesture + frame 映射 + planner），按以下三处最小改动落地。覆盖三条根因，不动 `ShortcutEditorState` 与既有测试。

### 改动 1 — `ShortcutsTabView.swift:823-840` `gripHandle` 重写

```swift
@ViewBuilder
private var gripHandle: some View {
    let icon = WinkIcon.grip.image(size: 12, weight: .semibold)
        .foregroundStyle(palette.textTertiary)
        .frame(width: ShortcutRowMetrics.gripColumnWidth, height: 24)
        .contentShape(Rectangle())
        .help("Drag to reorder")
        .onHover { hovering in
            if hovering { NSCursor.openHand.push() } else { NSCursor.pop() }
        }

    if let reorderHandlers {
        icon.simultaneousGesture(
            DragGesture(
                minimumDistance: 2,
                coordinateSpace: .named(ShortcutListCoordinateSpace.name)
            )
            .onChanged(reorderHandlers.onChanged)
            .onEnded(reorderHandlers.onEnded)
        )
    } else {
        icon
    }
}
```

并把 `ShortcutRowMetrics.gripColumnWidth` 从 `12` 调到 `24`（行 `Sources/Wink/UI/ShortcutsTabView.swift:7`），icon 大小同步从 11pt 调到 12pt。回归 RC2、RC3。

### 改动 2 — 拖动期间锁住本地 ScrollView 的滚动

`Sources/Wink/UI/ShortcutsTabView.swift:495` 的 `ScrollView` 后面追加：

```swift
.scrollDisabled(draggingShortcutID != nil)
```

这样 RC1 在「拖拽真正开始之后」彻底消失：用户一旦越过 2pt minimumDistance 进入拖拽态，ScrollView 不再竞争 pan。开始之前 `.simultaneousGesture` 已经保证 DragGesture 能并行识别，所以拖动不会被吃掉。

### 改动 3 — `completeReorderDrag` 增加守门

`Sources/Wink/UI/ShortcutsTabView.swift:561-576`：当 `value.translation.height` 极小（例如 `< 4pt`）时直接 return，不调 `editor.reorderShortcut(...)`。避免「点一下把手」也走重排路径。`ShortcutReorderPlanner` 现有逻辑没考虑 zero-translation，建议加：

```swift
private func completeReorderDrag(shortcutID: UUID, translationY: CGFloat) {
    defer {
        draggingShortcutID = nil
        dragTranslationY = 0
    }
    guard abs(translationY) >= 4 else { return }
    guard let offset = visibleDropOffset(for: shortcutID, translationY: translationY) else {
        return
    }
    editor.reorderShortcut(
        draggedID: shortcutID,
        toVisibleOffset: offset,
        visibleShortcutIDs: filteredShortcuts.map(\.id)
    )
}
```

### 不做的事
- **不切 `List + onMove`**：样式回归代价过大，且与 PR #239「local scroller 限宽」目标冲突。
- **不重建 `.draggable` + `.dropDestination`**：PR #239 已实测在该容器层级失效。
- **不引入 auto-scroll near edge**：先让基础拖拽稳定，再单独发 issue 做。
- **不动 `ShortcutEditorState.reorderShortcut(...)`**：planner 与 persist 都已有测试覆盖，逻辑没问题。

### 备选方案（仅用于场景 A 三处改动落地后仍不稳）
- 把 `simultaneousGesture` 升级为 `highPriorityGesture`：彻底压住 ScrollView pan，但代价是 ScrollView 滚动需要点行其它区域才能触发，体验稍差，因此放在备选。
- 切换到 `List` + `onMove(perform:)`，但需要重做交替底色、分隔线、accessoryGroup 宽度对齐。这条留给后续重构 issue。

## 文件改动清单

- 修改 `Sources/Wink/UI/ShortcutsTabView.swift`
  - 行 7：`gripColumnWidth: 12 → 24`
  - 行 495 区域：`ScrollView { ... }.scrollDisabled(draggingShortcutID != nil)`
  - 行 561-576：`completeReorderDrag` 增加 `abs(translationY) >= 4` 守门
  - 行 823-840：`gripHandle` 改用 `.simultaneousGesture`、命名坐标空间、`NSCursor.openHand` hover
- 新增/扩展 `Tests/WinkTests/ShortcutEditorStateTests.swift`（可选）
  - 在 `ShortcutReorderPlanner` 单测里补一条 `translationY = 0` 时返回 `nil` 的回归

## 验证清单

1. **单测** — `swift test --filter ShortcutEditorStateTests` 全绿（已有 `reorderingShortcutToVisibleDropOffsetPersistsOrder` 与 planner 单测）。
2. **完整测试** — `swift test` 全绿，特别是 `LayoutRegressionTests`。
3. **打包** — `./scripts/package-app.sh` + `codesign --verify --deep --strict --verbose=2 build/Wink.app`。
4. **runtime 手测**（参考 `docs/validation.md` 与 PR #239 RESULTS.md 模式）：
   - 设置中至少 5 条 shortcut，鼠标 hover 把手列：光标变 `openHand`
   - 从把手抓住第 1 行竖直拖到第 3 行下方：行随光标平滑跟随、拖动期间列表不再被卷动、放手后顺序持久化到 `~/Library/Application Support/Wink/shortcuts.json`
   - 在 filter 输入框打字：把手不再可拖（`canReorder = false`），无残影
   - 启动 import 预览：把手不可拖
   - 在 Computer Use 下复测一遍 PR #239 的「Ghostty → Finder 之后」场景
5. **截图归档** — 输出到 `build/validation/your-shortcuts-dnd-fix-<date>/screenshots/`，参照 PR #239 的命名。

## 备注

- 用户偏好：plan 文件最终也应放到项目目录（如 `docs/plans/`）。本次受 plan 模式限制只能写到 `~/.claude/plans/`，进入实施阶段后第一步就是把本文件复制 / 移动到 `docs/plans/your-shortcuts-dnd-fix.md`。
- Wink 处于早期阶段：直接改这三处即可，不需要兼容旧路径或加 deprecation shim。
