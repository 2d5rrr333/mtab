# Design: theme-system

## Context

style.css 约 700 行、颜色全部硬编码深色。config v2 已两次可选加法扩展（history/collapsed/blur），theme 同型。本 change 的核心风险是令牌化重构的波及面，用 replaceAll 级别的映射表保证不漏。

## Goals / Non-Goals

**Goals:** 单一令牌源；三态主题（auto 实时跟随）；既有视觉在深色下零变化（回归手段：两处颜色内容断言改为规则存在性，其余断言不变）；浅色对比度结构上成立（scrim 白纱 + 深字）。
**Non-Goals:** 用户自定义主题色、每壁纸独立主题、壁纸亮度自动适配、导出文件的主题迁移提示。

## Decisions

### D1. 令牌集（深色默认 + `[data-theme="light"]` 覆盖）

```
--text / --text-dim / --text-on-accent      文字三级
--surface / --surface-weak / --surface-hover 半透明面板三级
--accent / --accent-solid                    主操作面（active pill、搜索按钮）
--border / --divider                         描边两级
--panel / --panel-90                         模态面板 / 下拉面板
--focus-ring / --outline                     焦点环 / 键盘轮廓
--sb-thumb / --sb-thumb-hover                滚动条
--scrim-mid / --scrim-edge                   壁纸遮罩渐变两端
--badge-term-bg                              节气徽章底
```

映射规则：同值不同途（如 0.85 既作背景又作描边）统一归 `--accent`——深色下视觉不变，浅色下同值联动可接受。纯白字元件（toast/bm-ops/badge-festival）保持字面量（两主题下都落在深色底上）。

### D2. theme 字段与事件

- `Config.theme : String` 可选缺省 `"dark"`；`theme_set {theme}`：`dark|light|auto` 之外 notify_error；同值 no-op；否则写 + Save
- `applyTheme()`（renderAll 内幂等）：`auto` → `matchMedia('(prefers-color-scheme: light)')` 解析；写 `document.documentElement.dataset.theme`
- **实时跟随**：模块级一次性挂 `matchMedia(...).addEventListener('change')`，auto 态下重解析（dark/light 态忽略）

### D3. 设置 UI：三键分段选择器

`#theme-picker [data-theme-set]`，active 态高亮（复用 engine pill 视觉语言）；`syncSettingsControls` 同步 active。

### D4. 断言适配与验证

- 适配两处：`#search-input:focus` 的 boxShadow 内容断言 → 存在性断言；滚动条 thumb 的 background 内容断言 → 仅 borderRadius
- 新增：点击浅色 → `html[data-theme="light"]` + localStorage 持久 + CSSOM 存在 `[data-theme="light"]` 规则块；点击深色还原；auto → data-theme 与 matchMedia 解析一致
- 回归：109 moon test / 43 e2e / 99+101 harness 基线

## Risks / Trade-offs

- [令牌化漏网之鱼] —— 映射表逐值 replaceAll + 事后 grep 残留字面量清点
- [浅色对比度不足] —— scrim 用白纱 0.28→0.55、文字 #23252e，结构上有余量；人工过目截图
- [matchMedia 在 headless 的解析] —— 默认 light；断言按解析值写（不断言固定值）

## Migration Plan

零迁移（可选字段）。回滚 = revert（令牌化一并回滚，无数据影响）。

## Open Questions

（无）
