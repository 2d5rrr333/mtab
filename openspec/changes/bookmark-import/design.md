# Design: bookmark-import

## Context

见 proposal.md。现有基础：`Event` 闭枚举 + `FromJson`（event.mbt）、`normalize_url`（url.mbt）已承担 URL 归一化与校验、group_ops 提供纯函数数组操作、store 归约产生 `save`/`notify_error` 副作用。config v2 的 groups 结构（嵌套数组即顺序）是导入的目标落点。已知坑：derive(ToJson) snake_case、CSS longhand、e2e 中 config_import 整体替换需保存/恢复。

## Goals / Non-Goals

**Goals:**
- 解析器为纯函数（HTML 字符串 → `ParsedImport`），独立于 store，可单测
- 导入归约复用现有校验路径（normalize_url、分组不变式），不引入第二套规则
- 壳层零决策：JS 只读文件文本并 dispatch，wasm 决定一切（架构铁律）

**Non-Goals:**
- 导出 Netscape 格式（JSON 导出已覆盖）
- 去重策略可配置、导入预览 UI（后续如需再开 change）
- FEED 属性、`UNFILED_BOOKMARKS_FOLDER` 语义区分（一律视为普通分组层级）

## Decisions

**D1：解析器输出结构** —— `parse_netscape(html) -> ParseResult?`：`ParseResult{ groups : Array[ParsedGroup] }`，`ParsedGroup{ name, bookmarks : Array[(name, url)] }`，仅含文件里有名称的 `<H3>` 分组；顶层（默认层级）书签单独放一个 `top : Array[(name, url)]` 字段。验证门槛：`<!DOCTYPE NETSCAPE-Bookmark-file>`（大小写不敏感、允许前后空白）缺失即返回 None（spec：非法文件拒绝）。备选：返回 Result 带 3 种错误——过度设计，壳层只需"失败 + 原因"。

**D2：tokenizer 走单遍扫描而非正则/递归 DOM** —— 手写 `<! ...>` 注略、`<tag attr=...>`（属性值可无引号）、文本节点三个态的线性扫描器；分组嵌套用显式栈维护。理由：MoonBit 无内置正则；Netscape 文件实际是"每行一个 DT/H3/A/DL"的规整格式，Chrome/Firefox 导出均含大量非标容错点（无引号属性、多余空白、大小写混用、`<p>` 杂tag），单遍扫描 ~200 行可全覆盖且完全可测。已知偏差全部进测试夹具。

**D3：导入归约为一次新事件 `BookmarkImport(html~)`** —— 不在壳层解析、也不拆成 N 个 BookmarkAdd 事件（会绕过"同批去重 + 汇总统计"且 JSON 桥往返 N 次）。store 收到事件后：调解析器 → 逐组归并（同名现有分组合并、URL 与现有/本批重复则跳过）→ 产出新 groups + `save` 副作用 + 新 effect `Toast`。顶层书签落入默认分组。统计（新增组数/书签数/跳过数）随 Toast 文案返回，壳层只显示。
- 合并语义：按分组名精确匹配现有分组（含"默认分组"）；文件内同名分组（同深度或跨深度）依次并入同名目标组，不产生 "工作 (2)"。
- URL 去重：以 `normalize_url` 结果为键；解析阶段不做去重（保留原始数据），归并阶段统一去重，逻辑单点。

**D4：`Toast` 作为新 Effect** —— 现有 effect 枚举只有 notify_error/save/open_url；导入成功的汇报走新 `Toast(message~)`，壳层已有的 toast 逻辑（error 用）复用渲染。比复用 notify_error 语义更诚实，比新增"分区重绘 + 文案"轻。

**D5：实体还原限定 5 实体 + 数字实体** —— `&amp; &lt; &gt; &quot; &#39;` + `&#NNN;`/`&#xHH;`。不实现命名实体全集（&nbsp; 等罕见于书签 title），保留原样不报错。理由：浏览器导出实际只转义这 5 种（Chrome 源码 `Escaping::Escape`）。

**D6：文件大小护栏** —— 归约前检查 html 长度 > 5MB 直接 notify_error（防 localStorage 爆炸的是导入的书签量本身，容量上限沿用现有书签容量约束）。

## Risks / Trade-offs

- [解析器对真实世界怪文件覆盖不足] → 夹具用 Chrome/Edge/Firefox 三浏览器真实导出样例 + 手工构造边界（无引号、缺 HREF、嵌套 3 层、实体、CRLF）
- [同 URL 不同名称在导入时静默跳过，用户困惑] → Toast 文案带跳过数（"导入 3 组 12 条，跳过重复 4 条"）
- [大文件（万条书签）归约耗时] → 单遍解析 O(n)；5MB 上限兜底；实测万条 <10ms 量级（wasm-gc）
- [与现有 JSON 导入（config_import）混淆] → UI 入口分开：设置区"导入书签文件"与"导入配置 JSON"并列，文案明确区分

## Migration Plan

无 config schema 变化（导入只写既有 groups）。回滚 = 不用该功能；已导入数据可用现有删除/分组管理清理。事件新增对旧客户端无影响（未知事件已有 notify_error 路径）。

## Open Questions

（无）
