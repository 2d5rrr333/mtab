# Tasks: bookmark-import

## 1. 解析器（src/model/netscape.mbt）

- [x] 1.1 实现 `parse_netscape(html) -> ParseResult?`：DOCTYPE 验证（大小写不敏感）+ 单遍 tokenizer（注释、标签、属性可无引号、文本）+ `<H3>`/`<A>` 属性提取（HREF/ADD_DATE 等忽略项容忍缺失），验证：夹具"标准 Chrome 导出文件"解析出正确分组与书签树
- [x] 1.2 分组嵌套栈语义：`<DL>` 入栈 / `</DL>` 出栈、顶层书签收集到 `top`，验证：3 层嵌套夹具各组归位正确
- [x] 1.3 实体还原 `&amp; &lt; &gt; &quot; &#39;` + `&#NNN;`/`&#xHH;`，验证：单元测试覆盖 5 命名实体与数字实体（十进制/十六进制）
- [x] 1.4 容错与拒绝边界：无引号属性、大小写混用、多余空白、未知标签、缺 HREF/缺名称行跳过、空文件与任意 HTML 返回 None，验证：单元测试逐项断言
- [x] 1.5 真实浏览器夹具：构造 Chrome/Edge/Firefox 三风格导出样例（CRLF、UTF-8、注释头、PERSONAL_TOOLBAR_FOLDER 属性），验证：解析结果与预期一致

## 2. store 归约（src/store/）

- [x] 2.1 `Event::BookmarkImport(html~)` + FromJson 分支（`bookmark_import` snake_case tag），验证：store_test 往返断言
- [x] 2.2 新 `Effect::Toast(message~)` + 壳层协议文档同步（app.js 渲染 toast），验证：effect.mbt 编译 + 既有测试全绿
- [x] 2.3 归并逻辑 `merge_import(groups, parsed)`：同名分组合并、URL 去重（normalize_url 为键、含本批去重）、新组追加在后、顶层书签入默认分组、无效 URL 跳过，验证：store 单元测试覆盖规格全部 3 个 Scenario
- [x] 2.4 归约 wiring：`BookmarkImport` → 解析失败 notify_error；成功产出新 groups + save + Toast（含"新增 X 组 Y 条，跳过 Z 条"文案）+ 5MB 护栏，验证：单元测试（成功/失败/护栏三路）
- [x] 2.5 容量与不变式：导入后 groups 过 `ensure_groups_valid`、不突破现有书签容量约束（超限部分跳过并在 Toast 计数），验证：容量边界单元测试

## 3. 壳层与入口（web/）

- [x] 3.1 设置区新增"导入书签文件"入口（input[type=file] + FileReader 读文本 → dispatch `bookmark_import`），与"导入配置 JSON"并列且文案区分，验证：headless 断言入口存在与可点击
- [x] 3.2 Toast 副作用渲染（复用现有 toast 样式），验证：headless 断言导入后 toast 文案与分组/书签渲染结果

## 4. 端到端验证

- [x] 4.1 e2e.mjs：dispatch bookmark_import（成功文件/非法文件/重复 URL）三段断言（注意 config 保存/恢复），验证：`node e2e.mjs` 全绿
- [x] 4.2 headless.cjs：UI 导入流程 + toast + 网格渲染断言（reduced-motion 双运行），验证：`node headless.cjs` 全绿
- [x] 4.3 基线回归：`moon test` + `moon info` + `moon fmt` 干净，全部测试数目更新进文档

## 5. 文档与规格

- [x] 5.1 openspec validate bookmark-import 通过；archive 时 sync bookmark-grid 主 spec
- [x] 5.2 README 功能表与测试数字更新（含导入功能行）
