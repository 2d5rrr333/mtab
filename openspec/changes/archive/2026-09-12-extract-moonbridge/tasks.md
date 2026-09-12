# Tasks: extract-moonbridge

## 1. moonbridge 仓库（D:\code\moonbit\moonbridge）

- [x] 1.1 建库脚手架：moon.mod（name=2d5rrr333/moonbridge, version=0.1.0, license=Apache-2.0, keywords=[wasm, bridge, frontend, elm-architecture, json]）、src/bridge/moon.pkg（依赖 moonbitlang/core）、LICENSE、.gitignore、README 骨架，验证：`moon check` 通过
- [x] 1.2 实现 `BridgeText`（not_initialized/invalid_event 文案记录 + 中文默认）与手写信封序列化 `envelope_json(state : M?, effects : Array[F])`（None → `"state": null`，空数组 → `"effects": []`），验证：单测断言序列化（null 键显式存在/空数组/带 effect 三态，含 `\"state\":null` 子串级断言）
- [x] 1.3 实现 `Session[M : ToJson, E : FromJson, F : ToJson]`：`Session::make(update, ~texts?)`、`session.init(state, effects) -> String`（存 Ref + 返回信封）、`session.dispatch(event : String) -> String`（未初始化错误信封 / parse+from_json+update / catch-all 回显当前 state 的错误信封），验证：单测 10 项全绿（init/正常 dispatch/未初始化/非 JSON/未知事件/自定义文案/状态前滚等；abort trap 语义已实测并记入文档，非信封路径）
- [x] 1.4 编写 `web/moonbridge.mjs`：`bootBridge(options)`（js-string builtins 加载 + `_` 全局物化 + init/dispatch 循环 + effects 处理器注册表 + 未知 effect warn），验证：`node --check` 通过 + `scripts/smoke.mjs` 驱动 src/demo 计数器 wasm 8 项断言全绿（附带产出：src/demo 包 + 冒烟脚本进 CI）
- [x] 1.5 README：架构图（wasm 唯一决策点）、快速接入指南（MoonBit 侧 Session + JS 侧 bootBridge）、与 vdom 框架的路线差异说明、线协议错误路径语义表，验证：文档自查无遗留 TODO
- [x] 1.6 CI（.github/workflows/ci.yml：moon check → moon test → build demo → node scripts/smoke.mjs）+ git init + 首个 commit（338de8e），验证：本地 `moon test` 10 全绿、`moon fmt`/`moon info` 干净
- [x] 1.7 `moon publish` 0.1.0，验证：mooncakes.io API 200，模块可访问

## 2. mtab 接入（本仓库）

- [x] 2.1 `moon add 2d5rrr333/moonbridge`，src/main/moon.pkg import 增加，验证：`moon check` 通过（注：注册表索引克隆遇失效代理，用 no_proxy=mooncakes.io 直连解决，全局 git 配置未动）
- [x] 2.2 重写 `src/main/main.mbt`：`session : @bridge.Session[Store, Event, Effect]` + `update_adapter`（store 的 Response 结构 → Session 的元组）+ `mtab_init`/`mtab_dispatch` 薄导出（texts 传 mtab 现文案），验证：`moon test` 158 全绿、main 包 `.mbti` 无 diff（仅 wasm 导出函数，接口面不变）
- [x] 2.3 `web/vendor/moonbridge.mjs` vendored，`web/app.js` 删除 loadWasm/dispatch/apply/runEffects 基建段改用 bootBridge（save 处理器读 ctx.state.config，open_url/notify_error/toast 处理器照搬，效果执行顺序 effects→render 与原 apply 一致），验证：`node headless.cjs` 全绿（含 127+129 断言；修复：静态服务补 .mjs MIME 映射，否则模块导入被浏览器拦截）
- [x] 2.4 全量基线：`moon test` 158 + `node e2e.mjs` 62 项零修改全绿（wire format 未变的证明）+ `node headless.cjs` 双运行（127/129）+ `moon fmt`/`moon info` 干净

## 3. 文档与收尾

- [x] 3.1 mtab README：开头与架构段注明桥协议层来自 `2d5rrr333/moonbridge`（生态位反转叙事：mtab 是参考应用）、项目结构补 vendor；moon.mod version → 0.5.0
- [x] 3.2 openspec validate extract-moonbridge 通过；归档（2026-09-12，随复审材料整体交付）
