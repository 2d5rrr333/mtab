# Proposal: starter-presets-and-clock

## Why

首次打开页面时书签网格为空，导航页显得"空壳"，新用户还要自己一条条添加；同时时钟把秒数放在主视觉里，秒位每秒跳动干扰注意力。补上"开箱即用"的推荐书签，并让时钟回归时:分的稳重显示。

## What Changes

- **默认推荐书签**：默认配置的默认分组内置 6 条常用站点（百度、哔哩哔哩、知乎、GitHub、淘宝、网易云音乐），首次打开即可用；用户可正常编辑/删除/拖拽
- **时钟显示时:分**（**BREAKING** 对规格）：主时间从 `时:分:秒` 改为 `时:分`，秒不再显示；时间仍随本地时间自动更新（按分钟推进）
- 不改变：书签容量、导入去重、配置持久化与迁移等既有行为

## Capabilities

### New Capabilities

（无）

### Modified Capabilities

- `clock-widget`: 「公历时间显示」要求由"时、分、秒"改为"时、分"；场景同步
- `bookmark-grid`: 新增「初始推荐书签」要求——默认配置在默认分组预置一组常用站点

## Impact

- `src/model/config.mbt`：`Config::default()` 默认分组携带推荐书签；新增推荐站点常量
- `src/store/`：无需改归约（默认配置变化即可），但既有单测中依赖"默认空网格"的断言需调整
- `web/app.js`：时钟文本去掉秒；`web/index.html`、`web/test-harness.html` 占位符同步
- `e2e.mjs` / `test-harness.html`：新增推荐书签断言；测试基线先重置为空再跑既有流程
- 无 config 版本变化（默认内容变化，结构不变）
