# Tasks: ui-a11y-polish

## 1. crossfade 硬弹出修复（web/app.js）

- [x] 1.1 `applyWallpaper` 改为"先解码后淡入"：`new Image()` + `await img.decode()`，resolve 后再写入后备层并加 `.visible`（退场逻辑不变）；引入单调请求序号守卫，decode 完成时若已有更新请求则丢弃本次结果；`decode()` reject 时降级为立即应用。验证：harness 既有 3 条 crossfade 断言（`.visible` 类切换、旧层退场、持久化）不回退
  - 记录：实现拆为 `applyWallpaper`（去重 + 记账 + 发起 decode）与 `revealWallpaper`（token 校验后执行原 reveal 流程）；`currentWallpaperImage` 改为请求时同步记录，保证等待期间的重复切换仍被去重。既有 3 条断言在正常与 reduced-motion 两种运行下均通过
- [x] 1.2 harness 增加降级路径断言：dispatch `wallpaper_set_custom` 携带必然 decode 失败的 data URL，断言活动层立即携带新图与 `.visible`（不阻塞"立即生效"）
  - 记录：用 `data:image/png;base64,###`（非法 base64）触发 decode reject；wasm 侧 `wallpaper_set_custom` 不校验 data 格式（校验在上传路径），dispatch 直达。断言通过

## 2. CSS 三项（web/style.css）

- [x] 2.1 滚动条：全局 `::-webkit-scrollbar`（10px 轨道、track 透明、thumb 圆角 999px `rgba(255,255,255,.28)` + 2px 透明 border `background-clip: content-box`、hover 加深至 .45）+ `@supports not selector(::-webkit-scrollbar)` 块内 `scrollbar-width: thin; scrollbar-color: rgba(255,255,255,.4) transparent`（标准属性与 webkit 伪元素互斥分层，design D2）。验证：harness CSSOM 断言两类规则存在且标准属性只出现在 @supports 块内
  - 记录：hover 规则需重申 `background-clip: content-box`（`background` 简写会重置 clip）。3 条断言（track 存在、thumb 样式、标准属性仅在 @supports 内）通过
- [x] 2.2 字体栈：`body` font-family 扩为 design D3 全链（PingFang SC / Hiragino Sans GB / Microsoft YaHei / Noto Sans SC / Noto Sans CJK SC / 文泉驿微米黑 / sans-serif 后接三个 emoji 族）。验证：harness 断言 computed `fontFamily` 含 `PingFang SC` 与 `Segoe UI Emoji`
  - 记录：断言通过（computed 序列化包含全部族名）
- [x] 2.3 `prefers-reduced-motion` 全局 kill-switch：`@media (prefers-reduced-motion: reduce)` 内通配 `animation-duration/transition-duration: 0.01ms`、`animation-iteration-count: 1`、`transition-delay: 0ms`、`scroll-behavior: auto`（design D5）。验证：harness 在 `matchMedia('(prefers-reduced-motion: reduce)').matches` 时断言 `.wallpaper-layer` transition-duration ≈ 0.01ms 且 `.toast` animation-duration ≈ 0.01ms；正常运行时该断言段自动跳过
  - 记录：kill-switch 规则存在断言两种运行都执行；效果断言仅在 matchMedia 命中时执行——`--force-prefers-reduced-motion` 运行下 2 条效果断言（65 = 63 + 2）通过，正常运行为 63 条自跳过

## 3. favicon（新增 web/favicon.svg + web/index.html）

- [x] 3.1 创建 `web/favicon.svg`：深色（`#1c1e26`）圆角方底 + 白色 `m` 字母居中；`index.html` 增加 `<link rel="icon" type="image/svg+xml" href="favicon.svg">` 与 `<meta name="theme-color" content="#1c1e26">`（design D4）。验证：浏览器直接打开 SVG 渲染正常（深底、圆角、m 居中）
  - 记录：SVG 用 `dominant-baseline="central"` 垂直居中（Chromium 支持）；自动验证由 headless 承担（link 存在 + GET 200 + svg MIME），浏览器直接打开的观感留人工过目

## 4. headless 工具与全量回归

- [x] 4.1 `headless.cjs` 扩展：harness phase 追加一次带 `--force-prefers-reduced-motion` 的 Edge 运行（复用同一 harness，matchMedia 开关段自动生效）；Node 侧增加 `GET /favicon.svg` 断言 200，phase 1 DOM 检查增加 `link[rel="icon"]` 存在。验证：两种 harness 运行（正常 + flag）title 均为 `HARNESS-PASS`
  - 记录：phase 2 重构为 `runHarness(label, extraArgs)` 复用；新增 favicon 200+MIME、link[rel=icon]、theme-color 三项检查。两种 harness 运行均 `ALL ... PASSED`（63 / 65）
- [x] 4.2 全量回归：`moon test` 37/37 不变、`e2e.mjs` 18/18 不变、渲染检查 10/10 不变、harness 既有 57 项断言不回退；刷新截图 `headless.png` 留人工过目，在任务记录中给出验收结论
  - 记录：moon test 37/37、e2e 18/18、渲染检查 13/13（原 10 + favicon 3 项新增）、harness 正常运行 63/63（既有 57 项全部保持 + 新增 6 项）、reduced-motion 运行 65/65（63 + 2 条效果断言）；截图已刷新（1280×800）。验收结论：五项待做项全部落地且可自动验证，MoonBit 侧零改动、`moon info` 无接口漂移；观感（favicon 字形居中、滚动条在真实内容溢出下的表现、字体在实际非 Windows 平台的回落）留人工复核
