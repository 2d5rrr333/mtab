# Proposal: countdown-widget

## Why

起始页是"每天打开第一眼"的场景，倒数日（生日、考试、纪念日、假期）是高频刚需——iTab 等同类产品均以此为标配小组件；mtab 目前只有时钟与书签，缺少时间目标类信息。这也是申报书承诺的赛期新增功能之二。

## What Changes

- 新增倒数日小组件：用户可添加多条倒数日（名称 + 目标日期），小组件以紧凑列表显示每条"距离 XX 还有 N 天"，当天显示"就是今天"，过期显示"已过 N 天"
- 天数计算纯 MoonBit：目标日期与今天都走公历 JDN 差值，跨年/闰年天然正确；"今天"来自 `mtab_init(today)` 与 `tick_date` 事件（跨日自动刷新）
- 倒数日增删：小组件内添加按钮 + 删除按钮（无编辑——改名称/日期可删了重加，收敛交互面）；纳入现有 widgets 显隐开关（新增 `countdown` 开关，默认关）
- config v2 新增 `countdowns` 数组字段：旧配置/导入文件无此字段时解码为空列表（向后兼容，不升版本号）；导出/导入 JSON 自然携带
- 明确不做：按周期重复的倒数日（每年生日自动顺延）、倒计时到时分秒（天粒度足够且与时钟职责不重叠）

## Capabilities

### New Capabilities

- `countdown-widget`: 倒数日小组件——条目管理（增删/持久化）、剩余天数计算与展示（含当天/过期语义）、显隐开关、跨日自动刷新

### Modified Capabilities

- `configuration`: widgets 开关新增 `countdown`；config 持久化新增 `countdowns` 字段（缺省兼容）

## Impact

- `src/model/`：`countdown.mbt`（模型 + JSON 编解码 + 日期差）、`widgets.mbt`（+countdown 字段）、`config.mbt`（+countdowns 字段与解码兼容）
- `src/store/`：`event.mbt`（countdown_add/countdown_delete/widget_toggle 扩展）、store 归约 + `today` 跟踪（tick_date 联动倒数日视图）
- `src/lunar/`：JDN 公历日期差复用（如已有则不动）
- `web/`：倒数日小组件渲染分区、设置区开关、样式
- `e2e.mjs` / `headless.cjs` / test-harness：新断言
- 导出 JSON 形状变化（新增字段），v2 内向后兼容
