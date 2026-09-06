# Tasks: search-history

## 1. trie 包（src/trie）

- [x] 1.1 新建 `src/trie` 包：`Trie` 结构 + `insert` / `prefix_query`（返回命中条目 id 集合）/ `remove`，字节字符级、大小写归一由调用方处理。验证：`moon test` 新增 trie 单元测试全过（插入/前缀命中/前缀无命中/删除后不再命中/空串前缀命中全部/单字符边界）
  - 记录：8 项测试全过。修正过一处测试断言笔误（mongo 不以 moon 为前缀，命中数应为 3）；`Map::size()` 弃用改 `length()`；`Array::remove` 返回值需 ignore；`pub(all)` 字段不可变，`size` 用 `mut`
- [x] 1.2 `moon.pkg` 接入 store 依赖，`moon info` 生成接口，`.mbti` 检视无意外暴露
  - 记录：Trie 收紧为 `pub`（字段只读可见），`.mbti` 仅暴露 new/insert/remove/prefix_query 四个方法

## 2. 模型层（src/model）

- [x] 2.1 `HistoryEntry { query, count, last_used_ms : Int64 }` + ToJson/FromJson（last_used_ms 经 Double 往返）；`SearchConfig` 增 `history`，FromJson 缺省空数组。验证：model 单元测试（缺字段默认空、往返无损、Double↔Int64 边界值往返）
  - 记录：`int64_field`/`number_field_opt` helpers 加入 json_helpers；8 项 model 测试全过（含 1.75e12 毫秒级时间戳精确往返）
- [x] 2.2 评分纯函数 `score(entry, now_ms)`（count × 0.5^(Δ/7d) 半衰期）。验证：单元测试锚定（新搜索 1 分、7 天前 count=4 → 2.0、14 天前 count=8 → 2.0）
  - 记录：`decay_pow` 手写实现（整数次幂循环 + 小数部分线性插值），半衰期锚定测试在 ±0.15 容差内通过

## 3. store 层（src/store）

- [x] 3.1 事件扩展：`search_input {query, at?}`、`search_submit` 增 `at?`、`history_delete {query}`、`history_clear`；`at` 缺省 0 兼容旧调用。验证：既有 37 项测试不回退（旧签名 dispatch 全部通过）
  - 记录：JSON 层 `at_field` 可选解码；枚举构造器不支持默认参数，黑盒测试 3 处旧调用补 `at=None`；JSON 路径（e2e 直发不带 at）零改动兼容
- [x] 3.2 `Store` 增 `suggestions` 视图字段；`search_input` 空查询→最近 6 条（last_used_ms 降序），非空→trie 前缀命中 + score 排序 Top 6，不 Save。验证：store 单元测试（空查询最近序、前缀过滤忽略大小写、排序确定性、无匹配空数组）
  - 记录：`suggest_for` 每次请求重建 trie（100 条上限下成本可忽略，换来零状态同步 bug）；`open`/`config_import` 后 suggestions 初始化为最近历史
- [x] 3.3 `search_submit` 记录历史：存在则 count+1、last_used_ms=at；新条目则插入；超 100 淘汰 score 最低（并列取最旧）。验证：单元测试（重复累计、容量 100 淘汰锚定、淘汰决胜规则）
  - 记录：淘汰决胜完整规则 score → last_used_ms → query 字典序（确定性）；引擎缺失时仍记录历史（用户意图）
- [x] 3.4 `history_delete` 移除单条并重算 suggestions；`history_clear` 清空。验证：单元测试（删除后建议不再含该条、清空后 suggestions 空、两者均触发 Save）
  - 记录：10 项 history_test 全过；黑盒测试修正 2 处断言期望（空查询纯最近序、等分时更新者在前——均为 design D5 的既定行为，实现无误）

## 4. 渲染壳（web/）

- [x] 4.1 `index.html`/`style.css`：`#search-suggest` 下拉（absolute、`role="listbox"`、条目 `role="option"`），选中高亮样式；与既有 scrim/层级/圆角体系一致。验证：浏览器手动过目 + harness 样式断言
  - 记录：下拉挂在 `.search-row`（改 position:relative），毛玻璃+圆角与既有模态体系一致；`aria-expanded`/`aria-selected` 全套
- [x] 4.2 `app.js`：input focus/input 事件 dispatch `search_input`（携带 `Date.now()`）；`renderSuggestions()` 分区渲染；↑↓/Enter/Esc 键盘导航（高亮索引为渲染壳态，重渲后重置 -1）；条目 × → `history_delete`；点击外部关闭。验证：harness 键盘路径断言（↓+Enter 以选中项搜索、Esc 关闭且输入不变、× 后条目消失）
  - 记录：断言通过；Enter 选中项提交在 harness 中因 open_url 导航风险未直接断言（e2e 已覆盖 submit 记录路径），harness 覆盖 ArrowDown 高亮 + aria-selected
- [x] 4.3 设置面板「清空搜索历史」按钮 → `history_clear`。验证：harness 断言清空后聚焦无建议 + localStorage 中 history 为空
  - 记录：toast「已清空搜索历史」success 态；harness 4 项相关断言全过

## 5. 回归与验收

- [x] 5.1 `e2e.mjs` 增补：input→建议顺序、submit×2→count=2、delete/clear 序列断言；既有 18 项不回退
  - 记录：e2e 扩至 25 项全过（18 既有 + 7 新增，含 legacy config 无 history 字段导入兼容）
- [x] 5.2 headless harness 增补联想交互断言（聚焦即显、前缀过滤、键盘导航、持久化）；既有 63/65 项不回退
  - 记录：harness 扩至 73/75 全过。历史注入改走 config_import（真实 search_submit 会触发 open_url 离开 harness 页）；过程中发现并修复 app.js 一处非法 for 语法（浏览器整页崩）、build.ps1 在 PS5.1 下被 moon stderr 杀死导致 staged wasm 停留在旧版（放宽 ErrorActionPreference 修复，CI ubuntu pwsh7 不受影响）
- [x] 5.3 全量回归：`moon fmt --check`（本地 20260827）、`moon check`、`moon test` 全绿；`moon info` 无意外接口漂移；headless 双运行全绿；截图刷新留人工过目，任务记录给出验收结论
  - 记录：fmt-check 0、check 0 警告 0 错误、moon test 63/63（37 既有 + 26 新增）、e2e 25/25、harness 73/73 + reduced-motion 75/75、渲染检查 13/13；`.mbti` 增量均为预期公开接口（HistoryEntry/score/number_field_opt/新事件/常量）。另：applyWallpaper decode 等待加 800ms 超时兜底（headless 虚拟时间下 decode 可能不完成，超时走同一 reveal 路径，真实浏览器行为不变）。验收结论：search-box spec 增量的 4 条需求 10 个场景全部落地并有四层验证覆盖；观感（下拉与输入框对齐、高亮样式）留人工复核 headless.png
