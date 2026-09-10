# Design: starter-presets-and-clock

## Context

见 proposal.md。`Config::default()` 是 `open()` 在无存储/解码失败时的落点，也是单测的"初始状态"来源；`updateClockTime()` 在壳层拼时间字符串。

## Goals / Non-Goals

**Goals:**
- 预置内容与逻辑全部在 MoonBit（默认配置），壳层零决策
- 预置书签走既有 Bookmark 结构，不引入新字段/事件
- 时钟只改显示格式，不动时钟状态与跨日逻辑

**Non-Goals:**
- 预置分组（避免打乱 groups 索引语义），预置书签放默认分组
- 可配置的推荐清单、首次引导弹窗

## Decisions

**D1：预置书签是默认配置的一部分** —— 在 `config.mbt` 增加 `pub fn starter_bookmarks() -> Array[Bookmark]`（id `b1`..`b6`，常用站点），`Config::default()` 的默认分组携带它们。理由：`open()` 无存储时自然得到推荐内容；已有存储的用户走 stored 分支，天然不被追加（满足规格第三条）。备选：独立 `SeedPresets` 事件——会把"首次判断"推给壳层，违背"壳层零决策"铁律，弃用。

**D2：预置放在默认分组而非新分组** —— 新分组会让 `groups` 索引整体后移，冲击分组/拖拽/导入的既有语义与测试；放默认分组只影响"默认分组内容"相关断言，最小扰动。

**D3：id 从 b1 起** —— `next_bookmark_id` 取最大数字后缀 +1，用户新加的书签自动从 b7 起，不与预置冲突。

**D4：时钟去掉秒只在壳层** —— `updateClockTime()` 只写 `HH:MM`；`clock_view_for`/`TickDate`/状态树不变。跨日刷新逻辑不受影响。

## Risks / Trade-offs

- [默认非空破坏既有"空网格"测试] → 逐处修正断言：单测改用"最后一个书签"或空基线 helper；e2e/harness 在断言预置后重置为空基线，保持其余流程不变
- [用户可能不想要推荐] → 预置书签可正常删除，且删一次后持久保存，不再注入

## Migration Plan

无 config 版本变化（结构不变，仅默认内容）。旧配置照常加载，不追加预置。回滚 = 恢复 `Config::default()` 的默认分组为空。

## Open Questions

（无）
