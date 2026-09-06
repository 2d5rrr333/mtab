# Project Agents.md Guide

This is a [MoonBit](https://docs.moonbitlang.com) project.

You can browse and install extra skills here:
<https://github.com/moonbitlang/skills>

## Project Context (mtab)

mtab 是 MoonBit 九月黑客松参赛项目：iTab 风格浏览器起始页。**架构铁律：全部业务逻辑在 MoonBit（wasm-gc，`mtab_init`/`mtab_dispatch` JSON 桥），`web/` 只做渲染壳**。开发采用 OpenSpec 规格驱动（explore → new change → proposal/specs/design/tasks → apply → validate → archive 时 sync 主 spec）。

- **当前状态**：v0.3.0，4 个 capability（clock-widget/bookmark-grid/search-box/configuration）共 31 条需求规格，10 个 change 归档于 `openspec/changes/archive/`。功能：时钟（农历/节气天文历算/节日徽章）、书签分组拖拽（Pointer Events 自实现）、搜索历史联想（trie+半衰期评分）+拼音联想（~2000 字表）、config v2（v1 自动迁移）、主题令牌化（深/浅/自动）、壁纸模糊度
- **验证基线**：`moon test` 122 / `node e2e.mjs` 46 / `node headless.cjs`（Edge 双运行）106+106 与 108+108 断言、渲染检查 13；改完必须全绿 + `moon fmt`/`moon info` 干净
- **本地工具链** 0.1.20260827（moonc v0.10.11）；CI 装 latest、无 fmt 门禁（moonbit 官方分发跨平台不稳定，勿恢复 pin）
- **已知坑（务必遵守）**：① 永不用 PowerShell 字符串操作改源文件（编码灾难×2），只用 edit/write 工具；② `derive(ToJson)` 序列化 snake_case 且 None 字段不输出，手写 ToJson 键名自定义——JS/e2e 断言先核对实际键名；③ CSS 简写属性含 var() 在 CSSOM 序列化为空，断言用 longhand 或 cssText，样式写 longhand；④ e2e/harness 中 config_import 会整体替换 config，测试段前后要保存/恢复；⑤ harness 里合成 PointerEvent 可完整驱动拖拽；⑥ build.ps1 已处理 PS5.1 stderr 陷阱
- **提交/推送**：`git -c user.name=2d5rrr333 -c user.email=2d5rrr333@users.noreply.github.com commit`；push 直连 `git -c http.proxy= -c https.proxy= push origin master`（失败再走代理）
- 用户偏好：重要决策先确认，其余连续执行

## Project Structure

- MoonBit packages are organized per directory; each directory contains a
  `moon.pkg` file listing its dependencies. Each package has its files and
  blackbox test files (ending in `_test.mbt`) and whitebox test files (ending in
  `_wbtest.mbt`).

- In the toplevel directory, there is a `moon.mod` file listing module
  metadata.

## Coding convention

- MoonBit code is organized in block style, each block is separated by `///|`,
  the order of each block is irrelevant. In some refactorings, you can process
  block by block independently.

- Try to keep deprecated blocks in file called `deprecated.mbt` in each
  directory.

## Tooling

- `moon fmt` is used to format your code properly.

- `moon ide` provides project navigation helpers like `peek-def`, `outline`, and
  `find-references`. See $moonbit-agent-guide for details.

- `moon info` is used to update the generated interface of the package, each
  package has a generated interface file `.mbti`, it is a brief formal
  description of the package. If nothing in `.mbti` changes, this means your
  change does not bring the visible changes to the external package users, it is
  typically a safe refactoring.

- In the last step, run `moon info && moon fmt` to update the interface and
  format the code. Check the diffs of `.mbti` file to see if the changes are
  expected.

- Run `moon test` to check tests pass. MoonBit supports snapshot testing; when
  changes affect outputs, run `moon test --update` to refresh snapshots.

- Prefer `assert_eq` or `assert_true(pattern is Pattern(...))` for results that
  are stable or very unlikely to change. For snapshot tests that record
  structured debugging output, derive `Debug` and use `debug_inspect`, rather
  than deriving `Show` for debugging. For solid, well-defined results (e.g.
  scientific computations), prefer assertion tests. You can use
  `moon coverage analyze > uncovered.log` to see which parts of your code are
  not covered by tests.
