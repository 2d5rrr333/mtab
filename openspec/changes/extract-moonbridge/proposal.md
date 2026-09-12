# Proposal: extract-moonbridge

## Why

初审驳回理由是"面向最终用户的应用，可复用生态价值不足"。mtab 架构中真正可复用的是"wasm-gc 业务核心 + 薄 JS 渲染壳"的桥协议层（单一 store、`init`/`dispatch` JSON 往返、副作用队列、js-string 加载器），mooncakes 上无同类（现有 tiye/react 等均为 vdom 路线），把它抽成独立生态包 `2d5rrr333/moonbridge` 发布，mtab 降级为其参考应用——直接补齐"对 MoonBit 开发者的广泛使用场景"这一驳回要点。

## What Changes

- 新建独立模块 `2d5rrr333/moonbridge`（新仓库 `D:\code\moonbit\moonbridge`，GitHub `2d5rrr333/moonbridge`）：
  - MoonBit 包 `bridge`：泛型 `Session[M, E, F]`（M=状态 ToJson、E=事件 FromJson、F=副作用 ToJson），封装 init 信封、dispatch 信封（含未初始化/非法事件两条错误路径，错误文案可配置）、状态持有与更新
  - 浏览器运行时 `web/moonbridge.mjs`（约 120 行）：wasm-gc 加载（js-string builtins + `_` 字符串字面量全局导入技巧）、boot、dispatch 循环、副作用处理器注册表（未注册类型 warn）
  - 自带单测 + README（架构说明 + 接入指南），发 0.1.0
- mtab 侧改造（dogfooding）：
  - `src/main/main.mbt` 改为通过 `@moonbridge.Session` 组装（保留 `mtab_init`/`mtab_dispatch` 导出名与现有错误文案"未初始化"/"无效的事件"），文件从 ~46 行缩到 ~25 行
  - `web/app.js` 的 `loadWasm`/`dispatch`/`apply`/`runEffects` 基建段改用 moonbridge.mjs 的 `bootBridge`（boot 配置：initArgs、onState、effects 处理器表），渲染函数全部保留
  - `moon.mod` 增加 dep `2d5rrr333/moonbridge`（先发布后接入）
- **BREAKING**（仅对 mtab 模块内部而言）：无——wasm 导出名、桥协议 wire format、错误文案均不变，e2e/headless 断言零修改即为验证标准

## Capabilities

### New Capabilities

（无——新模块的规格与测试随其自身仓库走，不在 mtab 的 openspec 体系内）

### Modified Capabilities

（无——5 个 capability 可观测行为不变；桥协议是 design 层契约，此变更不触碰其 wire format）

## Impact

- 新仓库 `moonbridge/`：`src/bridge/`（bridge.mbt + bridge_test.mbt）、`web/moonbridge.mjs`、`moon.mod`、README、LICENSE(Apache-2.0)、CI（moon check/test/fmt）
- mtab `moon.mod`：deps 增加 `2d5rrr333/moonbridge`；`src/main/moon.pkg` import 增加
- mtab `src/main/main.mbt`：协议组装逻辑替换为 Session 调用
- mtab `web/app.js`：基建段（loadWasm/dispatch/apply/runEffects）替换为 bootBridge，减少 ~60 行
- mtab `web/index.html`：引入 moonbridge.mjs（module script）
- 验证基线不变：`moon test` 158、`node e2e.mjs`、`node headless.cjs` 全绿 + `moon fmt`/`moon info` 干净
