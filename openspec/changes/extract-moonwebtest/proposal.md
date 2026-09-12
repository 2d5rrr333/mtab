# Proposal: extract-moonwebtest

## Why

"wasm-gc 核心写完之后怎么测"是 MoonBit Web 开发的第二个普遍空白：Node 侧驱动 wasm 导出做 e2e、无头浏览器做 DOM/渲染断言，这两套工具 mtab 已在生产验证（e2e.mjs 62 项跨平台 + headless.cjs 252 断言 Windows/Edge 双运行），但以单文件脚本形态锁死在 mtab 仓库里，其他项目无法复用。抽成 `2d5rrr333/moonwebtest` 发布，补齐"每个 MoonBit Web 项目都要面对"的第二块生态拼图（第一块是 moonbridge）。

## What Changes

- 新建独立模块 `2d5rrr333/moonwebtest`（新仓库 `D:\code\moonbit\moonwebtest`，GitHub `2d5rrr333/moonwebtest`）：
  - `node/bridge-harness.mjs`：Node e2e 库——wasm 加载（js-string + `_` 全局）、`init(...)`/`dispatch(event)` 返回解析好的信封、`fresh()` 新实例、`check`/`finish` 断言与退出码
  - `node/headless.cjs`：无头浏览器库——静态文件服务、Chromium 启动器（浏览器探测：env `MOONWEBTEST_BROWSER` → Edge/Chrome 常见路径 → PATH）、独立 profile 目录、dump-dom 早停（`test-summary` 标记）、超时强杀、test-harness 页结果抽取（`>PASS `/`>FAIL `/`ALL N BROWSER CHECKS PASSED` 标记协议）、截图
  - `src/check/`（MoonBit 包）：桥协议 JSON 信封断言助手（`parse_envelope`/`effect_types`/`find_effect`），供应用在 `moon test` 层断言 wire format
  - `src/demoapp/`：极简 counter 桥应用（依赖 moonbridge），作为工具自测的靶子 + 用户最小示例
  - 自测：`moon test` + Node 自 e2e（harness 驱动 demoapp）+ headless 自测（demoapp 页面渲染断言）——工具测工具
  - 发 0.1.0
- mtab 侧迁移（dogfooding）：
  - `e2e.mjs` 改用 bridge-harness（保留全部 62 项应用断言，只替换加载/驱动基建）
  - `headless.cjs` 改用 headless 库（保留全部渲染检查与双运行逻辑）
  - `src/main/` 黑盒测试新增 1 组：moon 层直测 mtab wasm 导出的信封 wire format（用 @moonwebtest/check）——补上"协议行为只被 Node e2e 覆盖"的层间空隙

## Capabilities

### New Capabilities

（无——新模块规格随其自身仓库走）

### Modified Capabilities

（无——5 个 capability 可观测行为不变；此变更只动测试基建层）

## Impact

- 新仓库 `moonwebtest/`：moon.mod（deps 含 2d5rrr333/moonbridge）、`node/`、`src/check/`、`src/demoapp/`、README、CI（moon check/test + node 自 e2e）
- mtab `e2e.mjs`/`headless.cjs`：脚本瘦身，断言集不变（通过数不变为验收）
- mtab `moon.mod`：deps 增加 `2d5rrr333/moonwebtest`（为 src/check 断言用）
- 依赖顺序：依赖 extract-moonbridge 已发布（demoapp 用 moonbridge）
