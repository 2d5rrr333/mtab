# Tasks: pinyin-suggest

## 1. pinyin 包（src/pinyin）

- [x] 1.1 数据表（~2000 常用字，分声母块常量）+ 惰性 Map 构建 + `pinyin_of` / `phrase_pinyin` / `phrase_initials`（ü→v）。验证：单测锚定（春/节/春节/女/表外跳过/空串）
  - 记录：数据条目"字pinyin"连排、按字符类解析（仅 a-z 入拼音，防御杂字符）；顶层常量小写命名（py_block_a…）；锚定测试抓出 `言` 漏收（补）与一处测试期望笔误（农=nong→n，"nljq" 才对）
- [x] 1.2 `moon info` 检视（公开面仅三函数）
  - 记录：`.mbti` 仅 pinyin_of/phrase_pinyin/phrase_initials 三函数，内部表与解析不暴露

## 2. store 集成

- [x] 2.1 `suggest_for` 扩展：纯字母查询走三档匹配（原文 trie / 全拼 / 首字母），档位优先于评分。验证：store 单测（三档排序锚定、中文查询原路径不变、无匹配空）
  - 记录：`is_ascii_letters` 判定分流；suggest_ascii 线性三档扫描（≤100 条成本可忽略）复用 entry_before 评分决胜；中文查询路径与既有 trie 行为零变化（既有测试全过即证）

## 3. 回归与验收

- [x] 3.1 e2e 增补（中文历史 + chun/cj 查询）；harness 增补（config_import 注入中文历史 → 键入拼音断言建议）；全量回归（113/43/104+106 基线不回退）；wasm 体积记录；任务记录给出验收结论
  - 记录：moon test 122/122（+9）、e2e 46/46（+3）、harness 106/106 + 108/108（+2）、fmt-check 0；wasm 119,880 → 145,256 bytes（+25KB，含 ~2000 字数据表，符合预算）。过程中抓出并修复一个 bookmark-groups 遗留真 bug：`classList.add('drag-indicator after')` 单 token 含空格在拖拽至末位时抛 InvalidCharacterError（此前被事件处理器吞掉静默出错）——拆为两次 add。harness 拼音块改为 config 前后保存/恢复（避免清掉后续测试依赖的 moon 历史）。验收结论：拼音联想（全拼 + 首字母、三档优先级）端到端落地；手写表准确性由锚定测试覆盖核心词（春节/中秋节/端午节/语言/农历节气），冷僻字漏联为设计内边界
