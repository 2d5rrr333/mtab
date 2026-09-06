# Proposal: group-collapse-blur

## Why

两个同型的小体量配置扩展：分组多了以后全部展开占屏过长（折叠需要记忆，bookmark-groups 设计时明确"可后补"）；壁纸过亮影响书签可读性时用户需要不换图的柔化手段（模糊度调节）。

## What Changes

- **分组折叠记忆**：分组头新增折叠/展开按钮（▾/▸）；折叠后隐藏该组网格；状态存于 `Group.collapsed`（可选字段，缺省 false），config v2 内加法兼容（旧文件/旧构建互不干扰），刷新后保持
- **壁纸模糊度调节**：设置面板新增 0–20 滑杆；模糊度存于 `Config.wallpaper_blur`（可选字段，缺省 0），reducer 越界 clamp 到 [0, 20]；作用于两个壁纸层（`filter: blur`），持久保存
- 新事件：`group_toggle_collapse {id}`、`wallpaper_blur_set {amount}`

## Capabilities

### New Capabilities

（无）

### Modified Capabilities

- `bookmark-grid`: 新增"分组折叠记忆"需求（折叠/展开/持久）
- `configuration`: 新增"壁纸模糊度调节"需求（调节/持久/越界钳制）

## Impact

- **修改文件**：`src/model/group.mbt`（collapsed 字段）、`src/model/config.mbt`（wallpaper_blur 字段）、`src/model/json_helpers.mbt`（bool/int 可选字段 helper）、`src/store/event.mbt` + `store.mbt`（两个新事件）、`web/`（折叠按钮与逻辑、设置滑杆、壁纸层 filter 应用）、`web/test-harness.html`、`e2e.mjs`
- **兼容**：两个新字段均为可选解码，config version 保持 2，旧 v2 文件与旧构建互不干扰
- **风险面**：小；壁纸 blur 与既有 crossfade/scrim 层级无冲突（filter 只作用于壁纸层）
