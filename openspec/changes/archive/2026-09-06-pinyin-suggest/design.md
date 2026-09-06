# Design: pinyin-suggest

## Context

search-history 的 suggest_for 已是"trie 原文前缀 + 评分排序"结构。拼音联想是它的第二检索维度，数据与算法全部下沉 MoonBit。

## Goals / Non-Goals

**Goals:** 常用字（~2000）无声调全拼表；全拼 + 首字母双路匹配；三档优先级排序；零 UI 改动。
**Non-Goals:** 声调、多音字消歧（取通行读音单值）、整句拼音分词、模糊音（z/zh、n/l）。

## Decisions

### D1. 数据：紧凑连排串 + 惰性解析

- 单一字符串常量，条目为"汉字+无声调拼音"连排、空格分隔：`"啊a 阿a 埃ai ..."`——拼音为纯 ASCII，汉字 > 0x7F，按字符类切分；写库 ~2000 字（覆盖常用读写面），分块常量拼接（每块一个声母区间，可维护）
- 运行时惰性构建 `Map[Char, String]`（Ref 缓存 + 首次构建），~2000 项构建 < 1ms
- **ü → v**（女 nv、绿 lv），与通行输入法一致
- 多音字取通行读音（重 zhong、行 xing/hang 取语境常用值——查词用，取"行 xing"）

### D2. 匹配与排序（store 侧）

```
query 为纯 [a-zA-Z] 时：
  candidates = 原文前缀命中(trie) ∪ 全拼前缀命中 ∪ 首字母前缀命中
  分档：0 原文 / 1 全拼 / 2 首字母
  排序：档位 asc → score desc → last_used desc → query asc（确定性）
```

- 非纯字母查询走原路径（中文前缀不变）
- 全拼/首字母串每次 `search_input` 现算（≤100 条 × 短串，成本可忽略；不预存，避免 config 膨胀）

### D3. 验证

- pinyin 包单测：抽查锚定（春→chun/节→jie/春节→chunjie+cj/女→nv/表外字符跳过/ASCII 透传为空）
- store 单测：三档排序、中文查询不受影响、无匹配为空
- e2e + harness：中文历史 + 英文输入端到端

## Risks / Trade-offs

- [手写表拼音错误] —— 常用字逐块复核；错误仅导致漏联（无错误命中），风险性质良性
- [wasm 体积 +~15KB] —— 相对 120KB 基线可接受；后续可换分层压缩编码
- [多音字单值偏差] —— 记录为 Non-Goal；如"重庆"（chongqing ✓ 用 chong）等高频复合词已覆盖常用读音

## Migration Plan

纯新增，零迁移。回滚 = revert。

## Open Questions

（无）
