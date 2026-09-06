# Proposal: ui-polish

## Why

MVP 按"先骨架后皮肉"交付，界面只保证了功能与可用性。作为比赛演示项目，观感直接影响评审第一印象；同时骨架层遗留了几个可感知的呈现缺陷（时钟每秒抖动、焦点态缺失、浅色壁纸下文字可读性无保障、提示语义单一），需要一次集中的呈现层打磨。

## What Changes

在 **不改动任何 MoonBit 业务逻辑** 的前提下，对 `web/` 呈现层做一轮美化：

- **时钟数字等宽**（`tabular-nums`）：消除秒跳动引起的整行宽度抖动
- **焦点态**：搜索框聚焦高亮 + 键盘导航 `focus-visible` 轮廓
- **壁纸可读性遮罩**：壁纸与内容之间加暗化 vignette 层
- **壁纸切换 crossfade**：新旧壁纸交叉淡化，替代当前硬切
- **操作反馈语义**：Toast 区分成功/错误两种视觉状态，并加入场动画
- **交互 hover 过渡**：引擎 pill、工具栏、模态按钮、书签操作按钮（删除悬停变红）、书签卡片 hover 抬升
- **搜索按钮微动**：hover 上浮 / active 回落
- **弹窗**：pop 入场动画 + 背景毛玻璃（backdrop blur）
- **空状态**：改为虚线"投放框"样式
- **书签网格响应式布局**：加宽至 880px、列宽 104px 起，自适应更多列
- 顺带清理一条无效 CSS 选择器（`.modal-actions button secondary`）

**明确排除**（后续迭代）：滚动条美化、字体栈回退扩展、`prefers-reduced-motion`、favicon、设计令牌重构、图标回退配色。

## Capabilities

### New Capabilities

（无——本 change 通过 `.openspec.yaml` 的 `skip_specs: true` 声明零规格增量：4 个既有 capability 的全部 SHALL 要求与场景均不受影响，本 change 仅改变呈现层；验收标准记录于 tasks.md）

### Modified Capabilities

（无）

## Impact

- **修改文件**：`web/style.css`（主体）、`web/app.js`（两处最小配合：toast 增加 type 参数；壁纸切换改为双层 crossfade 渲染）、`web/index.html`（如需承载遮罩/壁纸层的少量结构调整）
- **不修改**：`src/` 下任何 MoonBit 代码、桥协议、localStorage 格式、既有测试语义
- **风险面**：纯前端样式与渲染壳逻辑，`moon test` 结果不受影响；headless 验证工具需补充样式断言
