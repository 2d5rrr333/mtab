# Design: extract-moonbridge

## Context

见 proposal.md。现有基础：`src/main/main.mbt` 手写 `mtab_init`/`mtab_dispatch`（Ref[Store?] 持有、try/catch 全兜底、手写错误信封）、`src/store/` 的 `open`/`update`/`Response{state, effects}`（纯函数）、`web/app.js` 的 `loadWasm`（js-string builtins + `_` 全局导入）与 `apply/dispatch/runEffects` 循环。已知坑：derive(ToJson) 的 None 字段不输出——错误信封的 `"state": null` 必须手写序列化；e2e/harness 断言只看 effect type 不看文案；mooncakes 无本地 path dep（发布顺序见 Migration）。

## Goals / Non-Goals

**Goals:**
- moonbridge 0.1.0 覆盖 mtab 桥协议的全部机制：init 信封、dispatch 信封（未初始化 → `{state: null, effects: [notify_error]}`；非法事件 → 回显当前 state + notify_error）、泛型 Session
- mtab 接入后 wire format 逐字节不变（e2e 62 项零修改全绿为验收）
- JS 运行时不引依赖、单文件、ES module，任何 wasm-gc 应用可 `<script type="module">` 引入

**Non-Goals:**
- vdom/响应式渲染（与 tiye/react 路线差异化正在于此）
- effect 类型的框架内定义（F 由应用自带枚举，保持类型安全）
- init 参数泛型化（`init(stored, today)` 的参数表由应用声明，框架只接收 `(state, effects)` 结果）
- 双向通信/异步 effect 回传（当前单向 request/response 即够）

## Decisions

**D1：Session 三参泛型而非 trait 对象** —— `Session[M : ToJson, E : FromJson, F : ToJson]` 持有 `Ref[M?]` + `update : (M, E) -> (M, Array[F])` 函数值。应用侧 `let session : Session[Store, Event, Effect] = Session::make(update)`，`#export_name` 导出留在应用 main（导出名是应用资产）。备选：定义 `trait App` 让应用实现——MoonBit trait 无法携带关联类型族（M/E/F 联动），泛型参数更直白。

**D2：错误文案经 `BridgeText` 记录配置** —— `Session::make(update, ~texts=BridgeText::default())`，字段 `not_initialized` / `invalid_event`，默认中文（mtab 现文案"未初始化"/"无效的事件"原样传入，零行为变化）。库默认值取中文：主要受众与首批用例即中文应用，英文应用自传文案。

**D3：信封手写序列化** —— `{ "state": <m.to_json() 或 Json::Null>, "effects": [...to_json()] }`。derive(ToJson) 会丢弃 None 字段（已知坑），手写是 `"state": null` 的唯一可靠途径。空 effects 数组仍输出 `"effects": []`（mtab 现行为）。

**D4：dispatch 兜底语义与 mtab 现状一致** —— `try { parse + from_json + update } catch { _ => 错误信封（回显当前 state）}`：catch 覆盖 JSON 语法错与 FromJson 解码错（含未知事件 type），失败时 state 不前滚（`from_json` 失败点在 decode 阶段，不触碰 Ref）。实现时已实测：MoonBit `try/catch` 只捕获 `raise` 错误，`abort` 会直接 trap 穿透（mtab 手写桥同样如此）——在 README 与源码注释中如实注明此语义，不虚构"框架能兜底 panic"。

**D5：JS 运行时 `bootBridge(options)` 单入口** —— options：`{ wasmUrl, exports: {init, dispatch}, initArgs(), onState(state), effects: {save?(eff, ctx), ...}, onUnknownEffect? }`；返回 `{ dispatch(eventObj), dispatchRaw(s), get state, wasm }`。ctx 携带 `{ state, dispatch }` 供 save 处理器读 `state.config`。加载器照搬 app.js 的 `_` 全局技巧（js-string builtins 声明 + 逐个物化）。未知 effect 默认 `console.warn` 不抛错（前向兼容新 effect）。

**D6：仓库形态** —— 独立仓库 `2d5rrr333/moonbridge`，`src/bridge/` 单包 + `web/moonbridge.mjs` + README + CI（moon check → fmt --check → test；JS 侧无浏览器 CI，由 moonwebtest 的 headless 自测覆盖，见另一 change）。发布顺序：先 `moon publish` 0.1.0，mtab 再 `moon add`（mooncakes 无 path dep；迭代走补丁号重发）。

## Risks / Trade-offs

- [跨仓迭代靠 registry 往返，补丁节奏慢] → moonbridge 先行写足单测（Session 全路径 + 信封字节级断言）再发布；mtab 接入期发现的问题以 0.1.x 修复
- [`_` 全局导入技巧依赖工具链行为] → 运行时按 `WebAssembly.Module.imports` 实测物化，不做硬编码假设；moonbridge CI 加 moon 版本 pin
- [泛型 + trait bound 编译器边角] → 若 struct 级 bound 受限，降级为函数级 bound（MoonBit 允许）
- [mtab app.js 改造引入行为漂移] → e2e 62 项 + headless 252 断言作为不变式护栏，全部零修改通过才收

## Migration Plan

1. moonbridge 仓库建库 + 单测全绿 → `moon publish` 0.1.0
2. mtab `moon add 2d5rrr333/moonbridge`，main.mbt/app.js/index.html 三处替换，全量验证
3. 回滚 = revert mtab 接入 commit；moonbridge 独立存在不受影响

## Open Questions

（无）
