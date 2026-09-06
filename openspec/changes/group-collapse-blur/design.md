# Design: group-collapse-blur

## Context

config v2（groups 嵌套 + wallpaper）已稳定。两个扩展均为可选字段加法：`Group.collapsed : Bool`（缺省 false）、`Config.wallpaper_blur : Int`（缺省 0）——旧 v2 文件读入取默认、旧构建忽略新字段，version 不动。

## Goals / Non-Goals

**Goals:** 折叠/模糊全部决策在 MoonBit（toggle 归约、clamp）；UI 只发事件与渲染。
**Non-Goals:** 折叠动画、记忆"部分展开"、每壁纸独立模糊度、模糊区域选择。

## Decisions

### D1. Group.collapsed 可选字段

- ToJson 恒写 `"collapsed"`；FromJson 缺省 false（新 `bool_field_opt` helper）
- `group_toggle_collapse {id}`：存在则翻转 collapsed + Save；不存在 notify_error（与分组家族一致）；**g0 也可折叠**（无保护必要）
- 既有 Group 构造点（make_default_group、测试 helper）补 `collapsed: false`

### D2. Config.wallpaper_blur 可选字段

- ToJson 恒写；FromJson 缺省 0（`int_field_opt`）
- `wallpaper_blur_set {amount}`：clamp [0,20]；值未变化时 no-op（不 Save）；变化则写 + Save
- 应用：`renderAll` 后幂等设置两个 `.wallpaper-layer` 的 `style.filter = blur(Npx)`（N=0 时移除 filter，避免无谓合成层）

### D3. UI

- 折叠按钮：组头最左固定宽度的 ▾/▸（`.bm-group-toggle`），不与拖拽柄/操作按钮冲突；`.bm-group.collapsed` 下 `.bm-grid` 与 `.bm-group-empty` display:none
- 滑杆：设置面板壁纸区 `<input type="range" min=0 max=20>` + 当前值显示；change 即 dispatch
- harness：合成点击折叠按钮断言网格隐藏 + localStorage collapsed=true；滑杆设值断言壁纸层 filter 与持久化

## Risks / Trade-offs

- [旧 v2 文件混读] —— 缺省值路径有单测锚定
- [blur filter 与 crossfade 层叠] —— filter 仅作用于壁纸层元素，scrim/内容层不受影响；性能为纯 GPU 合成，20px 上限可控

## Migration Plan

零迁移（可选字段）。回滚 = revert。

## Open Questions

（无）
