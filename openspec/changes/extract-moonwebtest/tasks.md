# Tasks: extract-moonwebtest

## 1. moonwebtest 仓库（D:\code\moonbit\moonwebtest）

- [ ] 1.1 建库脚手架：moon.mod（name=2d5rrr333/moonwebtest, version=0.1.0, deps=[2d5rrr333/moonbridge]）、src/check/、src/demoapp/、node/、LICENSE、.gitignore、README 骨架，验证：`moon check` 通过
- [ ] 1.2 `src/check`：`Envelope{state : Json?, effects : Array[Json]}`、`parse_envelope`、`effect_types`、`find_effect`，验证：单测覆盖合法信封/缺字段/非 JSON/null state 三态
- [ ] 1.3 `src/demoapp`：counter 桥应用（Session 组装、init 参数、inc/dec/reset/set_step 事件、越界 notify_error），验证：`moon test` 覆盖归约与错误路径
- [ ] 1.4 `node/bridge-harness.mjs`：`loadBridge(wasmPath, {init, dispatch})` → `{init, dispatch, fresh}`（信封自动 JSON.parse）+ `makeChecks()`（check 计数 + finish 汇总退出码），验证：自 e2e 脚本驱动 demoapp.wasm 全绿（含 fresh 实例隔离断言）
- [ ] 1.5 `node/headless.cjs`：`serveStatic(root, port)`、`detectBrowser()`（env → win 常见路径 → PATH）、`runChromium({browser, url, args, profileRoot, waitMarker, timeoutMs})`、`extractHarnessSummary(dom)`、`screenshot()`，验证：自 headless 脚本对 demoapp 页面跑通（本地 Edge），标记协议抽取正确
- [ ] 1.6 自测套件编排：`node self-e2e.mjs`（进 CI）+ `node self-headless.cjs`（local-only，README 注明），验证：两者全绿
- [ ] 1.7 README：三层测试策略说明（moon test @check / bridge-harness / headless）、demoapp 使用向导、标记协议契约、浏览器探测配置，验证：文档自查无遗留 TODO
- [ ] 1.8 CI（moon check → fmt --check → test → node self-e2e.mjs）+ git init + 首个 commit，验证：本地全绿 + `moon fmt`/`moon info` 干净
- [ ] 1.9 `moon publish` 0.1.0，验证：mooncakes.io/docs/2d5rrr333/moonwebtest 可访问

## 2. mtab 迁移（本仓库）

- [ ] 2.1 `e2e.mjs`：替换 wasm 加载为 `loadBridge('web/wasm/main.wasm', {init:'mtab_init', dispatch:'mtab_dispatch'})`，全部 62 项断言逐条保留，验证：`node e2e.mjs` 输出与迁移前逐项一致（对账通过数）
- [ ] 2.2 `headless.cjs`：服务/启动/抽取改用 headless 库，渲染检查 13 项 + 双运行断言保留，验证：`node headless.cjs` 通过数与迁移前一致（125+127）
- [ ] 2.3 `src/main/main_test.mbt`（黑盒）：用 `@moonwebtest.check` 直测 mtab wasm 导出——未初始化 dispatch → `"state": null` + notify_error；合法事件 → 信封形状，验证：`moon test` 新增项全绿
- [ ] 2.4 全量基线：`moon test` + `node e2e.mjs` + `node headless.cjs` + `moon fmt`/`moon info` 干净；moon.mod version → 0.5.0

## 3. 文档与收尾

- [ ] 3.1 mtab README：测试段注明工具来自 `2d5rrr333/moonwebtest`（三层策略图）；AGENTS.md 验证基线条目同步
- [ ] 3.2 openspec validate extract-moonwebtest 通过；与 extract-moonbridge 一并归档（复审材料交付前）
