# Tasks: bookmark-groups

## 1. 模型层（src/model）

- [x] 1.1 新建 `group.mbt`：`Group { id, name, bookmarks }` + ToJson/FromJson；`DEFAULT_GROUP_ID = "g0"`、`make_default_group(bookmarks)`、`ensure_groups_valid`（空数组补 g0 空组）。验证：单元测试（空数组补组、往返无损）
  - 记录：ensure_groups_valid 同时防御"首组非 g0"（前置默认组），与 store 的 g0 恒首位不变量双保险；9 项 group model 测试全过
- [x] 1.2 `Config` v2：`groups` 替代 `bookmarks`；`CONFIG_VERSION = 2`；FromJson 按 version 分派——v1 读平铺 bookmarks 迁移为默认组（保序），v2 读 groups；ToJson 恒写 v2。验证：单元测试（旧 v1 JSON 字面量 → 迁移结构保序、v2 往返、未知 version 拒绝、v2 空 groups 补默认组）
  - 记录：v1 字面量直接取自旧导出样例；既有 config_test 的 v1 shape 测试改为断言迁移结果（语义保留）
- [x] 1.3 分组 id 生成 `next_group_id`（跨组扫描 "gN" 最大值 + 1）。验证：单元测试（含 g0 存在时的编号递增）
  - 记录：numeric_gid_suffix 拒绝非纯数字后缀（防御性 0）

## 2. store 层（src/store）

- [x] 2.1 事件扩展：`bookmark_add/bookmark_edit` 增可选 `group`；新增 `BookmarkMove {id, to_group, to_index}`、`GroupAdd {name}`、`GroupRename {id, name}`、`GroupDelete {id}`、`GroupMove {id, to_index}`（JSON 解码含可选字段缺省）。验证：既有 80 项测试不回退（旧调用兼容）
  - 记录：`str_field_opt` 加入 json helpers；`int_field` 提升 pub（to_index 解码）；JSON 路径旧调用（不带 group）零改动兼容，MoonBit 构造器侧旧测试补 `group=None`
- [x] 2.2 书签 reducer 改造：add/edit/delete 跨组扫描与嵌套数组操作（全部返回新数组）。验证：适配既有书签测试 + 新增（add 到指定组、组不存在 notify_error、edit 改组、id 跨组唯一）
  - 记录：group_ops.mbt 承载全部嵌套操作（map_groups/map_all_groups/edit_bookmark），reducer 分支保持薄
- [x] 2.3 `bookmark_move`：组内换位、跨组移动（先移除后插入）、to_index clamp、目标组不存在 notify_error。验证：单元测试（组内换位锚定、跨组、负索引/超大索引 clamp、坏组拒绝且状态不变）
  - 记录：同组移动的索引语义 = "移除后的列表索引"（与 JS 命中计算一致，harness 拖拽断言验证了端到端一致性）
- [x] 2.4 分组 reducer：add（空名拒绝）、rename（g0 拒绝）、delete（g0 拒绝 + 组内书签 concat 进 g0 尾部）、move（clamp 到 [1, len-1]，g0 恒首位）。验证：单元测试（全套含 g0 保护、回落保序、move clamp）
  - 记录：move_group 初版插入索引数学有误（差一）被测试抓出，重写为"移除后按最终位置 insert"的清晰模型
- [x] 2.5 `config_import` 校验放宽 `version ∈ {1, 2}`。验证：单元测试（v1 导入迁移、v3 拒绝提示）
  - 记录：v1→v2 迁移发生在 FromJson 层，config_import 只放宽版本校验——localStorage 旧数据在 mtab_init 即享受同一路径

## 3. 渲染壳（web/）

- [x] 3.1 `index.html`/`style.css`：分组区块结构（bm-group/bm-grid 作用域化）、组头（拖拽柄/重命名/删除，g0 无删改）、空分组虚线占位、新建分组按钮、弹窗分组下拉、拖拽指示线样式、`.dragging` 全局态。验证：浏览器手动过目 + harness 样式断言
  - 记录：指示线用卡片 ::before 侧边条（left/right by .after）；空态文案保持原文案兼容既有断言
- [x] 3.2 `app.js` 渲染分区改造：`renderBookmarks` → 按组渲染（含组头操作按钮、下拉选项同步）；既有书签卡片结构与事件委托适配组作用域。验证：harness 既有书签断言适配后全过
  - 记录：总空态 = 仅 g0 且无书签（保持原文案）；syncGroupSelect 每次开弹窗重建选项
- [x] 3.3 `app.js` 拖拽实现：pointerdown 阈值 6px 判定、pointermove 命中计算（elementsFromPoint + 组内插入位）、指示线、pointerup dispatch `bookmark_move`/`group_move`；点击不被劫持（编辑/删除/打开照常）。验证：harness 合成 PointerEvent 拖拽断言（组内换位、跨组移动、小位移点击不排序）
  - 记录：命中计算用 getBoundingClientRect 而非 elementsFromPoint（合成事件下 rects 更稳）；gridAtPoint 允许 120px 垂直容差落点；两处非法 for-of 语法被 node --check 抓出后修正
- [x] 3.4 弹窗分组下拉：添加默认选中第一组、编辑预选当前组、提交带 group。验证：harness 断言（添加到指定组、编辑改组）
  - 记录：编辑预选通过 openBookmarkForm(bm, gid) 的 findBookmark 传组
- [x] 3.5 分组管理操作接线：新建（prompt）、重命名、删除。验证：harness 断言（新建出现、改名更新、删除回落书签到默认组、g0 无删改入口）
  - 记录：prompt 由 harness stub（window.prompt = () => '工作'），空输入不发事件

## 4. 回归与验收

- [x] 4.1 `e2e.mjs` 增补：v1 config 导入迁移断言、分组生命周期（add → rename → move → delete 回落）、bookmark_move 序列；既有 28 项适配后不回退
  - 记录：e2e 扩至 45 项全过（v1 迁移保序、跨组移动、g0 双保护、生命周期完整链路）
- [x] 4.2 headless harness 增补与适配：既有断言选择器按组作用域适配；新增分组管理 + 拖拽断言；既有 78/78 基线语义不变
  - 记录：harness 扩至 83/85 全过。适配点：gridItems 改 .bm-group 作用域、localStorage 断言 v2 结构、edit/click/delete 按 id 定位卡片（组内顺序变化不再依赖 [0]）、import 用 v1 形态文件顺带验证迁移路径。新增 8 项：新建组、下拉添加入组、跨组拖拽、组内拖拽换位、小位移不重排、改名、删组回落、（组拖拽换序由 group_move 的 store/e2e 覆盖）
- [x] 4.3 全量回归：fmt --check / moon check / moon test 全绿；`.mbti` 增量检视；headless 双运行全绿；截图刷新，任务记录给出验收结论（重点：v1 迁移双路径、拖拽全链路、g0 保护、回落不丢书签）
  - 记录：fmt-check 0、check 0 警告 0 错误、moon test 103/103（89 适配 + 14 新增 store 分组测试）、e2e 45/45、harness 83/83 + reduced-motion 85/85、渲染 13/13；`.mbti` 增量为预期的 v2 模型与新事件。验收结论：bookmark-grid 两条新需求 8 场景 + configuration 导入需求 v1 迁移场景全部落地；v1 迁移三路径（localStorage init、config_import、e2e/harness 文件导入）全覆盖；拖拽经合成 PointerEvent 端到端验证（跨组/组内/阈值）；g0 保护与回落保序由 store 单测 + e2e + harness 三层锚定。已知边界：prompt 交互为最简实现（后续可换内联输入）；观感留人工复核 headless.png
