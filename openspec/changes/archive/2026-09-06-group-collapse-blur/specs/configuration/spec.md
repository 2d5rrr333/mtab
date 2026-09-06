# configuration Delta

## ADDED Requirements

### Requirement: 壁纸模糊度调节
用户必须能够在设置面板调节壁纸模糊度（0 至 20 的连续值）；调节立即作用于壁纸显示并持久保存；超出范围的值必须被钳制到有效区间，不得报错。

#### Scenario: 调节模糊度
- **WHEN** 用户将模糊度滑杆从 0 调到 8
- **THEN** 壁纸立即以 8px 模糊显示，刷新后仍保持

#### Scenario: 越界钳制
- **WHEN** 传入的模糊度小于 0 或大于 20
- **THEN** 取值被钳制到 0 或 20，正常生效不报错
