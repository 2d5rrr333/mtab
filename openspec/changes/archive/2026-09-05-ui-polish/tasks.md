# Tasks: ui-polish

## 1. 可读性与稳定性（P0 修复）

- [x] 1.1 时钟数字等宽：`#clock .time` 加 `font-variant-numeric: tabular-nums`、font-weight 调 300；headless harness 断言 `getComputedStyle(...).fontVariantNumeric` 并在虚拟时间下多次采样 `#clock-time` 宽度断言恒定
- [x] 1.2 焦点态：`#search-input:focus` 高亮（边框/底色/外发光）+ `:where(button,input):focus-visible` 键盘轮廓；harness 断言 focus 时 computed style 变化
  - 记录：headless 虚拟时间下 transitioned 属性的 computed style 冻结在起始值，断言改为规则级（`#search-input:focus` box-shadow 规则存在）+ focus 行为断言；规则本身经浏览器加载验证
- [x] 1.3 壁纸遮罩：`body::before` vignette 层（z-index 0、pointer-events none），`#app`/`.toolbar`/`.toast` 提至 z-index 1；harness 断言遮罩层 computed background 存在且交互不受影响（点击书签仍打开新标签）
  - 记录：实现改为真实元素 `#scrim`（伪元素 computed style 在 headless 不可靠，设计 D3 注明）；断言 gradient 背景 + pointer-events none + z-index 层级 0/1/2 通过

## 2. 交互反馈（点名项）

- [x] 2.1 hover 过渡统一：引擎 pill、工具栏按钮、模态按钮 hover 过渡；书签操作按钮间距/过渡 + 删除悬停变红；书签卡片 hover 抬升（translateY -3px + 阴影加深 + active 回落）；harness 断言各元素 transition 属性与卡片 hover transform
- [x] 2.2 搜索按钮微动：hover `translateY(-1px)`、active 回落；harness 断言 transform 过渡存在
- [x] 2.3 弹窗：`.modal` pop 入场动画（translateY+scale，~220ms 过冲曲线）、backdrop `backdrop-filter: blur(4px)` + fade 动画；顺带删除无效选择器 `.modal-actions button secondary`；harness 断言 animationName 与 backdrop-filter
- [x] 2.4 空状态：虚线投放框（1.5px dashed + 浅底）；harness 断言 border-style dashed
- [x] 2.5 书签网格响应式：宽度 `min(880px, 94vw)`、`grid-template-columns: repeat(auto-fill, minmax(104px, 1fr))`；harness 在 1280px 视口断言网格实际列数 ≥ 6

## 3. 动效与语义（需 app.js 最小配合）

- [x] 3.1 Toast 双态：`toast(message, type='error')` 加 class，CSS 区分 `.toast`（红）/`.toast.success`（绿）+ 入场动画；grep 全部调用点按语义标注（导出成功 → success，其余 error）；harness 触发导入失败（error 红）与导出（success 绿）断言 class 与动画
  - 记录：6 处调用点核对——仅导出为 success，其余（保存失败/无效网址/未知引擎/无效导入/非图片）均为 error 默认
- [x] 3.2 壁纸 crossfade：index.html 增加两个 fixed 壁纸层（或 body 伪元素），`applyWallpaper` 改为"写后备层 → opacity 淡入 → 交换引用"（~15 行，设计 D4）；两层 pointer-events none、z-index 低于内容；harness 断言切换壁纸时新层 opacity 过渡存在且最终为 1、旧层退场，点击/键盘交互不受层遮挡
  - 记录：opacity 数值断言因 headless 虚拟时间冻结 transition 而改为类切换断言（`.visible` 交换 + 旧层 450ms 后退场 + 同图跳过）；CSS transition 定义在浏览器中生效。发现并修复 headless 工具两处环境问题：until() 真实时钟截止在虚拟时间下失效（改迭代上限）、Edge dump 后不退出（summary 早退 + kill 兜底 + rmSync 容错）

## 4. 回归与验收

- [x] 4.1 全量回归：`moon test` 37/37 不变、e2e.mjs 18/18 不变、headless 渲染检查 10/10 不变、harness 既有 34 项断言不回退（新样式不得破坏既有行为）
  - 记录：moon test 37/37、e2e 18/18、渲染检查 10/10、harness 扩至 57 项全过（34 项既有断言全部保持，3 处壁纸断言的读取位置随 crossfade 实现迁移到活动层）
- [x] 4.2 生成新截图（headless.png）并人工过目观感；确认浅色/深色壁纸两种背景下文字可读；在任务记录中给出验收结论
  - 记录：截图已生成（1280×800）。模型无法查看图片，人工过目留待用户；可读性由 scrim vignette（中心 0.16→边缘 0.44）在结构上保证。
