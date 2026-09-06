# Design: search-history

## Context

MVP 建立了"JS 壳只收集事件、store 是唯一决策点"的架构：`search_submit` 归约为 `open_url` 效果，搜索框分区从不重绘（焦点与草稿不丢）。历史联想要在这条架构内落地，且 config v1 必须双向兼容（旧数据导入零迁移、旧构建忽略新字段）。lunar 包是现有最大的纯算法资产（206 行），trie 包按同样的"纯函数 + 全测试"模式新增。

## Goals / Non-Goals

**Goals:**

- 历史记录、trie 检索、评分、容量淘汰全部在 MoonBit；JS 只做输入事件转发、下拉渲染、键盘导航
- config v1 兼容扩展，旧文件/旧 localStorage 导入即用，无迁移代码
- 每键一次 dispatch 的键入延迟无感知（payload 小、无网络）
- trie 包独立可复用，测试覆盖插入/检索/删除/边界

**Non-Goals:**

- 拼音联想、模糊匹配（编辑距离）、候选词高亮片段（后续可选增强）
- 历史跨设备同步、导入导出单独开关（历史已随 config JSON 自然导出）
- 防泄漏/隐身模式

## Decisions

### D1. 数据模型：`SearchConfig` 增加 `history`，缺省解码

```
HistoryEntry { query : String, count : Int, last_used_ms : Int }
SearchConfig { engines, current, history : Array[HistoryEntry] }
```

- `FromJson`：`history` 字段缺失 → 空数组默认（与 `config_import` 的 version 校验无冲突，version 保持 1）。旧构建的 `expect_object` 逐字段读取天然忽略未知字段
- `last_used_ms` 用 `Int`（JS `Date.now()` 当前 ~1.75e12，Int64 范围内；MoonBit `Int` 在 wasm-gc 为 32 位——**放不下**，改用 `Int64`，JSON 编解码走字符串或双精度：采用 `@json` 数字往返为 `Double` 再转 Int64，毫秒精度无损（< 2^53））
- 容量淘汰在 reducer 内完成，不引入后台任务

### D2. 事件扩展：`search_input` + `search_submit` 带时间戳 + 两个管理事件

```
search_input   { query, at? }         // 键入/聚焦；只更新视图，不 Save
search_submit  { query, at? }         // at 缺省取 0（兼容旧 e2e/测试调用）
history_delete { query }
history_clear  { }
```

`at` 可选：旧调用方（既有 e2e、headless）不传也能工作，只有评分时间衰减用到它。`search_input` 空查询不是错误，返回最近历史。

### D3. suggestions 视图分区：`Store` 增加瞬态字段

```
Store { config, clock, suggestions : Array[HistoryEntry] }  // 不入 config，不持久化
```

- 每次涉及历史的 dispatch（input/submit/delete/clear/init）重算 suggestions；其他事件原样保留（书签增删不碰联想内容）
- `mtab_init` 后 suggestions = 最近 6 条（页面刷新后聚焦即显由 JS 在 focus 时 dispatch `search_input{query:""}` 驱动，init 不必预填——JS focus 事件是唯一触发源，避免 init 时序耦合）

### D4. trie 包：`src/trie`，字节级字符 trie

- `Trie` 结构 + `insert(word, id)` / `prefix_query(prefix, limit)` / `remove(word)`；节点带 `entry_ids : Array[String]`（按 query 字符串索引历史条目）
- **为什么保留 trie 而非线性扫描**：100 条线性扫描性能足够，但 trie 是申报书承诺的数据结构资产、独立可复用（后续书签搜索可复用），且包体极小（预计 <150 行 + 测试）
- 忽略大小写：插入与查询统一 `to_lower`；中文无大小写，天然兼容
- trie 与评分解耦：trie 只做"前缀命中的条目集合"，排序在 store 侧按 `score = count × decay(now - last_used_ms)`（半衰期 7 天，`0.5^(Δms/7d)`），排序不稳定时按字典序保证确定性

### D5. 评分与淘汰

- 评分纯函数 `score(entry, now_ms)`，测试锚定半衰期（7 天前 count=4 ≈ 2.0）
- 容量淘汰：submit 插入新条目超限时，移除 `score` 最低者（并列移除 `last_used_ms` 最旧者）
- 空输入 Top6：按 `last_used_ms` 降序（纯最近优先）

### D6. UI：下拉分区 + 键盘状态在渲染壳

- `#search-suggest` 下拉挂在 `.search-row` 下（absolute 定位）；分区渲染函数 `renderSuggestions()`，输入框依旧不重绘
- 键盘状态（高亮索引）是纯 UI 态，留在 JS 模块变量，不入 store（store 不为渲染细节建模）；↑↓ 修改索引，Enter 时若有高亮项则以该项 query 提交 `search_submit`，Esc/失焦关闭
- 单条 ×：dispatch `history_delete`；设置面板「清空搜索历史」：dispatch `history_clear`，均立即触发 Save
- 点击外部关闭：`document` 点击委托，目标不在 `#search` 内则隐藏
- a11y：下拉 `role="listbox"`、条目 `role="option"` + `aria-selected`，沿用 `:focus-visible` 体系

### D7. 验证策略（四层）

- `moon test`：trie 包单元测试（插入/前缀/删除/大小写/空串边界）、store reducer 测试（记录累计、容量淘汰锚定、评分半衰期、delete/clear、`at` 缺省兼容）
- `e2e.mjs`：wasm 实例直跑新事件序列（input→建议顺序、submit 两次→count=2、clear→空）
- headless harness：真实键入路径（focus 显示最近、输入过滤、↑↓+Enter 执行、Esc 关闭、× 删除、设置清空、localStorage 持久化断言）
- 回归基线：37 项既有测试 + 63/65 harness + 18 e2e 不回退（`search_submit` 旧签名兼容保证旧调用不断）

## Risks / Trade-offs

- [每键 dispatch 序列化全量 config] → 当前 config 体量 <10KB，JSON 往返实测微秒级；若未来书签规模暴涨再考虑建议专用轻响应
- [Int64 毫秒时间戳跨 JSON] → 走 Double（< 2^53 精度无损），编解码各一处转换，测试锚定往返
- [键盘导航状态与 store 分区渲染的竞态]（input 事件重渲下拉时高亮索引重置）→ 每次重渲后索引 clamp 到 [-1, len)，索引重置为 -1（无选中），符合浏览器原生 autocomplete 行为
- [旧 e2e/headless 未带 `at`] → `at` 缺省 0，评分退化为纯 count 排序，行为确定可断言
- [容量淘汰的边界抖动]（并列最低分）→ 决胜规则固定（last_used_ms 最旧），测试锚定

## Migration Plan

config v1 兼容扩展，无数据迁移。回滚 = revert 代码，旧构建读到带 history 的 config 自动忽略该字段，数据无损。

## Open Questions

（无）
