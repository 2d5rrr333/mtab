# Tasks: group-collapse-blur

## 1. 模型与 store

- [x] 1.1 `Group.collapsed : Bool`（ToJson 恒写/FromJson 缺省 false，`bool_field_opt` helper）；`Config.wallpaper_blur : Int`（缺省 0，`int_field_opt`）。验证：model 单测（旧 v2 无字段读入默认、往返无损、默认组 collapsed=false）
  - 记录：+`WALLPAPER_BLUR_MAX = 20` 常量；修复过程中发现 Group::to_json 首次编辑未生效（编码冲突），由往返测试抓出后补写 collapsed 键——测试先行价值的直接体现
- [x] 1.2 事件 `group_toggle_collapse` / `wallpaper_blur_set`（JSON 解码）+ reducer（翻转 + Save / clamp + 变化才 Save）。验证：store 单测（折叠翻转、缺组 notify_error、blur clamp 两端、no-op 不 Save）
  - 记录：6 项新 store 测试全过；g0 可折叠（无保护必要，规格如此）

## 2. 渲染壳

- [x] 2.1 折叠按钮（▾/▸）+ `.bm-group.collapsed` 隐藏网格与空占位 + 点击 dispatch。验证：harness 断言（折叠后网格隐藏、localStorage collapsed 持久、再点展开）
  - 记录：折叠态由 groupNode 重建时从 state 恢复（刷新保持由 localStorage 天然承载）
- [x] 2.2 设置面板滑杆 + 值显示 + change dispatch；`applyWallpaperBlur` 幂等应用/移除壁纸层 filter。验证：harness 断言（filter 值 + 持久化 + 0 时无 filter）
  - 记录：序列化键为 `wallpaperBlur`（手写 ToJson camelCase 家族），JS 侧统一读 camelCase；0 时移除 filter 避免无谓合成层

## 3. 回归与验收

- [x] 3.1 e2e 增补两事件序列；全量回归（109 moon test / 43 e2e / 93+95 harness 基线不回退，新增计入新基线）；截图刷新；任务记录给出验收结论
  - 记录：moon test 109/109（+6）、e2e 43/43（+6；此前记账"45"系笔误，git 基线核实为 37+6）、harness 99/99 + 101/101（+6）、fmt-check 0、`.mbti` 增量符合预期（Group.collapsed / wallpaper_blur / 两事件 / WALLPAPER_BLUR_MAX）。过程事故：一次 PowerShell 批量替换把 e2e/app.js/harness 的中文毁成乱码（GBK/UTF-8 混写），git checkout 恢复后全部用 edit 工具重做；教训已固化——源文件永不走 PowerShell 字符串替换。验收结论：折叠记忆与模糊度调节全链路（model 持久化 → reducer clamp → UI 应用）三层验证覆盖，config v2 加法兼容成立
