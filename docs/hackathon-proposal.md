# moonbridge / moonwebtest：MoonBit wasm 前端的两块地基（mtab 为参考应用）

**仓库**：https://github.com/2d5rrr333/moonbridge · https://github.com/2d5rrr333/moonwebtest · https://github.com/2d5rrr333/mtab（主仓库，53 个提交全在赛期内）
**发布**：mooncakes `moonbridge@0.1.0` / `moonwebtest@0.1.0` / `mtab@0.5.0`，三仓 CI 全绿

## 1. 价值与定位

痛点是写 mtab 时一个个撞出来的，不是调研出来的：moon 编出 wasm-gc 后，字符串字面量以"内容命名的全局导入"抵达 JS，要逐个物化；`derive(ToJson)` 静默丢掉 None 字段，错误信封的 `"state": null` 只能手写序列化；协议写完没法定义"改坏了没有"；浏览器层测试全是脏活——被杀的 Edge 抓着 profile 目录锁不放、dump-dom 输出会分块截断。这些坑每个走 wasm 前端路线的人都会撞。

**缺口**：mooncakes 有 vdom 路线（tiye/react 等），但"wasm 拥有全部状态、JS 只做薄壳"这条路没有任何可复用实现，测试工具链则无论哪条路线都是空白。填的是地基——没有它，"全部逻辑写进 wasm"这个故事只有愿意从零手写一切的人才讲得起。

**与 vdom 框架的差异是定位问题，不是优劣问题**：不建组件树、不做 diff，渲染分区由应用的壳自己决定（mtab 搜索框永不重绘、焦点不丢，代价是壳层手写 DOM）。换来 JS 层 ~120 行、协议边界完全可测——正因如此测试工具链才有明确的存在理由。

mtab 的角色是参考应用。初审结论我接受：应用本身不是生态价值。把里面的架构抽成库、再被第二个消费者（moonwebtest 的 demoapp）用掉，才是。mtab 以 162 单测 / 63 e2e / 256 headless 断言的规模在真实消费这两个包。

## 2. 交付范围与边界

已全部交付，不是计划：moonbridge 0.1.0——泛型 `Session[M,E,F]`（init/dispatch 信封、未初始化与解码失败两条错误路径、文案可配）+ 零依赖浏览器运行时（单测 10 + Node 冒烟 8）；moonwebtest 0.1.0——moon 层 `@check` 信封断言、Node 层 bridge-harness（`fresh()` 隔离实例）、浏览器层 headless runner（单测 11 + 自 e2e 8 + 自 headless 6）；mtab 0.5.0 双包接入，`main.mbt` 缩为 Session 组装（162 / 63 / 127+129+渲染 13，fmt·info 干净）。

明确不做：vdom/组件树（与现有生态撞车，薄壳路线的价值恰在没有它）；npm 分发（用户工具链是 moon + Node，不引入 node_modules）；框架内定义 effect 类型（F 由应用自带枚举，保持类型安全）。

## 3. 实现路径与技术理解

可选三条路：每个项目手写桥（mtab 原状，重复劳动）；包一层 vdom 框架（改变架构主张）；把已验证的实现抽成库。选第三条，但定了一条铁律：**抽取的验收标准是 mtab 的 62 项 e2e 断言零修改全绿**——wire format 逐字节不变，证明抽库没有改变任何可观测行为。次序：先发 moonbridge、mtab 接入全量回归，再发 moonwebtest、mtab 迁移复跑对账。

独到的理解，都是坑换来的：MoonBit 的 try/catch 只捕获 raise，abort 直接 trap 实例——所以 README 如实写"panic 不变成错误信封"，手写桥也是这个语义，撒谎的抽象不如没有抽象；信封序列化必须手写，derive 会在测试覆盖不到的错误路径上静默丢 `"state": null`；dump-dom 见到标记就收工会截断捕获，改成标记后 500ms 静默期才结束（mtab 三连复跑验证）；浏览器层测试标 local-only 不进 CI——CI 没有浏览器时装死比装聪明诚实。
