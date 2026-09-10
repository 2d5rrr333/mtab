# Tasks: starter-presets-and-clock

## 1. 模型（src/model/）

- [x] 1.1 `config.mbt` 增加 `starter_bookmarks()`（6 条常用站点，id b1..b6），`Config::default()` 默认分组携带，验证：单元测试断言默认配置默认分组含 6 条且 id 连续
- [x] 1.2 确认 `next_bookmark_id` 在含预置时从 b7 起（无需改代码），验证：单测 add 后新书签 id 为 b7

## 2. 时钟显示（web/）

- [x] 2.1 `app.js` `updateClockTime()` 只写 `HH:MM`；`index.html` 与 `test-harness.html` 占位符 `--:--:--` → `--:--`，验证：headless 时钟文本匹配 `^\d{2}:\d{2}$`
- [x] 2.2 harness 的宽度稳定断言适配（不再逐秒变化），验证：headless 绿

## 3. 测试基线适配

- [x] 3.1 `store_test.mbt`：bookmark_add / bookmark_edit 改为定位"最后一个书签"；受影响断言逐一修正，验证：`moon test` 全绿
- [x] 3.2 `bookmark_import_test.mbt`：需要空基线的用例改用本地 `empty_import_store()` helper，验证：全绿
- [x] 3.3 `e2e.mjs`：新增"默认配置含推荐书签"断言；随后把主实例与导入实例重置为空基线，验证：`node e2e.mjs` 全绿
- [x] 3.4 `test-harness.html`：新增推荐书签断言；随后重置为空基线，验证：`node headless.cjs` 双运行全绿

## 4. 文档与规格

- [x] 4.1 README 功能/说明补充"默认推荐书签"；时钟描述去秒
- [x] 4.2 openspec validate 通过；feat 提交时 sync 两处主 spec；归档
