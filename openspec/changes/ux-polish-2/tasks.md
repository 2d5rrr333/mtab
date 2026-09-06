# Tasks: ux-polish-2

## 1. 节气/节日徽章与科普弹窗（web/）

- [x] 1.1 `style.css`：`.clock-badge` 徽章基样式 + `.badge-festival`（暖红）/`.badge-festival.traditional`（金橙，农历传统节日）/`.badge-term`（中性半透明）三态；`app.js` 节日分类表（公历法定 → 暖红，农历传统 → 金橙）与 renderClock 元素化改造（badge 文本保持入 textContent）。验证：harness 断言三态 class 规则存在 + 既有 date-line 三态断言不回退
  - 记录：TRADITIONAL_FESTIVALS 集合驱动分类；renderClock 改为 replaceChildren 逐节点拼接（' · ' 分隔），textContent 语义与旧实现完全一致，三态既有断言直接复验通过
- [x] 1.2 `index.html` 加 `#term-modal` 骨架；`app.js` 加 `TERM_INFO` 24 条静态简介 + 点击 `.badge-term` 打开弹窗（节气名/简介/黄经序号）、Esc 与 backdrop 点击关闭。验证：harness 断言弹窗打开、内容含节气名与简介、关闭行为
  - 记录：TERM_INFO 含 {name, lon, blurb}（lon=黄经 15° 倍数）；关闭三通道（按钮/Esc/backdrop 点击），harness 覆盖按钮与 Esc 两路

## 2. 搜索动效（web/style.css）

- [x] 2.1 focus 上浮：`#search-input:focus` 加 `translateY(-1px)`，transition 列表补 transform。验证：harness 规则断言（focus 规则含 transform）
  - 记录：断言通过
- [x] 2.2 面板入场：`.search-suggest` 显现时 `suggest-in` 动画（fade + 上滑 .16s）。验证：harness 断言 animationName/规则存在
  - 记录：`:not([hidden])` 选择器 + animationName === 'suggest-in' 断言通过
- [x] 2.3 条目 hover：padding 位移 + count 强调过渡。验证：harness 规则断言
  - 记录：hover padding-left 0.8→1rem、suggest-count opacity .55→.9，断言通过

## 3. 回归与验收

- [x] 3.1 全量回归：`moon fmt --check` / `moon check` / `moon test` 103/103、e2e 45/45、headless 83+85 不回退（新增断言计入新基线）；截图刷新，任务记录给出验收结论（重点：徽章三态观感、弹窗内容正确、动画在 reduced-motion 下关停）
  - 记录：fmt-check 0、moon test 103/103、e2e 45/45、harness 扩至 93/93 + reduced-motion 95/95（+10：徽章存在/弹窗开合两路/内容三要素/传统与法定徽章 class/focus transform/suggest-in/hover 位移）；截图已刷新。验收结论：徽章三态、节气弹窗、搜索三动效全部落地且受 reduced-motion 全局关停覆盖；MoonBit 侧零改动（skip_specs 成立）；观感留人工复核
