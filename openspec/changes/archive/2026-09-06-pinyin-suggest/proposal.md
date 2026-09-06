# Proposal: pinyin-suggest

## Why

历史联想目前只匹配原文前缀——中文关键词必须重新输入中文才能联到。拼音（全拼前缀 + 首字母）联想让英文键盘直接命中中文历史词（输 "chun" 或 "cj" 联到"春节"），是中文导航页的核心输入体验，也是一块真正落在 MoonBit 的数据+算法资产。

## What Changes

- **新包 `src/pinyin`**：常用汉字（约 2000 字）→ 无声调全拼的紧凑数据表（`字pinyin` 连排 + 按字符类解析）；`pinyin_of(ch)` / `phrase_pinyin(s)`（逐字拼接，表外字符跳过）/ `phrase_initials(s)`（逐字首字母）；ü 统一编码为 `v`（与通行拼音输入法一致）
- **联想扩展**：`search_input` 的查询为纯英文字母时，除原文前缀外同时匹配历史条目的全拼串与首字母串（忽略大小写）；排序规则：原文前缀 > 全拼前缀 > 首字母前缀，同级内沿用频次×时间衰减评分
- **spec 增量**：search-box 新增"拼音联想"需求

## Capabilities

### New Capabilities

（无）

### Modified Capabilities

- `search-box`: 新增"拼音联想"需求——英文输入命中中文历史词（全拼与首字母两路）、排序规则

## Impact

- **新增文件**：`src/pinyin/`（数据 + 查询 + 测试，预计 wasm 增量 ~15KB）
- **修改文件**：`src/store/history.mbt`（suggest_for 扩展拼音匹配与三档排序）、`web/test-harness.html`、`e2e.mjs`
- **不修改**：config 模型、事件、trie 包、UI（联想面板天然复用）
- **风险面**：手写字表的拼音准确性（常用字逐档核对；错误后果仅表现为"联不到"，不误报）；wasm 体积增量可控
