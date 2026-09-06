# mtab 项目申报书

- **项目名称**：mtab — MoonBit 驱动的浏览器导航起始页
- **仓库链接**：https://github.com/2d5rrr333/mtab
- **许可证**：Apache-2.0（农历算法模块移植自 MIT 许可的 solarlunar，来源与修改已在 README 与源码注明）

## 项目现有基础

mtab 是一个 iTab 风格的浏览器起始页，当前仓库已完整可运行：

- **功能**：时钟（公历 + 农历 + 干支/星期）、书签网格（增删改、图标回退）、多引擎搜索（百度/Bing/Google）、壁纸（内置 + 本地上传压缩）、小组件开关、配置 JSON 导入导出；全部数据 localStorage 持久化、离线可用。
- **架构**：业务重量全部放在 MoonBit——单一 store（事件 → 新状态 + 副作用）、配置/书签/URL/壁纸模型与 JSON 编解码、1900–2100 农历换算均为纯 MoonBit（编译目标 wasm-gc）；JS 侧仅约 450 行渲染壳，通过 JSON 桥调用 `mtab_init` / `mtab_dispatch`，从不做 store 能做的决定。
- **测试与工程**：37 个 MoonBit 单元测试、18 项 Node e2e（真实 wasm 实例过桥）、headless Edge 双运行（正常 + 强制 reduced-motion）共 13 项渲染检查 + 63/65 项浏览器断言；GitHub Actions CI（check / fmt / test / build / e2e）；OpenSpec 规格驱动开发，4 个 capability 行为规格与逐变更档案可追溯。

## 本次计划开发或新增的内容

1. **搜索历史与前缀联想**：trie 前缀树 + 去重 + 时间衰减评分，纯 MoonBit 实现，输入时给出历史建议。
2. **书签分组与拖拽排序**：树形分组模型与 JSON 往返在 MoonBit，拖拽交互在渲染壳，排序结果持久化。
3. **节气与传统节假日**：扩展农历包补全节气计算与节日展示，融入时钟组件。

## 项目预期目标和技术路线

**目标**：交付一个真实可用、可长期维护的 MoonBit 应用级开源项目，并成为「wasm 承担业务、DOM 只做渲染」的可复制架构样板。

**技术路线**：MoonBit store / 模型层（wasm-gc）↔ JSON 消息桥 ↔ 轻渲染壳；OpenSpec 行为规格先行，单元 / e2e / headless 三层测试与 CI 全程跟进；完成后发布至 mooncakes.io（`2d5rrr333/mtab`）。

## 预计完成的功能、测试和文档

- **功能**：搜索历史联想、书签分组与拖拽排序、节气节假日展示；发布 mooncakes.io。
- **测试**：新增功能均配套单元测试与 headless 断言，`moon test` / e2e / CI 保持全绿。
- **文档**：README（架构图、快速开始）、openspec 行为规格与变更档案同步更新。

## 其他说明

- 原创应用；其中农历换算算法移植自 MIT 许可的 [solarlunar](https://github.com/yize/solarlunar) 3.1.0（修改：干支年名跟随农历年切换），来源与许可证已在 README 与源码注释中注明。
- 无第三方运行时依赖；内置壁纸为自制 SVG。
- 开发全程合理使用 AI 工具辅助（代码生成、测试补全、文档撰写），提交记录完整可追溯，作者对代码质量、内容来源与开源合规性负责。
