# Proposal: search-history

## Why

搜索是导航页最高频的操作，但每次输入都要从零敲完整关键词。搜索历史 + 前缀联想（iTab 类产品的标配）能显著降低输入成本；同时这也是申报书承诺的三项新功能之一，核心算法（trie 检索、时间衰减评分）全部落在 MoonBit，直接扩充业务侧代码规模。

## What Changes

- **历史记录**：每次有效搜索（非空、成功发起跳转）记录关键词，条目 `{query, count, last_used_ms}`；重复搜索累计次数并刷新时间，容量上限 100 条（满则淘汰评分最低）
- **前缀联想**：新增 `search_input` 事件，输入框聚焦/键入时 dispatch，store 通过 trie 做忽略大小写的前缀检索，按"频次 × 时间衰减"评分返回 Top 6 建议（空输入时返回最近使用的 6 条）
- **联想下拉 UI**：输入框下方建议列表；聚焦空输入显示最近历史，键入时前缀过滤；支持 ↑↓ 选择、Enter 执行选中项、Esc 关闭；条目右侧 × 删除单条
- **历史管理**：设置面板新增「清空搜索历史」按钮（新增 `history_clear` 事件）
- **持久化与兼容**：历史存于 `config.search.history`；`FromJson` 对缺失字段取空默认，**schema version 保持 1**——旧导出文件与旧 localStorage 无迁移导入，旧版本构建忽略新字段
- **新增 `src/trie` 独立包**：插入/前缀检索/删除的字符 trie，独立单元测试，作为可复用数据结构资产

## Capabilities

### New Capabilities

（无）

### Modified Capabilities

- `search-box`: 新增"搜索历史联想"需求——历史记录、前缀联想、键盘导航、历史管理（单条删除/清空）的行为规格

## Impact

- **修改文件**：`src/store/event.mbt`（search_input/search_submit 扩展时间戳、history_delete/history_clear）、`src/store/store.mbt`（reducer + suggestions 视图）、`src/model/search.mbt`（HistoryEntry + JSON 编解码）、`src/main/main.mbt`（不变，桥协议自动透传）、`web/app.js`（输入事件、下拉分区渲染、键盘导航）、`web/index.html`/`web/style.css`（下拉 UI）、`web/test-harness.html`、`e2e.mjs`
- **新增文件**：`src/trie/*.mbt`（trie 包 + 测试）、`openspec/changes/search-history/specs/search-box/spec.md`
- **不修改**：桥协议形态（仍是 init/dispatch 两个导出）、localStorage 既有字段语义、其他三个 capability 的行为
- **风险面**：config 兼容（缺省字段默认空，双向兼容已论证）；每键一次 wasm roundtrip（payload 小，实测量级无感）
