# Design: ux-polish-2

## Context

solar-terms-festivals 已把 `solar_term`/`festival` 派生到 ClockView 并由 date-line 以 `·` 拼接展示；search-history 的联想面板以 `hidden` 硬切出现。本 change 只动 `web/` 呈现层，skip_specs。

## Goals / Non-Goals

**Goals:**

- 节气/节日获得视觉层级（徽章 + 节日暖色强调）
- 节气徽章可点击查看科普卡片（静态文案，无状态）
- 搜索交互三处动效补全（focus/面板入场/条目 hover）
- 既有 harness 断言语义零回退（textContent 兼容、reduced-motion 关停覆盖）

**Non-Goals:**

- 节气时刻展示、节日放假安排、科普内容的多语言
- 主题系统/设计令牌（C 包）、联想面板退场动画（与 modal 家族行为保持一致）

## Decisions

### D1. 节气/节日徽章：date-line 元素化 + 三态样式

```
date-line: [公历日期 · 星期] [<badge>节气|节日</badge> · 农历]
badge 三态：
  .badge-festival  暖红底(rgba(214,69,60,.85)) 白字 + 轻微光晕   ← 春节/除夕/国庆/元旦/劳动节
  .badge-festival.traditional 金橙底(rgba(200,140,60,.85))        ← 元宵/端午/七夕/中秋/重阳
  .badge-term      中性半透明白底 + 白字，无光晕                   ← 二十四节气
```

- renderClock 由 `textContent = parts.join(' · ')` 改为 `replaceChildren(...)` 构建节点（badge 为 `<span class="clock-badge …">`）；**badge 文本仍在父元素 textContent 中**，既有 `includes('寒露')` 断言不破
- 徽章色与 scrim/毛玻璃体系一致（半透底 + backdrop-blur 可选）；font-size 0.78rem、圆角 999px、padding 0.1em 0.6em

### D2. 节气科普弹窗：静态数据 + 复用 modal 骨架

- 数据：`TERM_INFO` 24 条 `{ name, blurb }`（每条 ≤40 字的简介），渲染壳侧常量（与 WALLPAPERS 同级，展示文案非业务逻辑）
- 交互：点击 `.badge-term` 打开 `#term-modal`（复用 modal-backdrop/modal 结构与动画）；无 dispatch、无状态——纯展示弹窗，Esc/点 backdrop 关闭由既有通用逻辑复用（新写最小 close 接线）
- 弹窗内容：节气名 + 简介 + "太阳黄经"序号（term_names 下标 ×15°，展示用）

### D3. 搜索动效三件套

- **focus**：`#search-input:focus` 既有 box-shadow 基础上加 `transform: translateY(-1px)`（transition 已含 transform？当前不含——加进 transition 列表）
- **面板入场**：`.search-suggest:not([hidden])` 加 `animation: suggest-in .16s ease`（translateY(-4px)+opacity，toast-in 同族曲线）；退场无动画（hidden 立即消失，与 modal 一致）
- **条目 hover**：`.suggest-item:hover` 加 `padding-left` 0.8→1.0rem 过渡 + `.suggest-count` opacity .55→.9
- 全部走 transform/opacity/padding 合成友好属性；reduced-motion 下由全局 kill-switch 置 0.01ms

### D4. 验证策略

- harness：徽章存在与三态 class 规则（CSSOM）、badge 文本仍入 textContent（寒露断言不回退）、term-modal 打开/内容/关闭、focus 上浮规则、suggest-in 动画规则、条目 hover 过渡规则
- 回归：103 moon test / 45 e2e / 83+85 harness 基线不回退

## Risks / Trade-offs

- [date-line 元素化破坏既有断言] —— badge 文本保持在 textContent；`date line shows 寒露` 等三态断言直接复验
- [科普文案准确性] —— 24 条 blurb 按通行历法常识撰写，不涉及争议表述；错误属文案级，热修即可
- [动画与 reduced-motion] —— 全部用 animation/transition，已被全局 kill-switch 覆盖，无需单独处理

## Migration Plan

纯 web/ 改动，刷新生效；回滚 = revert 三个文件。

## Open Questions

（无）
