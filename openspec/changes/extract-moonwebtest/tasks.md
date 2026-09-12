# Tasks: extract-moonwebtest

## 1. moonwebtest 仓库（D:\code\moonbit\moonwebtest）

- [x] 1.1 建库脚手架：moon.mod（name=2d5rrr333/moonwebtest, version=0.1.0, import 2d5rrr333/moonbridge@0.1.0）、src/check/、src/demoapp/、node/、LICENSE、.gitignore、README 骨架，验证：`moon check` 通过
- [x] 1.2 `src/check`：`Envelope{state : Json?, effects : Array[Json]}`、`parse_envelope`、`effect_types`、`find_effect`，验证：单测覆盖合法信封/缺字段/非 JSON/null state/无 type 效果五态（显式 null ≠ 缺键：缺 state 键拒绝，显式 null 归 None）
- [x] 1.3 `src/demoapp`：counter 桥应用（Session 组装、init 参数、inc/dec/reset 事件、越界 notify_error），验证：`moon test` 黑盒 6 项（兼作 @check 的 dogfooding）
- [x] 1.4 `node/bridge-harness.mjs`：`loadBridge(wasmPath, {init, dispatch})` → `{init, dispatch, dispatchRaw, fresh, state}`（信封自动 JSON.parse，模块单次编译、fresh 快速隔离实例）+ `makeChecks()`（check 计数 + finish 汇总退出码），验证：自 e2e 8 项全绿（含未初始化路径与实例隔离断言）
- [x] 1.5 `node/headless.cjs`：`serveStatic(root, port)`、`detectBrowser()`（env → win 常见路径 → PATH）、`runChromium({browser, args, profileRoot, waitMarker, timeoutMs})`（唯一 profile、标记防抖早停、超时强杀）、`extractHarnessSummary(dom)`、`report()`，验证：自 headless 对 demo 页跑通（本地 Edge，6 项浏览器检查 + 截图）；附带修复 dump-dom 分块竞态（标记出现后 500ms 静默期再收工）
- [x] 1.6 自测套件编排：`node scripts/self-e2e.mjs`（进 CI，8 项）+ `node scripts/self-headless.cjs`（local-only，README 注明），验证：两者全绿
- [x] 1.7 README：三层测试策略说明（moon 层 @check / bridge-harness / headless）、demoapp 使用向导、标记协议契约、浏览器探测配置，验证：文档自查无遗留 TODO
- [x] 1.8 CI（moon check → moon test → build demo wasm → node scripts/self-e2e.mjs）+ git init + 首个 commit，验证：本地全绿 + `moon fmt`/`moon info` 干净
- [x] 1.9 `moon publish` 0.1.0，验证：mooncakes.io API 200

## 2. mtab 迁移（本仓库）

- [x] 2.1 `e2e.mjs`：替换 wasm 加载为 `loadBridge('web/wasm/main.wasm', {init:'mtab_init', dispatch:'mtab_dispatch'})`，全部 62 项断言逐条保留，另以 fresh 实例新增 1 项未初始化路径断言（63 项），验证：`node e2e.mjs` 全绿，通过数 63
- [x] 2.2 `headless.cjs`：服务/启动/抽取改用 `tools/headless.cjs`（vendored），渲染检查 13 项 + 双运行断言保留，验证：`node headless.cjs` 通过数与迁移前一致（127+129，三连稳定复跑）
- [x] 2.3 `src/main/main_test.mbt`（黑盒）：用 `@moonwebtest/check` 直测 mtab wasm 导出——未初始化 dispatch（声明序首个测试，Node e2e fresh 实例双保险）→ `"state": null` + notify_error；合法事件 → 信封形状与 save effect，验证：`moon test` 新增 4 项全绿（总数 162）
- [x] 2.4 全量基线：`moon test` 162 + `node e2e.mjs` 63 + `node headless.cjs`（127/129）+ `moon fmt`/`moon info` 干净；moon.mod version → 0.5.0（已在 extract-moonbridge 中完成）

## 3. 文档与收尾

- [x] 3.1 mtab README：测试段注明工具来自 `2d5rrr333/moonwebtest`（三层策略表）；AGENTS.md 验证基线与生态包上下文同步
- [ ] 3.2 openspec validate extract-moonwebtest 通过；与 extract-moonbridge 一并归档（复审材料交付前）
