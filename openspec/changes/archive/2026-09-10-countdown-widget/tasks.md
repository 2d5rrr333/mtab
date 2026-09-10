# Tasks: countdown-widget

## 1. 模型层（src/model/）

- [x] 1.1 lunar 包导出 `gregorian_day_number(y, m, d)`（包装 days_from_civil），验证：单元测试断言已知日期差（2026-09-10 → 2026-09-13 差 3；2027-02-28 → 2027-03-01 差 1；跨闰年 2028-02-28 → 2028-03-01 差 2）
- [x] 1.2 `countdown.mbt`：`Countdown { id, name, date }` + ToJson/FromJson（键 id/name/date）+ `validate_countdown_date`（YYYY-MM-DD 真实日期校验，含 2026-02-30 拒绝）+ `remaining_days(date, today)`（正=剩余、0=今天、负=已过），验证：单元测试覆盖格式错误/月日越界/闰月边界
- [x] 1.3 `widgets.mbt` 加 `countdown : Bool`（默认 false 缺省）；`config.mbt` 加 `countdowns : Array[Countdown]`（缺省 []）、ToJson 写 countdowns、default() 中 widgets.countdown=false + countdowns=[]，验证：config JSON 往返测试（含无字段旧文件解码为空）

## 2. store 层（src/store/）

- [x] 2.1 `Store` 加 `today : String` 与派生 `countdown_views : Array[CountdownView]`（`{ name, days }`）；open/ConfigImport 后初始化，验证：store_test 断言 today 与视图初始为空列表
- [x] 2.2 事件 `CountdownAdd(name~, date~)` / `CountdownDelete(id~)` + FromJson 分支（snake_case：countdown_add/countdown_delete），验证：事件 JSON 往返断言
- [x] 2.3 归约：CountdownAdd 校验（trim 名称非空 + validate_countdown_date，失败 notify_error）成功 append + Save + 视图重算；CountdownDelete（不存在 id notify_error）成功移除 + Save；`WidgetToggle` 增加 "countdown" 分支，验证：单元测试覆盖规格"倒数日管理"全部 Scenario
- [x] 2.4 `TickDate` 联动：更新 today 并重算 countdown_views（不 Save），验证：单测先加 2026-09-11 目标（今天 2026-09-10 显示剩余 1），tick 到 2026-09-11 后视图变 0

## 3. 壳层（web/）

- [x] 3.1 倒数日小组件渲染分区：卡片列表（名称+天数徽章+删除）、空列表占位、添加表单（名称 + 原生 date input），"就是今天/已过 N 天"文案，验证：headless 断言渲染结构
- [x] 3.2 设置区 widgets 面板加"倒数日"开关（复用现有开关样式与 aria 模式），验证：headless 断言开关存在、切换生效且持久
- [x] 3.3 test-harness.html 同步 mirror 上述 UI，验证：与 3.1/3.2 一并断言

## 4. 端到端验证

- [x] 4.1 e2e.mjs：countdown_add（成功/空名/坏日期）、countdown_delete、widget_toggle countdown、tick_date 天数变化断言，验证：`node e2e.mjs` 全绿
- [x] 4.2 headless.cjs：小组件渲染、添加/删除交互、开关、跨日（harness 直接 dispatch tick_date）断言（reduced-motion 双运行），验证：`node headless.cjs` 全绿
- [x] 4.3 基线回归：`moon test` + `moon info` + `moon fmt` 干净；旧配置文件导入兼容（无 countdowns 字段）e2e 断言

## 5. 文档与规格

- [x] 5.1 openspec validate countdown-widget 通过；feat 提交时 sync countdown-widget 新主 spec 与 configuration 主 spec（MODIFIED 两处）
- [x] 5.2 README 功能表加倒数日行、测试数字刷新；申报书"本次赛期新增"已完成项勾稽（实现完成后）
