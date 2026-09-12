# moonbridge / moonwebtest：MoonBit wasm 前端的两块地基（mtab 为参考应用）

**仓库**：https://github.com/2d5rrr333/moonbridge · https://github.com/2d5rrr333/moonwebtest · https://github.com/2d5rrr333/mtab（主仓库，50+ 提交全部在赛期内）
**发布**：mooncakes `moonbridge@0.1.0` / `moonwebtest@0.1.0` / `mtab@0.5.0`，三仓 CI 全绿

## 1. 价值与生态定位

痛点是写 mtab 时一个个撞出来的，不是调研出来的：moon 编出 wasm-gc 后，字符串字面量以「内容命名的全局导入」抵达 JS，要逐个物化；`derive(ToJson)` 静默丢掉 None 字段，错误信封里的 `"state": null` 只能手写序列化；协议写完，"改没改坏"没法定义；浏览器层测试全是脏活——被杀的 Edge 攥着 profile 目录锁不放，dump-dom 输出还会分块截断。走 wasm 前端路线的人迟早撞上这些。

缺口是逐个实查过 mooncakes 的：vdom 路线已有包（tiye/react 等），但「wasm 拥有全部状态、JS 只做薄壳」这条路没有任何可复用实现，测试工具链则哪条路线都是空白。也评估过把 lunar/pinyin/trie 抽成库——tyme4mb、walkzzz/pinyin 已存在且更全，不重复造。真正缺的是架构层和测试层，而这是地基：没有它，「全部逻辑写进 wasm」只有愿意从零手写一切的项目讲得起。

与 vdom 框架的差别是定位不同，不是优劣：不建组件树、不做 diff，渲染分区由应用的壳自己决定（mtab 搜索框永不重绘、焦点不丢，代价是手写 DOM），换来 JS 层约 120 行、协议边界完全可测——也正因协议可测，配套的测试工具链才有存在的理由。

mtab 的角色是参考应用。初审结论我认：应用本身不是生态价值；把里面的架构抽成库、再被第二个消费者（moonwebtest 的 demoapp）用掉，才是。mtab 以 162 单测 / 63 e2e / 256 headless 断言的规模真实消费这两个包。

## 2. 交付范围与工程边界

已全部交付，不是计划——两个包的抽取、发布、接入回归在 9/12 单日闭环（git 历史可查）：

- **moonbridge 0.1.0**：泛型 `Session[M,E,F]`（init/dispatch 信封、未初始化与解码失败两条错误路径、文案可配）+ 零依赖浏览器运行时。moon 单测 10 + Node 冒烟 8。
- **moonwebtest 0.1.0**：三层测试链——moon 层 `@check` 信封断言、Node 层 bridge-harness（`fresh()` 隔离实例）、浏览器层 headless runner。moon 单测 11 + 自 e2e 8 + 自 headless 6，工具测自己的 demoapp。
- **mtab 0.5.0 双包接入**：`main.mbt` 缩为 Session 组装；e2e/headless 驱动器换成 moonwebtest（断言逐条保留，63 与 127+129 与迁移前一致）；新增 moon 层协议黑盒 4 项。全量基线 162 / 63 / 127+129+渲染 13，fmt·info 干净。

明确不做：vdom/组件树（与现有生态撞车，薄壳路线的价值恰在没有它）；npm 分发（目标用户工具链是 moon + Node 脚本）；框架内定义 effect 类型（F 由应用自带枚举，保持类型安全）。

## 3. 实现路径与技术理解

三条路：每个项目手写桥（mtab 原状，重复劳动）；包一层 vdom 框架（等于放弃自己的架构主张）；把已验证的实现抽成库。选第三条，并立了一条铁律：**抽取的验收标准是 mtab 的 62 项 e2e 断言零修改全绿**——wire format 逐字节不变，抽库没有改变任何可观测行为。次序同理：先发 moonbridge、mtab 接入并全量回归，再发 moonwebtest、mtab 迁移后逐项对账。

独到的理解都是坑换来的：MoonBit 的 try/catch 只捕获 raise，abort 直接 trap 实例，所以 README 如实写明 panic 不变成错误信封——撒谎的抽象不如没有抽象；mooncakes 没有 path 依赖，跨仓迭代只能发版往返，所以先写足协议单测再发布；新装的工具链不带注册表索引，CI 首跑必须先 `moon update`，moonwebtest 的 CI 首跑就栽在这；dump-dom 见到标记就收工会截断捕获，改成标记后等 500ms 静默期（mtab 三连复跑验证）；浏览器层测试标 local-only 不进 CI——CI 没有浏览器时，装死比装聪明诚实。
