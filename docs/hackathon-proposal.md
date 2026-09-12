# mtab 生态项目申报书（复审版）

## 基本信息

- 项目名称：mtab 生态——moonbridge 前端桥协议包 + moonwebtest 测试工具链包 + mtab 参考应用
- 主仓库：https://github.com/2d5rrr333/mtab（51 个有效提交，全部在本赛期内）
- 生态包仓库：https://github.com/2d5rrr333/moonbridge、https://github.com/2d5rrr333/moonwebtest
- mooncakes 发布：`2d5rrr333/moonbridge@0.1.0`、`2d5rrr333/moonwebtest@0.1.0`、`2d5rrr333/mtab@0.5.0`（三个模块均可 `moon add` 直接使用）
- 项目性质：原创；农历换算算法移植自 solarlunar 3.1.0（MIT，修改点已在 README 与源码注明）；moonbridge/moonwebtest 全部原创，零第三方依赖

## 痛点与生态定位（回应初审反馈）

初审反馈指出：项目"偏向面向最终用户的应用，可复用生态价值不足"。复审版本把项目重定位为**面向 MoonBit 开发者的前端基建**，用 mooncakes 实测数据说明两个包各填一个生态空白：

1. **moonbridge（前端架构空白）**：想用 wasm-gc 后端写浏览器前端的 MoonBit 开发者，第一件事不是写 UI，而是回答"状态放哪、事件怎么进 wasm、副作用怎么出来"。mooncakes 上 vdom 路线已有包（tiye/react 等），但**"wasm 业务核心 + JSON 桥 + 薄 DOM 壳"路线没有任何可复用实现**——每个项目都要手写一遍协议。moonbridge 把这条路收敛为一个泛型 `Session[M,E,F]`（init/dispatch 信封、双错误路径、错误文案可配）+ 一个 120 行零依赖浏览器运行时（js-string 加载、dispatch 循环、副作用注册表），`moon add` 即用。
2. **moonwebtest（测试工具链空白）**：写完 wasm 之后怎么测？mooncakes 上没有 wasm Web 应用的测试工具。moonwebtest 提供与该架构配套的三层答案：moon 层 `@check` 包断言 wire format、Node 层 `bridge-harness` 驱动真实 wasm 实例（fresh() 隔离实例）、浏览器层 headless runner（Chromium 系浏览器探测 + dump-DOM 标记协议）。工具自证：其内置 demo 应用由自己的两层工具测试。

**任何**想写浏览器前端的 MoonBit 开发者——工具页、仪表盘、游戏 UI、编辑器——都是这两个包的直接用户；这正是"对 MoonBit 开发者的广泛使用场景"。

mtab 的角色随之改变：**从申报主角降级为参考应用（dogfooding 证明）**。它以 162 单测 / 63 e2e / 256 headless 断言的规模真实消费这两个包，证明包不是"配 demo 的玩具库"。

## 已有基础（初审前完成并验证）

时钟（公历/农历含闰月干支/24 节气天文历算/节日徽章）、书签分组与 Pointer Events 拖拽、Netscape 书签导入（纯 MoonBit 容错解析器）、多引擎搜索（trie + 半衰期评分 + 拼音联想）、倒数日小组件、config v1→v2 迁移、深浅主题令牌、壁纸模糊度；OpenSpec 规格驱动（5 capability 39 需求、13 变更档案）。

## 初审反馈后补充（9/12 → 9/24 的复核材料）

1. **`2d5rrr333/moonbridge@0.1.0` 已发布**（独立仓库）：泛型 Session 桥协议 + 浏览器运行时。质量基线：moon 单测 10 项（信封序列化 null 语义、Session 五条路径、错误文案）+ Node 冒烟 8 项（驱动内置 demo wasm）+ CI（check/test/build/smoke）。关键设计：`"state": null` 手写信封（规避 derive(ToJson) 丢 None 字段的坑）、abort trap 语义如实文档化。
2. **`2d5rrr333/moonwebtest@0.1.0` 已发布**（独立仓库）：三层测试工具链。质量基线：moon 单测 11 项（check 包五态 + demoapp 黑盒 6 项，后者即 check 的 dogfooding）+ 自 e2e 8 项（含未初始化路径——moon 层全局 session 测不到的路径）+ 自 headless 6 项（浏览器层，本地）+ CI（moon + Node 两层）。附带修复 dump-dom 分块竞态（标记防抖）。
3. **mtab v0.5.0 双包接入**：`main.mbt` 缩为 Session 组装（协议机制全部来自 moonbridge）；e2e/headless 驱动器换为 moonwebtest 工具（断言逐条保留，通过数 63 与 127+129 与迁移前一致——wire format 不变的证明）；新增 moon 层协议黑盒测试 4 项。全量基线：`moon test` 162 / e2e 63 / headless 127+129+渲染 13 / `moon fmt`/`moon info` 干净。
4. **包间互证**：moonwebtest 的 CI 用 Node harness 测 moonbridge 写的 demoapp（moonbridge 依赖图内可见）；mtab 用两者。三个仓库各自 CI 独立，依赖方向单向（mtab → moonbridge + moonwebtest，moonwebtest → moonbridge）。

## 实现路径（已全部落地）

架构铁律不变：单一 store 把每个事件归约为「新状态 + 副作用列表」，wasm 永远是唯一决策点。抽取采用"先证明不变、再搬实现"的次序：moonbridge 独立成库（单测覆盖协议全路径）→ 发布 → mtab 接入（e2e 断言零修改全绿作为 wire format 未变的验收）→ moonwebtest 同样先自证再迁移 mtab 测试驱动。OpenSpec 规格驱动全程：两个 change（extract-moonbridge / extract-moonwebtest）的 proposal/design/tasks 与验收记录归档于 `openspec/changes/archive/`。

明确不做：vdom/组件树（与现有生态差异化所在）、npm 分发（目标用户工具链是 moon + Node 脚本）、账号与云同步。
