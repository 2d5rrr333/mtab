# Design: ui-a11y-polish

## Context

ui-polish 已交付双层 crossfade（D4）、hover 过渡、弹窗动画等呈现层打磨并归档；本轮处理其明确排除的收尾项与一个新发现的边缘缺陷。约束不变：MoonBit 与桥协议零改动，全部改动落在 `web/` 呈现层与渲染壳展示函数。四个 capability 的规格均为行为级（壁纸"立即生效"指选择即生效，不约束呈现动画——ui-polish 已以 400ms 淡入确立此解读）。

## Goals / Non-Goals

**Goals:**

- 修复 crossfade 大图硬弹出：解码完成后再淡入，失败降级立即应用
- 滚动条在页面级与弹窗内均呈现为贴合毛玻璃质感的圆角半透明细条
- 字体栈覆盖 macOS/Linux 中文平台与 emoji 回落，无网络字体加载
- favicon 落地（SVG 文件 + link + theme-color），headless 可验证可达
- `prefers-reduced-motion: reduce` 下全部动效瞬时完成，且以真实 flag 运行验证

**Non-Goals:**

- 设计令牌（`--vars`）重构、图标回退配色（维持 ui-polish 排除决定）
- 布局、组件结构、任何视觉以外的行为变化
- Firefox 上的精细滚动条样式（标准属性兜底即可，非目标平台）

## Decisions

### D1. crossfade 硬弹出修复：decode 后再淡入 + 请求序号守卫

现状缺陷：`applyWallpaper` 设置 `backgroundImage` 后立即加 `.visible`，不等图片加载；大图（自定义上传 1920px JPEG data URL）解码完成时淡入早已结束，图片"啪"地硬弹出。

修复：`applyWallpaper` 内先 `new Image()` + `await img.decode()`，resolve 后再执行既有"写后备层 → 加 `.visible` → 450ms 后退场旧层"流程：

- **竞态守卫**：decode 是异步等待，期间用户可能再次切换壁纸。引入单调递增的请求序号（token），decode 完成后若 token 已过期则丢弃本次结果。既有代码的 `prev !== activeWallpaperLayer` 守卫处理退场侧，序号处理入场侧。
- **失败降级**：`decode()` reject（data URL 损坏、格式异常）时直接应用不等待——壁纸"立即生效"（configuration spec）不被阻塞。本地 SVG 与同源小图 decode 通常 <100ms，正常路径无可感延迟。
- **函数签名**：`applyWallpaper` 变 async，`renderAll` 调用点不 await（fire-and-forget），渲染管线时序不变；首次加载行为从"立即淡入"变为"解码后淡入"，避免首屏大图硬弹，属预期改善。

备选（否决）：CSS `transition-behavior` / `@starting-style`——不解决"解码晚于动画结束"的根因；Canvas 手动绘制混合——复杂度高收益低。

### D2. 滚动条：`::-webkit-scrollbar` 为主，`@supports not selector(...)` 放标准属性

```
html ── ::-webkit-scrollbar          width/height 10px，track 透明（壁纸透出）
      ├─ ::-webkit-scrollbar-thumb   圆角 999px，rgba(255,255,255,.28)，
      │                              2px 透明 border + background-clip: content-box
      │                              （视觉细于 10px 轨道、离边缘有间距），hover .45
      └─ @supports not selector(::-webkit-scrollbar)
                                     scrollbar-width: thin;
                                     scrollbar-color: rgba(255,255,255,.4) transparent
```

关键坑：Chromium 121+ 中**非默认值的标准 `scrollbar-width`/`scrollbar-color` 会使 `::-webkit-scrollbar` 伪元素全部失效**，两者全局同设会互相打架。因此标准属性只写进 `@supports not selector(::-webkit-scrollbar)` 块——Chromium/Edge 走精细样式，Firefox 等走标准属性，互不干扰。作用域为全局（页面级滚动与 `.modal` 内滚动共用一套规则）。

备选（否决）：仅标准属性——不可定制圆角与轨道，观感收益减半。

### D3. 字体栈：中文平台链 + emoji 兜底，全系统本地字体

```
system-ui, -apple-system, 'Segoe UI',
'PingFang SC', 'Hiragino Sans GB', 'Microsoft YaHei',
'Noto Sans SC', 'Noto Sans CJK SC', 'WenQuanYi Micro Hei',
sans-serif, 'Apple Color Emoji', 'Segoe UI Emoji', 'Noto Color Emoji'
```

- 中文链顺序按平台：macOS（PingFang → Hiragino）→ Windows（YaHei，维持现状）→ Linux/Android（Noto SC → Noto CJK SC）→ 文泉驿兜底
- emoji 族置于 `sans-serif` 之后：字体匹配按字符回落，emoji 字形在前序族与通用族中均无命中时会继续尝试后面的具体族（书签名称可含 emoji）
- 全部为系统字体，零网络请求，无 FOUT 类延迟

### D4. favicon：独立 SVG 文件 + theme-color

- `web/favicon.svg`：深色圆角方底（取 `#1c1e26` 页面底色）+ 白色 `m` 字母（`<text>`，依赖系统字体渲染，favicon 语境可接受且文件最小）
- `index.html` 增加 `<link rel="icon" type="image/svg+xml" href="favicon.svg">` 与 `<meta name="theme-color" content="#1c1e26">`
- `headless.cjs` 既有 `.svg` MIME 映射直接复用；验证走 phase 1 DOM 检查（link 标签存在）+ Node 侧 `GET /favicon.svg` 断言 200
- `test-harness.html` 不加 favicon（测试页无此需求）

备选（否决）：data-URI 内联——HTML 变大、失去独立缓存、可读性差；`.ico` 多分辨率——目标平台 Edge/Chrome 支持 SVG favicon，无兼容包袱。

### D5. reduced-motion：全局 kill-switch，一条 media query 覆盖全部动效

```css
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
    transition-delay: 0ms !important;
    scroll-behavior: auto !important;
  }
}
```

- **为什么 blanket 而非逐条**：现有 7 类动效（壁纸淡入、modal-pop、backdrop-fade、toast-in、卡片抬升/缩放、按钮上浮、状态色过渡）分散在多个规则，逐条关停维护成本高且新增动效易漏；一条通配规则永久覆盖未来新增
- **0.01ms 而非 0**：保留 transitionend/animationend 事件触发（本项目 JS 不依赖，纯防御）
- **JS 侧不改**：crossfade 的 450ms 退场 timer 只是层清理；decode 等待是加载语义而非动效语义，均不属于 reduced-motion 管辖
- **验证**：harness 中以 `matchMedia('(prefers-reduced-motion: reduce)').matches` 为开关——命中时追加断言（`.wallpaper-layer` 的 transition-duration ≈ 0.01ms、`.toast` animation-duration ≈ 0.01ms），未命中时该段自动跳过。这样同一份 harness 在正常与 `--force-prefers-reduced-motion` 两种 Edge 运行下都全绿，`headless.cjs` 只需为 harness phase 增加一次带 flag 的运行

备选（否决）：targeted 关停（保留 hover 状态色变化）——hover transform 属于应关停的范畴，精细名单反而引入争议与遗漏面。

## Risks / Trade-offs

- [decode 等待期间连续切换壁纸产生竞态] → 请求序号守卫，过期 decode 结果直接丢弃（D1）
- [Chromium 标准 scrollbar 属性使 webkit 伪元素失效] → 标准属性仅写入 `@supports not selector(::-webkit-scrollbar)`，与 webkit 伪元素互斥分层（D2）
- [headless 虚拟时间下 decode 立即完成，无法测"慢图"时序] → 断言聚焦：正常路径既有三条 crossfade 断言不回退 + 构造必然 decode 失败的 URL 验证降级路径立即应用（D1）
- [SVG favicon 在不支持的环境不渲染] → 目标平台（Edge/Chrome）均支持；无 fallback 必要，不引入 `.ico` 复杂度
- [blanket kill-switch 误伤"功能性"动画] → 项目内无功能性动画（无 spinner、无进度指示）；JS 不依赖动画事件
- [字体栈变长引起渲染延迟] → 全部系统本地字体，无网络加载，逐字符回落成本可忽略

## Migration Plan

纯 `web/` 改动：wasm 与 `build.ps1` 不涉及，刷新页面即生效。回滚 = revert 5 个修改文件、删除新增的 `favicon.svg`。

## Open Questions

（无）
