# Proposal: theme-system

## Why

全站颜色硬编码为单一深色方案（被两轮迭代明确排除的"设计令牌重构"），浅色偏好用户不可用。引入 CSS 自定义属性令牌体系并支持深色/浅色/跟随系统三态主题，是视觉打磨的地基——后续任何配色调整只动令牌。

## What Changes

- **设计令牌化**：style.css 全部颜色字面量收敛为 `--text/--surface/--accent/--border/--panel/--scrim/--sb-*` 等语义令牌，深色为默认值
- **三态主题**：`Config.theme : String`（`dark` | `light` | `auto`，可选字段缺省 `dark`）；`theme_set {theme}` 事件（非法值拒绝、未变化 no-op）；`auto` 经 `prefers-color-scheme` 解析并实时跟随系统切换
- **应用机制**：`<html data-theme="dark|light">` 驱动 `[data-theme="light"]` 令牌覆盖；`applyTheme` 幂等（renderAll 内）
- **设置 UI**：外观分区三键分段选择器（深色/浅色/跟随系统），即时生效并持久
- 浅色令牌含 scrim 反转（白色薄纱渐变保障深色文字可读）、面板/滚动条/焦点环全套

## Capabilities

### New Capabilities

（无）

### Modified Capabilities

- `configuration`: 新增"主题设置"需求（三态选择、立即生效、持久、跟随系统）

## Impact

- **修改文件**：`src/model/config.mbt`（theme 字段）、`src/store/event.mbt`/`store.mbt`（theme_set）、`web/style.css`（令牌化重构，改动面最大）、`web/app.js`（applyTheme + matchMedia 监听 + 设置接线）、`web/index.html`/`web/test-harness.html`（外观分区）、断言适配（两处 rgba 内容断言改为规则存在性）
- **兼容**：可选字段加法，config v2 不动
- **风险面**：令牌化波及全文件——既有 harness 的两处颜色内容断言需适配；浅色态的 scrim/对比度需人工过目
