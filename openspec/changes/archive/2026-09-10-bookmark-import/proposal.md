# Proposal: bookmark-import

## Why

新用户已有浏览器书签（Chrome/Firefox/Edge 均可导出 Netscape 书签 HTML 文件），逐条手动录入 mtab 成本高。补上"导出 → 一键导入"路径，mtab 才能作为真实的日常起始页落地，也让申报书承诺的核心新增功能闭环。

## What Changes

- 新增纯 MoonBit 的 Netscape 书签文件解析器：容错 tokenizer（属性可选引号、标签大小写、多余空白）、`<DT><H3>` 分组与 `<DT><A>` 链接提取、HTML 实体（`&amp;` `&lt;` `&gt;` `&quot;` `&#39;` 及数字实体）转义还原
- store 新增 `bookmark_import` 事件：解析结果归约为分组/书签创建事件流，复用现有 group/bookmark 归约与校验（URL 归一化、容量上限、重名处理）
- web 壳新增"导入书签"入口（设置区），文件读取由 JS 侧 FileReader 完成，HTML 文本经 JSON 桥进入 wasm；导入完成后按分区重绘并 toast 汇报（新增 N 组 / M 条）
- 明确不做：导出为 Netscape 格式（现有 JSON 导出已覆盖备份需求）、去重合并策略配置（同名分组自动追加序号，见 design）

## Capabilities

### New Capabilities

（无）

### Modified Capabilities

- `bookmark-grid`: 新增"书签导入"需求——Netscape HTML 解析行为、导入归约规则（同名分组合并且书签去重、默认分组导入、无效行跳过）、导入结果汇报

## Impact

- `src/model/`：新增 `netscape.mbt` 解析器 + 单元测试（真实浏览器导出样例、嵌套文件夹、缺属性、非法行边界）
- `src/store/`：`event.mbt` 新增事件、`store.mbt`/`group_ops.mbt` 归约逻辑 + 测试
- `src/main/`：`mtab_dispatch` 透传，无新 FFI 面
- `web/app.js`：设置区导入入口 + 文件读取（壳层无决策逻辑）
- `e2e.mjs` / `headless.cjs`：导入流程断言
- config 结构不变（导入只产生既有 bookmark/group 数据）
