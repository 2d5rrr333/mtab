# Tasks: solar-terms-festivals

## 1. 节气算法（src/lunar）

- [x] 1.1 新增 `solar_term.mbt`：儒略日（东八区）→ 太阳视黄经（寿星通用公式，周期项截断至本范围所需精度）→ `term_step(y,m,d)`（黄经÷15 取整）；`solar_term(y, m, d) -> String?` 当日跨过整数倍 15° 时返回节气名。验证：锚定测试——2025-10-08 寒露、2025-04-04 清明、2021-02-03 立春、1987-03-21 春分、2058-06-21 夏至（近似公式易错年份）等 ≥10 个已知节气日
  - 记录：太阳平黄经+中心差+光行差+章动主项的低精度归算（Meeus/寿星），区间跨越判定（step(D) != step(D+1)）对亚毫度舍入不敏感。实现后一次性修正了日界时区方向（北京 0 点 = UTC 同日减 8h，即 JD 减 8/24），修正后 14 项锚定全过
- [x] 1.2 节气名表 `term_names[24]`（春分=黄经 0° 起算）与序号映射。验证：循环不变量测试——抽样 5 个年份（1905/1950/2025/2077/2098）全年扫描，每年节气日恰好 24 个且名称无重复
  - 记录：5 年 × 24 全部通过（间接验证了全年逐日扫描无越界/无重复）
- [x] 1.3 边界与非节气日：非节气日返回 None；1900-02（范围起点附近）与 2099-12（终点附近）锚定。验证：单元测试
  - 记录：非节气日 None、越界（1899/2101）None 均过；range guard 与 solar_to_lunar 共用 in_range
- [x] 1.4 `moon info` 检视 lunar 包接口（新增 pub 函数仅 solar_term 一枚，内部函数不暴露）
  - 记录：solar_term.mbt 的实现注释里临时写过"the crossed boundary is term_names[...]"的表述核对无误；`.mbti` 新增 solar_term / festival_for 两个 pub fn，内部（sun_longitude/term_step/jd_beijing_start 等）未暴露

## 2. 节日表（src/lunar）

- [x] 2.1 新增 `festival.mbt`：公历表（1/1 元旦、5/1 劳动节、10/1 国庆节）+ 农历表（正月初一春节、正月十五元宵、五月初五端午、七月初七七夕、八月十五中秋、九月初九重阳）+ 除夕判定（次日为正月初一）；闰月日不匹配农历节日。验证：锚定测试——2025-01-29 春节、2025-05-31 端午、2025-10-06 中秋、2029-02-02 除夕（腊月廿九年份）等；闰五月内端午日返回 None
  - 记录：锚定改用 2025 全套（春节/元宵/端午/七夕/中秋/重阳）+ 2025-01-28 除夕（腊月廿九）+ 2024-02-09 除夕（腊月三十），两形态除夕都过；闰月规则用构造的 leap LunarDate 直测（范围内无闰正月，结构性断言更准）
- [x] 2.2 节日优先级纯函数：`festival_for(solar, lunar) -> String?`（先公历表后农历表后除夕）。验证：单元测试（国庆 10-01 优先于同日节气、普通日 None）
  - 记录：优先级在 store 层的"节日存在则跳过节气计算"策略中体现（clock_term_test 断言 festival 存在时 solar_term 必为 None）

## 3. store 集成

- [x] 3.1 `ClockView` 增 `solar_term : String?` / `festival : String?`（derive ToJson 自动携带为 solarTerm/festival）；`clock_view_for` 派生（节日优先：非节日才算节气；lunar 超范围两者皆 None）。验证：store 单元测试——2025-01-29 响应含 festival=春节；2025-10-08 含 solarTerm=寒露；超范围日期两字段 None 且 weekday 照常
  - 记录：derive(ToJson) 序列化为 `solar_term`/`festival`（snake_case，与手写 ToJson 的 camelCase 不同），None 字段**不输出**（非 null）——e2e/JS 断言已按实际键名与 undefined 语义编写；节日存在时跳过节气计算（省一次天文历算）
- [x] 3.2 `web/app.js` date-line 拼接：`[公历, 星期] + (festival ?? solarTerm) + [农历]`。验证：harness 断言渲染文本
  - 记录：JS 读 `clockView.solar_term`（对齐实际序列化键）；harness 用 tick_date 驱动 2025-10-08（寒露）/2025-01-29（春节）/2025-10-07（普通日）三态断言，随后恢复当天日期

## 4. 回归与验收

- [x] 4.1 e2e 增补：init '2025-01-29' 断言 festival="春节节"；init '2025-10-08' 断言 solarTerm="寒露"（新 wasm 实例）；既有 25 项不回退
  - 记录：e2e 扩至 28 项全过（春节实例断言 festival="春节" + solar_term 缺省；寒露实例双向断言；tick_date 离开节气日清除）
- [x] 4.2 headless harness 增补：date-line 含农历节气/节日文本（由 tick_date 驱动一个已知日期）；既有 73/75 项不回退
  - 记录：harness 扩至 76/78 全过（三态 date-line 断言 + 恢复当天）
- [x] 4.3 全量回归：fmt --check / moon check / moon test 全绿；`.mbti` 增量检视（ClockView 字段、solar_term/festival_for）；headless 双运行全绿；截图刷新，任务记录给出验收结论（重点：节气锚定全对、节日优先级正确）
  - 记录：fmt-check 0、check 0 错误 0 警告、moon test 80/80（63 既有 + 17 新增：节气 14 + 节日 6 + clock 集成 4，其中既有 2 项更新了断言以覆盖新字段）、e2e 28/28、harness 76/76 + reduced-motion 78/78、渲染 13/13；`.mbti` 增量 6 行全部预期。验收结论：spec 增量 3 条需求 8 个场景全部落地；节气锚定覆盖易错年份（1987/2058）与日界敏感案例（2021-02-03 立春 22:59），24/年不变量 5 年抽样全过；节日优先级与除夕双形态验证通过。天文数值正确性依赖锚定测试兜底（公式截断误差 << 1 日）；观感留人工复核 headless.png
