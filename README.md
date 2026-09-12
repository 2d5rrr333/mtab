# mtab · MoonBit 导航起始页

[![CI](https://github.com/2d5rrr333/mtab/actions/workflows/ci.yml/badge.svg)](https://github.com/2d5rrr333/mtab/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)

一个 iTab 风格的浏览器起始页：**全部业务逻辑——状态机、事件归约、农历换算、书签文件解析、检索评分、配置模型与 JSON 编解码——由 MoonBit 编译为 wasm-gc 承担**，HTML/CSS/JS 只是约 1,000 行的轻渲染壳。零后端、零第三方依赖，数据全部保存在 localStorage，离线可用。

mtab 是两个生态包的**参考应用**（dogfooding）：桥协议层来自 **[moonbridge](https://github.com/2d5rrr333/moonbridge)**（`moon add 2d5rrr333/moonbridge`，泛型 Session + 浏览器运行时，"wasm 拥有状态、JS 只是薄壳"架构的可复用实现），测试工具链为 **[moonwebtest](https://github.com/2d5rrr333/moonwebtest)**。

![screenshot](docs/screenshot.png)

## 功能

| 功能 | 说明 |
|---|---|
| 时钟小组件 | 公历日期时间 + 农历 + 干支/星期（1900–2100，纯 MoonBit 换算）+ 24 节气天文历算 + 节日徽章 |
| 书签网格 | 增删改、favicon 图标 + 首字回退、新标签打开；分组管理与指针拖拽排序、分组折叠记忆；首次使用预置常用站点 |
| 书签导入 | 浏览器导出的 Netscape 书签 HTML（Chrome/Edge/Firefox）一键导入：容错解析、实体还原、同名分组合并、URL 去重 |
| 倒数日小组件 | 自定义目标日（生日/考试/纪念日），显示剩余天数（还有 N 天 / 就是今天 / 已过 N 天）；跨年闰年按真实日历计算，跨日自动刷新 |
| 多引擎搜索 | 百度 / Bing / Google 一键切换，回车当前页跳转；历史联想（trie + 半衰期评分）+ 拼音联想（全拼/首字母） |
| 壁纸 | 4 张内置 SVG + 本地上传（长边 1920px 压缩、JPEG 80%）；双层层叠 crossfade 淡入（先解码后淡入，避免大图硬弹） |
| 个性化 | 小组件显隐开关；深/浅/自动主题令牌；壁纸模糊度；全部配置 localStorage 持久化；离线可用 |
| 配置迁移 | 一键导出/导入 JSON，自定义壁纸以图像数据内嵌，文件自足可迁移 |
| 无障碍与呈现 | `prefers-reduced-motion` 全局动效关停、键盘 `focus-visible` 轮廓、跨平台中文字体回退链、SVG favicon |

## 架构

```
┌─────────────────────────── 浏览器 ────────────────────────────┐
│  index.html · style.css       app.js（渲染壳，~1,000 行）      │
│      ▲ 按分区重绘                  │ 事件 JSON / 响应 JSON     │
│      │                            ▼                           │
│   DOM 事件 ────────▶ wasm.mtab_dispatch ────▶ MoonBit store   │
│                        (wasm-gc)          （唯一的决策点）     │
│                                              │ effects        │
│  localStorage ◀── save ──────────────────────┘ open_url /     │
│                              toast / notify_error 由渲染壳执行 │
└────────────────────────────────────────────────────────────────┘
```

- **MoonBit 是唯一的决策点**：单一 store 把每个事件归约为「新状态 + 副作用列表」；JS 壳只收集事件、重绘、执行副作用，从不做 store 能做的决定
- **桥协议层来自 [moonbridge](https://github.com/2d5rrr333/moonbridge)**：`src/main/main.mbt` 只做 Session 组装（约 40 行），信封序列化 / 事件解码兜底 / 错误路径全部由生态包承担；`web/vendor/moonbridge.mjs` 运行时负责 wasm 加载、dispatch 循环与副作用分发
- **渲染分区**：时钟 / 引擎栏 / 书签网格 / 壁纸各自独立重绘；搜索框永不重绘，焦点与草稿不丢
- **桥协议**：`mtab_init(stored, today)` 与 `mtab_dispatch(event)` 两个导出，字符串 JSON 往返，未初始化/非法事件返回 `notify_error` 而非崩溃

## 快速开始

前置条件：

- [MoonBit](https://docs.moonbitlang.com) 工具链 ≥ 0.10.7
- Node.js ≥ 20（跑 e2e）
- PowerShell 7（`build.ps1`；非 Windows 平台见下方手动步骤）

```bash
git clone https://github.com/2d5rrr333/mtab
cd mtab
./build.ps1 -Release        # moon build --target wasm-gc 并暂存产物到 web/wasm/
npx serve web               # 或 python -m http.server 8000 -d web
```

打开 http://localhost:8000（wasm 经 `fetch` 加载，`file://` 协议打开无效）。

非 Windows 手动构建：`moon build --target wasm-gc --release`，然后把
`_build/wasm-gc/release/build/main/main.wasm` 复制到 `web/wasm/main.wasm`。

## 测试与 CI

| 层 | 命令 | 覆盖 |
|---|---|---|
| 单元测试 | `moon test` | store 事件归约、Netscape 书签解析、倒数日日期运算、模型 JSON 往返、URL 归一化、农历换算（含闰月、春节边界）、桥协议 wire format（@moonwebtest/check）—— 162 项 |
| e2e | `node e2e.mjs` | 真实 wasm 实例过 FFI 桥逐事件断言（驱动器来自 @moonwebtest bridge-harness，vendored 于 `tools/`）—— 63 项 |
| headless | `node headless.cjs` | Edge headless 双运行（正常 + `--force-prefers-reduced-motion`）：渲染检查 13 项 + 交互/样式断言 —— 127 + 129 项（需 Chromium 系浏览器） |

GitHub Actions（`.github/workflows/ci.yml`）在每次 push / PR 上执行
`moon check` → `moon fmt --check` → `moon test` → `build.ps1 -Release` → `node e2e.mjs`，并上传可部署的 `web/` 产物。

## 项目结构

```
├── moon.mod              # 2d5rrr333/mtab 模块定义（deps: 2d5rrr333/moonbridge）
├── build.ps1             # wasm 编译 + 产物暂存（跨平台）
├── src/
│   ├── main/             # wasm 导出：mtab_init / mtab_dispatch（Session 组装）
│   ├── store/            # 状态树、事件归约、副作用队列、导入归并、倒数日视图
│   ├── model/            # 配置/书签/引擎/壁纸/倒数日模型、JSON 编解码、Netscape 解析
│   ├── pinyin/           # 无声调拼音表（~2000 常用字）
│   ├── trie/             # 字符前缀 trie（历史联想检索）
│   └── lunar/            # 公历↔农历换算、节气天文历算（1900–2100）
├── web/                  # 渲染壳：index.html · style.css · app.js · vendor/moonbridge.mjs · 壁纸 · favicon
├── e2e.mjs               # FFI 桥 e2e（Node，驱动器为 moonwebtest bridge-harness）
├── headless.cjs          # headless 渲染/交互验证（运行时为 moonwebtest headless runner）
├── tools/                # vendored 测试工具链（github.com/2d5rrr333/moonwebtest）
└── openspec/             # 行为规格（4 个 capability）与变更档案
```

## 工程过程：规格驱动

本仓库采用 OpenSpec 规格驱动流程开发：`openspec/specs/` 下 5 个 capability
（`clock-widget` / `bookmark-grid` / `search-box` / `configuration` / `countdown-widget`）的行为规格先行，
每个变更（proposal → design → tasks → 验收记录）归档于 `openspec/changes/archive/`，
开发动机、技术决策与验证结果完整可追溯。

## 第三方来源说明

- **农历换算算法**移植自 [solarlunar 3.1.0](https://github.com/yize/solarlunar)（MIT License）；
  修改点：干支年名跟随农历年（春节切换），与常见历书展示一致。详见 `src/lunar/lunar.mbt` 头部注释。
- 其余代码均为本项目原创；内置壁纸为自制 SVG；无第三方 MoonBit / JS 运行时依赖。

## License

[Apache-2.0](LICENSE)
