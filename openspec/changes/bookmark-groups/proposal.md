# Proposal: bookmark-groups

## Why

书签目前是单一平铺网格，数量一多便无从组织。分组 + 拖拽排序是 iTab 类产品的核心组织能力，也是申报书承诺的最后一项新功能；树形分组模型与 JSON 迁移全部落在 MoonBit，是三项中数据面最重的一块。

## What Changes

- **分组模型**：`Config.groups : Array[Group]`（`Group { id, name, bookmarks }`）替代平铺 `bookmarks`；**config schema version 1 → 2**，`FromJson` 同时识别 v1（平铺数组自动迁移为默认分组）与 v2，`config_import` 接受两种版本，旧导出文件导入零丢失
- **固定默认分组**：每组配置的首位存在不可删除、不可重命名的「默认分组」（id `g0`）；删除其他分组时组内书签自动移回默认分组
- **分组管理事件**：`group_add {name}` / `group_rename {id, name}` / `group_delete {id}`（书签回落默认组）/ `group_move {id, to_index}`（分组排序）
- **书签事件扩展**：`bookmark_add` / `bookmark_edit` 增可选 `group`（目标分组，缺省默认组）；新增 `bookmark_move {id, to_group, to_index}` 统一承载组内排序与跨组移动
- **分段区块 UI**：每组一个区块（组名标题 + 该组网格），纵向排列；空分组显示占位
- **拖拽（Pointer Events 自实现）**：书签卡片拖拽（组内换位 + 跨组移动，插入位指示线）；分组标题拖拽换序；与点击/编辑/删除通过位移阈值区分
- **弹窗分组下拉**：添加/编辑书签弹窗增加目标分组选择

## Capabilities

### New Capabilities

（无）

### Modified Capabilities

- `bookmark-grid`: 新增"分组管理"（增删改组、默认分组规则、删组书签回落）、"拖拽排序"（书签组内/跨组、分组换序）需求；"添加书签"需求补充分组目标场景
- `configuration`: "配置导入"需求补充 v1 文件迁移场景（接受 version 1 与 2，v1 平铺书签自动入默认分组）

## Impact

- **修改文件**：`src/model/`（config.mbt v2 + group.mbt 新文件 + bookmark.mbt 不变）、`src/store/`（event.mbt 新事件、store.mbt reducer 全面改造为嵌套数组操作）、`web/`（index.html 分组区块结构与弹窗下拉、style.css、app.js 渲染分区 + pointer 拖拽 ~100 行）、`web/test-harness.html`（DOM 结构变更波及既有断言 + 拖拽模拟）、`e2e.mjs`
- **不修改**：桥协议形态、localStorage 机制、search/clock/configuration 其他需求
- **风险面**：本仓库最大一次模型变更——v1→v2 迁移正确性（localStorage 旧数据 + 旧导出文件双路径）、拖拽与点击的阈值区分、DOM 结构变更对既有 78 项 harness 断言的波及面
