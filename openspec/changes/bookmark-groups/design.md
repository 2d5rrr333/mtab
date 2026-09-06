# Design: bookmark-groups

## Context

config v1 的 `bookmarks` 平铺数组要演进为 `groups` 嵌套结构（version 2），这是本仓库第一次 schema 迁移。store reducer、渲染分区、harness 断言都要跟着模型走。拖拽的可测性约束（headless 无法驱动 HTML5 DnD 的 DataTransfer）决定了交互实现选型。

## Goals / Non-Goals

**Goals:**

- v1 → v2 双向兼容：旧 localStorage 与旧导出文件导入零丢失；新导出文件为 v2 形态
- 分组管理/拖拽排序的全部决策逻辑（目标位置计算、回落、id 生成）在 MoonBit；JS 只上报 pointer 几何
- 拖拽可在 headless harness 中以合成 PointerEvent 完整驱动
- 既有行为（增删改书签、图标回退、空状态）在新结构下语义不变

**Non-Goals:**

- 分组折叠/展开记忆（可后补）、分组图标/颜色、嵌套子分组
- 键盘排序（Tab+方向键移动书签）
- 移动端触摸拖拽优化（pointer events 天然可用，但不做专门手势）

## Decisions

### D1. 模型：嵌套 groups 数组，version 2

```
Config v2 {
  version: 2,
  groups: [ Group { id, name, bookmarks: Array[Bookmark] } ],
  search / widgets / wallpaper  （不变）
}
```

- 顺序信息（组序 + 组内序）天然编码在嵌套数组中：reorder = 元素移动，无额外 order 字段
- **固定默认分组**：id `"g0"`、名"默认分组"，恒为 `groups[0]`；不可删/不可改名（reducer 拒绝），`group_delete` 回落目标、`bookmark_add` 缺省目标
- **解码双版本**：`FromJson` 按 `version` 字段分派——v1 读平铺 `bookmarks` → `groups: [默认组(全部)]`；v2 读 `groups`。v2 解码时若 `groups` 为空数组，补默认空组（不变量：groups 永远 ≥ 1 且首组为 g0）
- `CONFIG_VERSION = 2`；`config_import` 校验放宽为 `version ∈ {1, 2}`；`ToJson` 恒写 v2
- **分组 id**：`"g" + (现有最大 gN 数字 + 1)`，与书签 id 同款生成器（跨组扫描）

### D2. 事件与 reducer

```
bookmark_add    {name, url, group?}      缺省 g0；组不存在 → notify_error
bookmark_edit   {id, name, url, group?}  可顺带改组（弹窗下拉）；不传组则留原组
bookmark_move   {id, to_group, to_index} 组内换位与跨组统一；index 越界 clamp；
                                          目标组不存在 → notify_error + 状态不变
bookmark_delete {id}                      （不变，跨组扫描）
group_add       {name}                    空名/纯空白 → notify_error；追加到末尾
group_rename    {id, name}                g0 拒绝；空名拒绝
group_delete    {id}                      g0 拒绝；组内书签 concat 进 g0 尾部
group_move      {id, to_index}            g0 也参与换位？——否：g0 恒为首位，
                                          其余组在其后重排（to_index 相对全数组，
                                          clamp 到 [1, len-1]）
```

- reducer 全部操作返回**新数组**（copy + 定点修改），无原地变异；`next_bookmark_id` 扫描全部组
- 一次 dispatch 一个事件，无批量；每个变更组的事件都发 `[Save]`

### D3. 拖拽：Pointer Events 自实现 + JS 上报几何、MoonBit 定结局

分层：

```
JS（渲染壳，~100 行）                    MoonBit（store）
pointerdown  记录起点/目标卡片            bookmark_move {id, to_group,
  + setPointerCapture                       to_index}
pointermove  位移 > 6px 进入拖拽态；
             命中计算（哪个组网格、            组内换位 / 跨组移动 / clamp
             插入到哪个索引）→
             指示线渲染（纯 DOM）
pointerup    若拖拽态 → dispatch
             bookmark_move；否则视为点击
分组标题      同款阈值逻辑 → group_move
```

- **点击/拖拽区分**：6px 位移阈值，未超过 = 原点击行为（打开/操作按钮）
- **命中计算**：`document.elementsFromPoint` 找组网格容器 + 按组内卡片中点二分插入位——全部在 pointermove 里做，只读几何，不做决策
- **为何不在 JS 算 to_index 后直接改 DOM**：维持"store 唯一决策点"——JS 只报 `to_group + to_index`，store 归约出新状态，渲染分区照常重绘
- 拖拽期间 body 加 `.dragging` class（禁 hover 抬升等干扰样式）；`touch-action: none` 于可拖元素

### D4. UI：分段区块 + 弹窗下拉

- `#bookmarks` 内渲染：每组 `<section class="bm-group" data-gid>` = `<header>`（组名 + 拖拽柄 + 重命名/删除按钮，g0 无删改按钮）+ `.bm-grid`（既有卡片结构不变）
- 空分组显示虚线占位（复用 bm-empty 风格）"拖到这里"——也是跨组拖放的落点提示
- 添加/编辑弹窗：`<select>` 分组下拉（g0 置顶）；编辑时预选当前组
- 分组管理入口：组头 hover 显示 ✎/🗑；新建分组按钮放书签区标题行（"添加书签"旁）
- **总空状态**：仅 g0 且无书签时显示既有空状态提示（原文案不变，兼容既有断言）

### D5. 验证策略（四层）

- `moon test`：模型迁移（v1 JSON → v2 结构、书签保序、旧文件无 groups 字段）、分组 CRUD、g0 保护、回落、bookmark_move（组内/跨组/越界 clamp/坏组）、group_move clamp、id 生成跨组唯一
- e2e：wasm 实例序列——v1 config 导入迁移、完整分组生命周期、move 序列
- harness：真实 DOM——**合成 PointerEvent 拖拽**（pointerdown → 多次 pointermove → pointerup）断言卡片换位与跨组移动；点击不触发排序（小位移）；既有书签断言在新 DOM 下适配（grid 选择器按组作用域）
- 回归：80 moon test / 28 e2e / 78+78 harness 基线不回退

## Risks / Trade-offs

- [DOM 结构变更波及既有 harness 断言]（bm-grid 选择器、列数断言等）——逐条适配，只改选择器不改断言语义；空状态断言保持原文案兼容
- [合成 PointerEvent 与真实浏览器差异]（isTrusted=false、pointer capture 行为）——handler 不检查 isTrusted；capture 用 try/catch 兜底；harness 断言覆盖完整拖拽链
- [迁移路径遗漏（localStorage 旧 v1 + 导入 v1 文件 + e2e 旧 JSON 字面量）]——三条路径各有测试锚定；v1 解码单测直接喂旧导出样例
- [拖拽期间分区重绘竞争]（dispatch 后重绘 DOM 与拖拽态冲突）——拖拽由用户 pointer 驱动，dispatch 后立即结束拖拽态再重绘；无持续拖拽中的状态更新场景
- [group_move 的 g0 首位不变量被绕过]——reducer 内 clamp 强制 [1, len-1]，单测锚定

## Migration Plan

v1 localStorage 在下次 `mtab_init` 时自动迁移为 v2 并在下一次 Save 落盘；旧导出文件导入即迁移。回滚 = revert 代码（v2 localStorage 对旧代码不可读，回滚前需清 localStorage——记录在案）。

## Open Questions

（无）
