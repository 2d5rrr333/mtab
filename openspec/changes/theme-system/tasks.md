# Tasks: theme-system

## 1. 模型与 store

- [x] 1.1 `Config.theme : String`（缺省 "dark"）+ `theme_set {theme}` 事件与 reducer（合法三值、非法拒绝、同值 no-op）。验证：store 单测（三值设置/非法拒绝/no-op/持久往返）
  - 记录：`theme_field` 解码缺失/非法值回落 "dark"；4 项测试全过（其中链式三步测试修正了一处自设的 no-op 陷阱）

## 2. 令牌化与主题应用（web/）

- [x] 2.1 style.css：`:root` 令牌集（深色默认）+ `[data-theme="light"]` 覆盖块；按映射表 replaceAll 替换全部颜色字面量；grep 清点无漏网。验证：`rg` 残留字面量清点 + 浏览器过目深色零变化
  - 记录：两轮修复——①replaceAll 误伤令牌定义块自身（自引用循环 + light 块错值），整体重写两块恢复；②`border:`/`background:` 简写含 var() 在 CSSOM 序列化为空串，改为 longhand（bm-empty 三段式、scrollbar thumb background-color）。故意保留字面量：徽章三色、bm-ops 深色芯片、toast、阴影系、drag 指示线（两主题下均落在确定底色上）
- [x] 2.2 `app.js`：`applyTheme()`（auto 解析 + dataset 写入）+ matchMedia change 监听（仅 auto 态生效）+ renderAll 接入。验证：harness 断言
  - 记录：resolveTheme 纯函数化；matchMedia 监听模块级一次性挂载
- [x] 2.3 设置面板外观分区（index + harness）三键分段选择器 + 接线 + active 同步。验证：harness 断言（浅色点击生效与持久、深色还原、auto 解析一致、CSSOM light 规则块存在）
  - 记录：5 项新断言全过（light token 块存在/html data-theme/持久+active/dark 还原/auto 解析）

## 3. 回归与验收

- [x] 3.1 断言适配（focus boxShadow / 滚动条 thumb 两处内容断言改存在性）；全量回归（109/43/99+101 基线不回退，新增计入新基线）；双主题截图；任务记录给出验收结论（重点：深色零回归、浅色可读性、auto 实时跟随）
  - 记录：moon test 113/113（+4）、e2e 43/43、harness 104/104 + 106/106（适配 2 + 新增 5）、fmt-check 0、`.mbti` 增量预期（theme 字段 + ThemeSet 事件）。验收结论：令牌化完成且深色视觉零变化（既有断言全过即证）；浅色令牌含 scrim 白纱反转与全套面板/滚动条/焦点环；auto 经 matchMedia 实时跟随（监听仅 auto 态生效）；匹配系统深浅的观感留人工复核截图
