# Design: ui-polish

## Context

MVP 已交付并通过四层验证（见 mvp-navigation-page）。当前呈现层为骨架级（design D5 分区重绘、半透明卡片 + 毛玻璃方向已定），本 change 只动 `web/` 的 CSS/HTML 与渲染壳 JS 的最小配合，MoonBit 与桥协议零改动。评估结论与建议清单见会话记录（P0/P1/P2 分级），用户已确认范围。

## Goals / Non-Goals

**Goals:**

- 修复三个可感知缺陷：时钟数字抖动、焦点态缺失、浅色壁纸可读性
- 交付用户点名的一组交互/动效反馈（hover 过渡、搜索微动、弹窗入场、空状态投放框、网格响应式）
- 壁纸切换 crossfade，替代硬切
- Toast 语义化（成功/错误可区分）
- 全部改动可通过 headless harness 自动断言（computed style 层面）

**Non-Goals:**

- 滚动条美化、字体栈扩展、`prefers-reduced-motion`、favicon、设计令牌（`--vars`）重构、图标回退配色（用户明确排除，留后续迭代）
- 布局重排、组件结构重构、任何视觉以外的行为变化

## Decisions

### D1. 范围解读与记录的假设

"全部P0项"按此前评估的 P0 清单执行（时钟等宽、焦点态、遮罩、Toast 双态），加上用户点名的交互项（hover 过渡、搜索微动、弹窗动画+毛玻璃、空状态虚线框、网格响应式）与壁纸 crossfade；P2 项全部排除。

**记录的假设**："只修改 web 目录下 css/html" 的边界按"不改动 MoonBit 业务逻辑"理解——crossfade 与 Toast 双态需要 `app.js`（渲染壳）各一处最小改动（约 15 行 + 5 行），仍属 web 前端层；若严格禁止 app.js 改动，crossfade 在技术上无法实现（`background-image` 不可过渡）。

### D2. 时钟稳定：`font-variant-numeric: tabular-nums`

等宽数字让每位数字占宽一致，秒跳动不再引起整行抖动；同时 `font-weight` 200 → 300（Windows 雅笔 Light 下 200 渲染发虚）。备选（否决）：改用等宽字体家族——观感损失大。

### D3. 可读性遮罩：`body::before` 固定 vignette 层

`radial-gradient` 暗化遮罩置于壁纸之上、内容之下（`z-index: 0`，`pointer-events: none`），`#app`/`.toolbar`/`.toast` 提到 `z-index: 1`。比逐元素加 text-shadow 可靠，浅色壁纸下同样成立。模态 backdrop（z-index 10）与 toast（20）不受影响。

### D4. 壁纸 crossfade：双 fixed 层 + opacity 过渡

`background-image` 不可过渡，采用两个固定定位层元素（`#wallpaper-a`/`#wallpaper-b`，或 body 伪元素）叠放于遮罩之下：

1. JS 维护"当前层/后备层"引用
2. `applyWallpaper()` 时把新图写入后备层 → 后备层 opacity 0→1 过渡（~400ms）→ 交换引用
3. CSS 只负责 `transition: opacity .4s ease` 与 `background: center/cover`

`applyWallpaper` 是渲染壳内纯展示函数，改动约 15 行；桥协议、状态、localStorage 均不变。备选（否决）：Canvas 绘制/解码后淡入——复杂度高收益低。

### D5. Toast 双态：`toast(message, type)`

`type: 'error' | 'success'`，映射 `.toast` / `.toast.success` 两个视觉态（红 / 绿），统一加入场动画（fade + 上滑）。现有全部 `toast(...)` 调用点按语义标注：保存失败/无效网址/导入失败/无效文件 → error；导出成功 → success。默认 error，避免遗漏。

### D6. 交互反馈统一曲线与时长

- hover：`transition: background .15s ease, transform .18s cubic-bezier(.2,.8,.3,1.2)`（书签卡片抬升 -3px + 阴影加深，active 回落）
- 搜索按钮：hover `translateY(-1px)`、active 回落
- 弹窗：backdrop `backdrop-filter: blur(4px)` + fade；`.modal` pop（translateY+scale，220ms，轻微过冲曲线）
- 空状态：`1.5px dashed` 边框 + 更浅底色，表达"可投放"
- 顺带删除无效选择器 `.modal-actions button secondary`

### D7. 网格响应式：`min(880px, 94vw)` + `minmax(104px, 1fr)`

880px 上限容纳 7 列，窄屏自然回落到更少列；卡片内边距与图标尺寸不变。书签卡片 hover 抬升归入 D6 的"hover 过渡"范围。

## Risks / Trade-offs

- [多层 backdrop-filter/blur 叠加导致低端机卡顿] → blur 仅用于弹窗 backdrop 一处（搜索框已有 blur 保持不变）；动画只用 opacity/transform（合成层属性）
- [crossfade 层遮挡交互] → 两层均 `pointer-events: none` 且 z-index 低于内容层
- [headless 无法断言"观感"只能断言样式] → harness 用 `getComputedStyle` 断言关键属性（transition/animation/font-variant-numeric/遮罩层存在性）+ 时钟宽度稳定性测量 + 截图留档供人工过目
- [Toast 语义标注遗漏] → 默认 error 兜底，grep 复查全部调用点
- [遮罩层加深整体偏暗] → vignette 中心 0.16 起步，视觉复核可调

## Migration Plan

纯前端改动：`build.ps1` 不涉及（wasm 不变）；改完刷新页面即生效。回滚 = revert 三个 web 文件。

## Open Questions

（无）
