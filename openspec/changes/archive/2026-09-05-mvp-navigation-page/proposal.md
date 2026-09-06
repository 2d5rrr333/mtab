# Proposal: mvp-navigation-page

## Why

mtab 是 MoonBit 9 月黑客松赛道一的参赛项目：用 MoonBit 打造一个类似 iTab 的浏览器导航起始页。作为全新项目，当前仓库还没有任何代码，需要一个明确定义的 MVP 来落地"可运行 demo 优先"的比赛交付。本 change 建立项目基线：纯网页形态（不做 Chrome 扩展），MoonBit 承担业务逻辑、状态与存储，DOM/UI 交给 HTML+CSS+JS，通过 FFI 桥接。

## What Changes

从零建立导航页 MVP，包含：

- **时钟小组件**：展示公历日期与时间，并显示对应农历日期
- **书签网格**：以图标网格展示常用站点，支持添加、编辑、删除书签
- **多引擎搜索框**：支持在多个搜索引擎之间切换并以所选引擎发起搜索
- **localStorage 持久化**：所有配置与书签数据持久保存，刷新后不丢失
- **小组件开关**：用户可开启/关闭各小组件的显示
- **壁纸**：支持从内置壁纸集中选择，也支持上传本地图片作为壁纸
- **配置 JSON 导入导出**：将全部配置导出为 JSON 文件，并可从文件导入恢复
- **工程骨架**：MoonBit 模块（编译为 wasm）+ 静态 HTML/CSS/JS 壳层的全新项目结构

本次迭代**不做**（明确排除）：

- 备忘录、倒计时、简单主题切换 → 归入后续增强迭代
- 拖拽排序、天气、浏览器扩展（含 Chrome MV3 CSP 风险验证）→ 移出本次迭代，扩展形态留待未来 spike
- 桌面端深度美化 → 先骨架后皮肉，优先保证可运行 demo

## Capabilities

### New Capabilities

- `clock-widget`: 时钟小组件——公历日期时间显示与农历换算展示
- `bookmark-grid`: 书签网格——常用站点的展示与管理（增删改、图标展示）
- `search-box`: 多引擎搜索框——搜索引擎切换与搜索跳转
- `configuration`: 个性化与配置——小组件开关、壁纸设置、localStorage 持久化、配置 JSON 导入导出

### Modified Capabilities

（无——全新项目，尚无既有 capability）

## Impact

- **新增代码**：MoonBit 模块（业务逻辑/状态/存储，编译目标 wasm）、静态网页壳层（index.html + CSS + JS 渲染层与 FFI 桥）、项目构建脚本
- **依赖**：不引入 rabbita 等 UI 框架；FFI 桥为手写边界
- **约束**：控制 wasm 包体积，保证页面启动速度（每次打开标签页都会加载）
- **不受影响**：无既有代码（全新项目）；Chrome MV3 CSP 兼容性风险本次不触碰
