# Proposal: solar-terms-festivals

## Why

时钟组件目前只显示公历+农历日期，缺少 iTab 类产品的两个中式历法要素：二十四节气与传统/法定节日。这是申报书承诺的三项功能之一，且核心是真正的天文历算（寿星通用公式：太阳黄经法），是扩充 MoonBit 算法资产最有含金量的一块。

## What Changes

- **二十四节气计算**：`lunar` 包新增寿星通用公式实现（儒略日 → 太阳黄经 15° 倍数判定），支持范围与农历一致（1900–2100），当日为节气日时返回节气名（如"寒露"）
- **节日表**：公历法定节假日（元旦、劳动节、国庆等）+ 农历传统节日（春节、元宵、端午、七夕、中秋、重阳、除夕），返回当日节日名
- **时钟展示**：`ClockView` 派生字段扩展 `solar_term` / `festival`，日期行按"节日优先、节气次之"展示（同为节日日不叠加节气名）
- **纯派生视图**：无 config 字段变更、无新事件、零迁移——由 `clock_view_for` 在 init/tick_date 时派生

## Capabilities

### New Capabilities

（无）

### Modified Capabilities

- `clock-widget`: 新增"节气与节日显示"需求——节气换算准确性（权威万年历一致）、节日覆盖范围、展示优先级行为规格

## Impact

- **修改文件**：`src/lunar/`（新增 solar_term.mbt / solar_term_data.mbt / festival.mbt + 测试）、`src/store/store.mbt`（ClockView 两个字段 + clock_view_for 派生）、`web/app.js`（date-line 拼接优先级）、`web/test-harness.html`、`e2e.mjs`
- **不修改**：config 模型、事件枚举、桥协议、localStorage 格式、其他 capability
- **风险面**：寿星公式的数值正确性（以已知节气日锚定测试兜底）；浮点运算在 wasm-gc 的确定性（IEEE 754 双精度，确定性有保证）
