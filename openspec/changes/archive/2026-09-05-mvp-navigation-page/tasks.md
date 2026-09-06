# Tasks: mvp-navigation-page

## 1. 工程骨架与 FFI Spike

- [x] 1.1 初始化 MoonBit 模块（moon.mod.json；src/main、src/model、src/lunar、src/store 四个 package）与 web/ 壳（最小 index.html/style.css/app.js），运行 `moon check` 通过、静态页面可被本地服务器打开
- [x] 1.2 Spike：wasm-gc 目标下导出 `init`/`dispatch`（先做 echo 实现），JS 侧完成实例化与字符串往返；在浏览器 console 验证全链路。若一个会话内无法打通，按 design D3 降级 `--target wasm` 并在任务记录决策
- [x] 1.3 编写构建脚本（`moon build` + 拷贝产物至 web/wasm/），验证改一行 MoonBit 代码后重跑脚本、刷新页面能看到变化

## 2. 数据模型与状态核心（MoonBit）

- [x] 2.1 实现 Config 数据模型（version/bookmarks/search/widgets/wallpaper，见 design D6）与 JSON 编解码；`moon test` 验证 decode→encode 往返一致，且非法 JSON 返回错误而非崩溃
- [x] 2.2 实现网址补全与校验（缺协议补 `https://`；空/无效网址拒绝）；`moon test` 覆盖 `example.com`→`https://example.com`、空串、非法串
- [x] 2.3 实现 store 的 `(state, event) -> (state, effects)`：默认配置 + bookmark_add/edit/delete、engine_select、widget_toggle、wallpaper_set、search_submit（产出 open_url）、config_import、tick_date；每个事件一条 `moon test` 断言状态变化或产生的 effect
- [x] 2.4 验证每次状态变更都产出 `save_to_storage` 副作用（config_import 后同样触发），`moon test` 覆盖至少三类事件

## 3. 农历模块（MoonBit）

- [x] 3.1 实现农历数据表（1900-2100）与公历→农历换算（月、日、闰月标示、干支年）；`moon test` 黄金用例：2025-01-29→乙巳年正月初一、2025 闰六月区间样本、1900-01-31 与 2100-12-31 边界、范围外返回"不支持"
- [x] 3.2 将农历与星期接入状态：init 与 tick_date 事件计算当前日期的农历/星期并写入状态；`moon test` 用注入日期验证

## 4. 桥与渲染壳（JS）

- [x] 4.1 实现 app.js 桥：加载 wasm → 读 localStorage 喂 `init` → dispatch 循环 → 执行 effects（save_to_storage 落盘、open_url 跳转）；手动验证：console 触发一次事件后 localStorage 内容更新
- [x] 4.2 实现分区渲染（design D5）：时钟区（JS 秒级走动 + 状态中的农历/星期）、搜索区（输入期间不重绘）、书签区（事件委托）；手动对照 clock-widget spec 的三个场景
- [x] 4.3 实现书签 UI：网格展示、添加/编辑/删除表单（含网址校验错误提示）、空状态引导、favicon onerror 首字符回退；手动对照 bookmark-grid spec 全部场景

## 5. 搜索与配置 UI

- [x] 5.1 实现搜索框：预置百度/Google/Bing 三引擎、引擎切换立即生效、空关键词不跳转、当前页跳转结果页、打开页面自动聚焦、引擎选择持久；手动对照 search-box spec 全部场景
- [x] 5.2 实现设置面板：小组件开关（时钟、书签网格）、内置壁纸选择（web/wallpapers/ 预置若干张）、本地上传（canvas 压缩长边≤1920/JPEG~0.8、拒绝非图片文件）；手动对照 configuration spec 对应场景
- [x] 5.3 实现导入导出：导出下载含 version 字段与全部配置的 JSON（自定义壁纸 base64 内嵌）；导入整体替换、非法文件报错且现状不变；用导出文件作夹具手动验证两个场景

## 6. 收尾与验收

- [x] 6.1 体积与启动检查：记录 wasm 产物与 web/ 资源总体积、首屏无白屏/无明显延迟；若 wasm 明显超预期（>200KB 量级），复核 D3 降级路径并记录结论
  - 记录：wasm debug 155,208 B → release 62,667 B；web/ 全部资源 ~101 KB；远低于 200 KB 阈值，wasm-gc 路径保留（无降级）。首屏渲染经 headless 浏览器验证无报错。
- [x] 6.2 按 4 个 spec 的全部 Scenario 逐条手动验收（bookmark-grid、clock-widget、search-box、configuration），在任务记录中勾对结果
  - clock-widget：加载显示时间/秒级走动/日期星期 ✓（headless）；2025-01-29→乙巳年正月初一、2025 闰六月、范围外降级 ✓（moon test + e2e）
  - bookmark-grid：展示/新标签打开/空状态/https 补全/无效拒绝/编辑/删除/图标回退 ✓（headless harness + moon test）
  - search-box：多引擎/切换立即生效/空关键词不跳转/当前页跳转（URL 构建 e2e 验证；实际跳转行为为单行 `location.href`）/引擎持久 ✓；自动聚焦 ✓（harness）
  - configuration：开关即时+持久 ✓、内置壁纸 ✓、上传（真实 canvas 压缩路径）✓、拒绝非图片 ✓、localStorage 持久化+init 恢复（e2e）✓、导出含 version（e2e；浏览器下载动作未自动实测）/导入整体替换 ✓、非法导入报错且不变 ✓
  - 留给人工确认项：真实视觉观感、搜索实际跳转体验、导出文件实际下载、文件选择对话框交互（自动化已覆盖其后的全部逻辑层）
- [x] 6.3 最终回归：`moon test` 全绿、`moon check` 无告警、静态服务器完整冒烟一遍（刷新持久化、离线加载页面可用）
  - 记录：moon test 37/37；moon check 0 errors 0 warnings；headless 浏览器（Edge）渲染检查 10/10 + 交互 harness 34/34 + FFI e2e 18/18 全部通过。验证工具保留于 e2e.mjs / headless.cjs / web/test-harness.html。
