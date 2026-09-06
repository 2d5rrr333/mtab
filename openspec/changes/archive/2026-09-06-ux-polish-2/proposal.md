# Proposal: ux-polish-2

## Why

三个已交付功能的呈现层收尾：节气/节日目前只是日期行里的裸文本（缺乏视觉辨识度），搜索联想面板是硬切出现（无过渡），历史条目 hover 反馈弱。同时给节气加一个轻量科普入口，强化中式历法的差异化观感。全部为纯呈现层打磨，MoonBit 业务逻辑零改动。

## What Changes

在**不改动任何 MoonBit 业务逻辑**的前提下，对 `web/` 呈现层做一轮打磨：

- **节气/节日徽章**：日期行中的节气/节日改为圆角徽章样式；节日徽章用暖色强调（春节/除夕/国庆等加红色系高亮），节气徽章用中性半透明——一眼区分"今天过节"与"今天节气"
- **节气科普弹窗**：点击节气徽章弹出小卡片，展示该节气的名称与简介（24 条静态文案，渲染壳侧数据，无状态变更）
- **搜索聚焦动画**：输入框 focus 态在既有高亮基础上加轻微上浮 + 光环扩散过渡
- **联想面板过渡**：下拉出现时 fade + 上滑入场动画（与 toast/modal 同族曲线），关闭保持立即（无退场动画，与既有 modal 行为一致）
- **历史条目 hover**：联想条目 hover 增加轻微内边距位移 + 次数徽标强调的过渡反馈
- 全部动效自动受既有 `prefers-reduced-motion` 全局关停覆盖

**明确排除**（后续迭代）：分组折叠记忆（B 包）、壁纸模糊度（B 包）、设计令牌/主题系统（C 包）、拼音联想（独立立项）。

## Capabilities

### New Capabilities

（无——本 change 通过 `.openspec.yaml` 的 `skip_specs: true` 声明零规格增量：clock-widget 的"节气/节日显示"需求只约束文本呈现存在性（已满足），徽章/弹窗是呈现形式增强；search-box 联想需求的行为语义不变。验收标准记录于 tasks.md）

### Modified Capabilities

（无）

## Impact

- **修改文件**：`web/index.html`（节气弹窗容器）、`web/style.css`（徽章/动画/hover）、`web/app.js`（date-line 改为元素构建以承载徽章 + 弹窗渲染与点击，~40 行）、`web/test-harness.html`（新增断言）
- **不修改**：`src/` 任何 MoonBit 代码、桥协议、事件、config、localStorage 格式
- **风险面**：纯呈现层，`moon test` 不受影响；date-line 从 textContent 改为元素构建需保持既有 harness 断言的 `textContent` 兼容（徽章文本仍在 textContent 内）
