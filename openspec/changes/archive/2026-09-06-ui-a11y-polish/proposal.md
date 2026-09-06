# Proposal: ui-a11y-polish

## Why

ui-polish 归档时明确排除的呈现项（滚动条、字体栈、favicon、`prefers-reduced-motion`）需要一轮收尾，加上遗留的 crossfade 边缘缺陷：大图（自定义上传的 1920px JPEG）在淡入结束后才完成解码，图片会"啪"地硬弹出。`prefers-reduced-motion` 是无障碍硬指标，favicon 是演示观感第一眼，这批是呈现层的最后打磨。

## What Changes

在**不改动任何 MoonBit 业务逻辑与桥协议**的前提下，对 `web/` 呈现层做收尾迭代：

- **crossfade 硬弹出修复**：`applyWallpaper` 预加载图片并等待 `decode()` 完成后再写入后备层、触发淡入；解码失败降级为立即应用（不阻塞壁纸"立即生效"）
- **滚动条美化**：全局 `::-webkit-scrollbar` 圆角半透明细条（页面级与弹窗内滚动），配 `scrollbar-width` / `scrollbar-color` 标准属性兜底
- **字体栈回退扩展**：补 macOS/Linux 中文平台链（PingFang SC、Hiragino Sans GB、Noto Sans SC、文泉驿微米黑）与 emoji 兜底族（Segoe UI Emoji 等）
- **favicon**：新增 `web/favicon.svg`（深色圆角底 + m 字母），index.html 加 `<link rel="icon">` 与 `<meta name="theme-color">`
- **`prefers-reduced-motion`**：一条全局 media query 关停全部 7 类动效（壁纸淡入、modal-pop、backdrop-fade、toast-in、卡片抬升、按钮上浮、状态色过渡）；headless 以 `--force-prefers-reduced-motion` 实跑断言

**明确排除**（维持 ui-polish 的决定）：设计令牌重构（`--vars`）、图标回退配色、布局与组件结构改动。

## Capabilities

### New Capabilities

（无——本 change 通过 `.openspec.yaml` 的 `skip_specs: true` 声明零规格增量：4 个既有 capability 的全部 SHALL 要求均为行为级，本轮仅改呈现层与渲染壳展示函数，不影响任何场景；验收标准记录于 tasks.md）

### Modified Capabilities

（无）

## Impact

- **修改文件**：`web/style.css`（滚动条、字体栈、reduced-motion）、`web/app.js`（crossfade 预加载，约 10 行）、`web/index.html`（favicon link + theme-color meta）、`web/test-harness.html`（新增断言）、`headless.cjs`（reduced-motion 实跑 + favicon 可达性检查）
- **新增文件**：`web/favicon.svg`
- **不修改**：`src/` 下任何 MoonBit 代码、桥协议、localStorage 格式、`openspec/specs/`
- **风险面**：纯前端呈现层，`moon test` 不受影响；decode 等待有失败降级路径，configuration spec 的"选择后壁纸立即生效"不受阻塞
