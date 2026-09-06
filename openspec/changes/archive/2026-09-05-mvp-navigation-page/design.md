# Design: mvp-navigation-page

## Context

全新空仓库（无既有代码）。本设计基于 proposal 的范围：纯网页 MVP，MoonBit 承担业务逻辑/状态/存储，DOM 与 UI 由 HTML+CSS+JS 完成，FFI 桥接。硬约束：wasm 包体积可控、页面启动速度快、先可运行 demo 后美化。不引入 rabbita 等任何第三方依赖。

## Goals / Non-Goals

**Goals:**

- 一条清晰、可测试的 FFI 边界：wasm 是纯逻辑核心（输入事件 → 输出状态+副作用意图），不直接触碰任何浏览器 API
- 状态只有一份真相（wasm 内的单一状态树），localStorage、导出文件、桥上传输共用同一 JSON 形态
- 零外部依赖、零构建工具链（产物即静态文件），任何静态服务器可直接托管
- MoonBit 侧逻辑全部可用 `moon test` 离线测试（不需要 DOM）

**Non-Goals:**

- VDOM / 声明式 UI 框架（MVP 用分区重绘足够）
- 响应式深度优化与移动端专项适配（自然自适应即可）
- 多张自定义壁纸管理（MVP 至多一张当前自定义壁纸）
- 备忘录、倒计时、主题切换、拖拽排序、天气、扩展形态（见 proposal 排除项）

## Decisions

### D1. 总体架构：单向数据流，wasm 为大脑，JS 为手脚

```
        ┌────────────────── 浏览器 ──────────────────┐
        │  index.html + style.css + app.js（渲染壳）    │
        │                                            │
        │  事件采集        DOM 更新         副作用执行   │
        └────┬──────────────▲──────────────────┬─────┘
             │ event JSON    │ state +          │ effects
             ▼               │ effects JSON     │ (open_url /
        ┌────────────────────┴──────────────────▼─────┐
        │  wasm（MoonBit）：dispatch(event)             │
        │  ├─ model：Config 数据模型 + JSON 编解码      │
        │  ├─ lunar：农历换算（纯函数）                  │
        │  └─ store：状态树 + 更新逻辑 + 持久化意图      │
        └─────────────────────────────────────────────┘
```

- JS 壳职责仅三类：采集用户事件并调用 `dispatch(event_json)`；按返回的新状态重绘受影响分区；执行返回的副作用列表（`open_url`、`save_to_storage`、`download_json` 等）。
- wasm 不 import 任何浏览器 API（localStorage、定时器、跳转全在 JS 侧）。收益：wasm 核心是纯函数式的 `(state, event) -> (state, effects)`，`moon test` 可全覆盖。
- 备选方案（否决）：MoonBit 通过 FFI 反向调用 JS DOM API 主动渲染——FFI 面扩大、JS 壳不再"薄"、事件回调注册复杂，与"MoonBit 管逻辑、DOM 交给 JS"的分工相悖。

### D2. 桥上协议：全量状态 JSON + 副作用列表

- `dispatch` 返回 `{ "state": <全量配置状态>, "effects": [ ... ] }`。MVP 状态体量小（KB 级），不做增量 diff。
- 状态 JSON 同时是 localStorage 持久化格式和导出文件格式（含 `version` 字段），一式三用，避免多套编解码。
- 事件是封闭枚举，在桥上以带 `type` 标签的 JSON 表达：`bookmark_add / bookmark_edit / bookmark_delete / engine_select / search_submit / widget_toggle / wallpaper_set / config_import / tick_date` 等。
- 备选（否决）：二进制协议（体积更优但调试困难、与导出格式割裂，MVP 不值）。

### D3. 编译目标：wasm-gc 为主选，wasm（带 glue）为降级路径

- wasm-gc 无运行时、体积最小，契合"包体积 + 启动速度"硬约束，也是 MoonBit 当前默认目标。
- 风险点是 JS↔wasm 字符串互操作的成熟度：**实施第一个任务即为此做 spike**（init/dispatch 全链路字符串往返）。若复杂度超预期，降级为 `--target wasm`（moon 生成 JS glue），架构不变，只换加载器。
- Chrome MV3 CSP 兼容性本次不验证（见 proposal 排除项）。

### D4. 时钟渲染分工：秒级跳动在 JS，农历/星期来自 wasm

- 时:分:秒 的走动是纯展示，由 JS 本地 `setInterval` 更新 `textContent`，不跨 FFI。
- 农历换算与星期是真正的业务逻辑，由 wasm 在 init 与日期变更时计算并写入状态（`tick_date` 事件每日触发一次）。
- 备选（否决）：每秒 `tick` 事件穿越 FFI 并回传全量状态——白白放大 FFI 流量与 JSON 开销。

### D5. 渲染策略：分区重绘 + 事件委托

- 页面按 widget 分区（header 时钟区、搜索区、书签区、设置面板区），每次状态变化只重绘受影响分区。
- 搜索框输入过程中不重绘搜索分区，避免焦点丢失（配合 spec 的自动聚焦要求）。
- 书签网格用事件委托绑定交互，避免逐节点挂监听。
- 备选（否决）：自写 VDOM——MVP 规模下纯增量成本。

### D6. 数据模型（配置 schema，version 1）

```json
{
  "version": 1,
  "bookmarks": [ { "id": "b1", "name": "示例", "url": "https://example.com" } ],
  "search": {
    "engines": [ { "id": "baidu", "name": "百度", "urlTemplate": "https://www.baidu.com/s?wd={query}" },
                 { "id": "google", "...": "..." }, { "id": "bing", "...": "..." } ],
    "current": "baidu"
  },
  "widgets": { "clock": true, "bookmarks": true },
  "wallpaper": { "type": "builtin", "id": "w1" }
}
```

- 自定义壁纸：`{ "type": "custom", "data": "data:image/jpeg;base64,..." }`，与内置壁纸互斥（新上传覆盖旧自定义壁纸）。
- 导入 = 整体替换（不做合并），与 spec"完整恢复"一致。
- 上传时用 canvas 压缩（长边 ≤1920px、JPEG 质量 ~0.8）再转 base64，控制 localStorage 占用（总配额约 5MB）。
- MoonBit 侧以 struct + enum 建模，JSON 编解码用标准库支持（精确 API 以实施时 `moon ide doc` 验证为准）。

### D7. 农历：纯 MoonBit 实现（1900–2100）

- 数据表 + 换算算法全部用 MoonBit 写在独立 package `src/lunar`，离线可用、可做黄金测试集（如 2025-01-29 → 乙巳年正月初一；2025 闰六月区间）。
- 备选（否决）：复用 JS 农历库或联网 API——前者削弱"MoonBit 承担业务逻辑"的项目立意，后者违反离线约束。

### D8. 书签图标与搜索跳转

- 图标：`<img src="https://<domain>/favicon.ico">`，`onerror` 回退到名称首字符占位（符合 spec 的图标回退要求）。
- 搜索提交：当前页跳转到搜索引擎结果页（导航页使命完成）；书签点击：新标签页打开（spec 已定）。

### D9. 工程布局与发布流

```
mtab/
├── moon.mod.json
├── src/
│   ├── main/      # 入口：FFI 导出（init / dispatch）
│   ├── model/     # 配置数据模型 + JSON 编解码
│   ├── lunar/     # 农历换算（纯函数）
│   └── store/     # 状态树 + (state, event) -> (state, effects)
└── web/
    ├── index.html / style.css / app.js
    ├── wasm/      # moon build 产物（脚本拷入）
    └── wallpapers/ # 内置壁纸（静态资源，不进 localStorage）
```

- 构建即"编译 + 拷贝产物到 web/wasm/"，一个轻量脚本完成（PowerShell）；发布物 = `web/` 目录，零 Node 依赖。

## Risks / Trade-offs

- [wasm-gc 字符串互操作复杂度未知] → 首个任务做端到端 spike；失败即降级 `--target wasm`，架构与桥协议不变
- [localStorage 容量超限（自定义壁纸 + 书签累积）] → 上传前 canvas 压缩；保存包裹错误处理，超限时向用户提示而不静默丢失
- [农历数据表错误] → 黄金测试集覆盖岁首/岁尾/闰月/春节锚点；表数据来源需在实现时注明出处并交叉核对
- [分区重绘导致输入状态丢失] → 搜索分区输入期间不重绘；设置面板表单本地态与全局状态分离
- [全量状态 JSON 在书签量增大后变慢] → MVP 体量（几十个书签）无感知；若后续变慢，桥协议升级为增量，属增强迭代

## Open Questions

- ~~wasm-gc 下 JS↔wasm 传字符串的精确机制~~ **已解决（task 1.2 spike）**：`link: { "wasm-gc": { "use-js-builtin-string": true } }` 下 MoonBit String 即 JS string（externref）；JS 侧加载器用 `new WebAssembly.Module(bytes, { builtins: ['js-string'] })` + 手动物化 `_` 模块的字符串常量 imported globals（global 名即字面量内容），不依赖引擎的 `importedStringConstants` 支持。wasm-gc 路径保留，未降级。
