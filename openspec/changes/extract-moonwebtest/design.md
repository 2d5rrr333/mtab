# Design: extract-moonwebtest

## Context

见 proposal.md。现有基础：`e2e.mjs`（wasm 加载 10 行样板 + check 计数器 + 内联 JSON.parse 信封消费，340 行）、`headless.cjs`（HTTP 静态服务 30 行 + Edge 固定路径启动器 50 行 + dump-dom 捕获/超时杀 + harness 页结果抽取 + 截图，167 行）。已知坑：被杀 Edge 的 profile 目录锁残留（已用每次唯一 profile 解）；`--force-prefers-reduced-motion` 双运行；CI 无浏览器（mtab 的 headless 只本地跑）。moonbridge（另一 change）提供 demoapp 的协议层。

## Goals / Non-Goals

**Goals:**
- 两库均零 npm 依赖、单文件、Node ≥20，`import`/`require` 即用
- headless 浏览器探测跨平台（env 覆盖 > 常见安装路径 > PATH 查找），Windows/Edge 首保（mtab 现状），Linux/macOS 尽力支持
- 工具自测闭环：demoapp（moonbridge 写的 counter）被两库测过，证明工具可用——这也是给复审的"生态包互相验证"证据
- mtab 迁移后断言通过数不变（e2e 62 / headless 渲染 13 + 交互 125+127）

**Non-Goals:**
- test-harness 页面内运行器（页面侧 PASS/FAIL 标记逻辑）抽库——mtab 的 test-harness.html 已工作且页面逻辑应用耦合深，只固化标记协议契约
- Chrome DevTools Protocol/CDP、多浏览器矩阵、视频录制等重特性
- Windows 以外平台的 headless CI 化（本地可跑，CI 维持 moon+node）

## Decisions

**D1：库形态选"复制友好"的单文件而非 npm 包** —— `bridge-harness.mjs`/`headless.cjs` 直接 `node/` 下可 import，用户 `npx` 不可得时整目录拷贝。理由：目标用户是 MoonBit 开发者，其工具链是 `moon` + Node 脚本，npm 分发反而引入 node_modules 管理负担；mooncakes 模块内附带 Node 工具是最贴近受众的分发位。

**D2：`check` 断言不进库、进约定** —— 断言写法保持 mtab 风格（`check(name, cond, detail)` 计数 + 末尾汇总退出码），库提供 `makeChecks()` 工厂返回 `{check, finish}`；不引入 assert 库/tap/jest 风格。理由：可预测、零依赖、输出即人读。

**D3：headless 库接口围绕"标记协议"显式化** —— `extractHarnessSummary(dom)` 返回 `{passed, failed, failLines, summaryText, ok}`；`runChromium({browser?, args, profileRoot, waitMarker='test-summary', timeoutMs})` 返回 stdout；浏览器解析顺序 env `MOONWEBTEST_BROWSER` → 平台默认候选（win: Edge/Chrome 固定路径；darwin/linux: PATH 查找）→ 报错并列出尝试过的候选。理由：mtab 之外的项目（含 moonwebtest 自测）不读 mtab 文档也能对齐契约。

**D4：`src/check` MoonBit 包站在 Json 层而非应用 Effect 枚举层** —— `parse_envelope(String) -> Envelope?`、`effect_types(Array[Json]) -> Array[String]`、`find_effect(Array[Json], String) -> Json?`。理由：Effect 枚举是应用资产（moonbridge 泛型 F），跨应用断言只能落在 wire format（Json）上；mtab 的 main 黑盒测试正需要这个层。

**D5：demoapp 是"计数器"而非 mtab 复制品** —— state `{count, step}`、事件 `inc/dec/reset/set_step`、effect `notify_error`（越界），~60 行 MoonBit + ~40 行页面。理由：最小可理解示例的教科书形态，同时覆盖 Session 全部用法（带 init 参数、错误路径、多 effect）。

**D6：发布顺序与依赖链** —— moonbridge 0.1.0 先发（extract-moonbridge 已定）→ moonwebtest（deps: moonbridge）自测全绿后发 0.1.0 → mtab 迁移。moonwebtest 的 CI 在 GitHub 上无浏览器，自测分两层：moon test + node 自 e2e（bridge-harness 驱动 demoapp.wasm）进 CI；headless 自测标 local-only 文档注明。

## Risks / Trade-offs

- [浏览器探测在新平台误判] → env 变量永远可覆盖；探测失败信息列出全部候选路径
- [mtab 迁移引入断言漂移] → 铁律：断言内容逐条保留，只换驱动方式；通过数前后对账写进任务验收
- [Node 库在 mooncakes 上的"非 MoonBit 内容"观感] → src/check 与 src/demoapp 提供实体 MoonBit 包；README 明示工具分层（moon 层断言 / Node 层 e2e / 浏览器层 headless）
- [demoapp 维护双份协议示例成本] → moonbridge README 直接链 demoapp 为 live example，不另写大例子

## Migration Plan

1. moonwebtest 建库：先 src/check + src/demoapp（moon check/test 绿）→ node/ 两库 + 自 e2e → 本地 headless 自测（Windows/Edge）→ publish 0.1.0
2. mtab e2e.mjs / headless.cjs 迁移到库调用，全量验证
3. 回滚 = revert mtab 迁移 commit；moonwebtest 独立存在不受影响

## Open Questions

（无）
