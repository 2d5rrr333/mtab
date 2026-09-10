# Design: countdown-widget

## Context

见 proposal.md。现有基础：`days_from_civil`/`solar_days`（lunar 包，private）、store 的 `parse_ymd`（private）、`TickDate` 事件已驱动时钟跨日刷新、widgets 开关（clock/bookmarks）与 config v2 可选字段先例（wallpaperBlur/theme 均为加字段不升版本）。渲染分区：时钟/引擎栏/书签网格/壁纸各自独立。

## Goals / Non-Goals

**Goals:**
- 天数计算与验证全部在 MoonBit；壳层只渲染
- 复用 lunar 的日期基础设施（导出公开包装，不复制算法）
- 旧配置零迁移成本（可选字段缺省空列表）

**Non-Goals:**
- 周期性倒数日（每年自动顺延）、时分秒粒度、条目编辑（删了重加）
- 倒数日排序（保持添加顺序，排序是后续可能的 UX 打磨）

## Decisions

**D1：模型与配置字段** —— `Countdown { id, name, date }`，`date` 为 "YYYY-MM-DD" 字符串；存于 `config.countdowns : Array[Countdown]`。id 用 "cN" 模式（复用书签/分组的 numeric_suffix 扫描方式）。ToJson 写 `countdowns` 键（空数组也写——导出文件显式携带）；FromJson 缺省 `[]`。版本号不升：与 wallpaperBlur/theme 先例一致（可选字段的加法兼容）。

**D2：天数计算复用 lunar** —— `days_from_civil` 是私有的 Howard Hinnant 算法；在 lunar 包新增 `pub fn gregorian_day_number(y, m, d) -> Int` 公开包装（不复制代码）。倒数的"剩余天数" = 目标日 day_number − 今天 day_number（正数=还有 N 天，0=就是今天，负数=已过 |N| 天）。日期有效性校验：`parse_ymd`（store 内已有）+ `solar_days` 边界（如 2026-02-30 拒绝）——校验放 model 层 `validate_countdown_date`。

**D3：today 进状态树** —— `Store` 新增 `today : String`（open 时设置、TickDate 时更新，与 clock 一同重算）；新增派生视图 `countdown_views : Array[CountdownView]`（`{ name, days }`，随 open/tick_date/countdown 增删事件重算）。视图放 state（与 suggestions 同模式：派生、不持久化），壳层零计算。

**D4：事件面** —— `CountdownAdd(name~, date~)` / `CountdownDelete(id~)`；`WidgetToggle` 增加 "countdown" 分支。归约：名称 trim 后非空、日期过 `validate_countdown_date`，否则 notify_error；成功 append 到 countdowns 末尾 + Save。删除不存在的 id：notify_error。

**D5：渲染与交互** —— 小组件默认关闭（`widgets.countdown = false`，与 proposal 一致）。开启后渲染在时钟与书签网格之间：紧凑卡片列表，每条"名称 + 天数徽章 + 删除按钮"，空列表显示占位提示与"添加"入口。添加用小表单（名称 input + date input，原生 `<input type="date">` 提供日历选择，提交走 JSON 桥）。设置区 widgets 面板加"倒数日"开关（复用现有开关样式）。

**D6：无障碍** —— 删除按钮 aria-label、列表用 ul/li、天数变化不引发动画（纯文本替换）。

## Risks / Trade-offs

- [原生 date input 在 headless 中赋值格式差异] → harness 用直接 dispatch + 手工设 value 双路测试；渲染断言只看派生视图输出
- [tick_date 每 30s 轮询跨日] → 已有时钟先例，倒数日同批重算，无额外轮询
- [date 字符串解析分散] → 唯一校验入口 `validate_countdown_date`（model），store/测试都走它

## Migration Plan

无 schema 版本变化。旧 v2 文件（无 countdowns）→ 空列表；新文件在旧构建上解码会忽略未知键（FromJson 只取已知字段）→ 双向兼容。回滚 = 关闭开关，数据留在 config 不受影响。

## Open Questions

（无）
