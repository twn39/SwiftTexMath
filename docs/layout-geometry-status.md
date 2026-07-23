# SwiftTexMath 垂直几何 / 渲染对齐 — 进度与待办

> 记录分数线贴分母等问题排查后的修复进度、坐标系约定、测试基建与后续可选工作。  
> 最后更新：2026-07-23  
> 测试基线：全量 **263** 项通过（`swift test`，10 suites）

---

## 0. 总览（快照）

| 类别 | 状态 |
|------|------|
| 分数 / radical / overline 等水平 rule 间隙 | ✅ 完成 |
| Axis 居中（delimiter / large-op / `\sout`） | ✅ 完成 |
| Script / limits / stack 上下成对 | ✅ 完成 |
| Radical 变体 + 竖直 assembly + 顶对齐 | ✅ 完成 |
| Accent 上/下/wide/通用 mark + bare `\underaccent{\tilde}` | ✅ 完成 |
| 水平 assembly（`h_assembly`）+ 绘制 offsetsX | ✅ 完成 |
| Flattened accents（基础）/ signed attachment / extender stretch | ✅ 完成 |
| 几何 clearance 测试 + 嵌套 / aligned / Taylor corpus | ✅ 完成 |
| PNG 墨迹投影自动检贴线（列向 median clear） | ✅ 完成 |
| Accent 多字符 base italic / 居中混合 | ✅ 完成 |
| README 重音命令表 | ✅ 完成 |
| Git 提交 + Cappuccino submodule 指针 | ⏳ 待用户决策 |
| StreamMark / 主应用目视回归 | ⏳ |
| 其它 bundled 字体补 `h_assembly` 数据 | ⏳ 数据侧 |
| Flattened accents 深化 / bottom vertical attach | ⏳ 可选 |
| `codegraph build .` 同步 | ⏳ |

---

## 1. 问题背景

用户截图中，Taylor / Maclaurin 公式里 `\frac{f''(0)}{2!}` 一类分数的 **分母顶到分割线**。

根因不是 LaTeX 写法，而是 **layout 坐标系与 draw 坐标系不一致**，以及 **MATH 表 gap 只算进 ascent/descent、绘制时未使用**。

典型模式：

| 模式 | 表现 |
|------|------|
| 偏移按 baseline / axis 算，线却画在 `y = 0` | 分母贴线、分数线不在 math axis |
| metrics 的 `*Gap*` 只加大外框 | 视觉上线仍贴内容 |
| 半边 clearance（分子做了、分母 `_ = clearDen`） | 一侧正常、一侧贴线 |
| glyph `shiftDown` 未反映到 `DisplayNode` ascent/descent | 侧挂上下标相对「假 baseline」错位 |

---

## 2. 坐标系约定（已写入代码注释）

见 `Sources/SwiftTexMathCore/Display/DisplayList.swift` 文件头：

| 概念 | 含义 |
|------|------|
| **Baseline** | 行内节点默认 `position.y = 0` |
| **Math axis** | `FontMetrics.axisHeight`；分数线、大括号 / large-op 居中应对齐它 |
| **ascent / descent** | 相对 baseline 的视觉外接高度 |
| **ruleOffset** | 水平 rule 中心（CG 描边以 path 为中心）；**禁止** TeX rule 硬画在 `y = 0` |

带 `shiftDown` 的 `GlyphRun`：`DisplayNode` 返回 **视觉** ascent/descent：

```text
ascent  = rawAscent  - shiftDown
descent = rawDescent + shiftDown
```

水平 MATH assembly：`GlyphRun.glyphOffsetsX`；竖直 assembly：`glyphOffsetsY`。二者互斥使用，draw 侧按非空数组选路径。

---

## 3. 已完成

### 3.1 水平 rule 间隙

| 结构 | 状态 | 要点 |
|------|------|------|
| **Fraction** | ✅ | `ruleOffset = axis`；分子/分母 min gap（`Fraction*GapMin`） |
| **Radical overbar** | ✅ | `ruleOffset = radicand.ascent + gap + rule/2`；draw 用 `ruleOffset` |
| **Overline / Underline** | ✅ | `LineDisplay.ruleOffset` 含 over/underbar gap |
| **Table hline / vline** | ✅ 审计 | `RuleDisplay.position` 已正确，无需改 |

### 3.2 Axis 居中

| 结构 | 状态 | 要点 |
|------|------|------|
| **Delimiter** `\left…\right` | ✅ | `centerOnAxis: true`；父节点用视觉 ascent/descent |
| **Large op limits** display | ✅ | nucleus `shiftDown`；上下限相对 **视觉** 核体；GapMin / BaselineRise(Drop)Min 分开 |
| **Large op side-script** | ✅ | `\int_0^1`、text `\sum_i`：`glyphNode(..., centerOnAxis: true)` |
| **`\sout` 横线** | ✅ | `strikeVerticalOffset = axisHeight` |

### 3.3 上下成对结构

| 结构 | 状态 | 要点 |
|------|------|------|
| **Script** 上下标 | ✅ | 间隙公式完整；随 base 视觉 ascent 工作 |
| **Limits** | ✅ | 随 large-op 修正 |
| **Stack** overset/underset | ✅ | over/under 用 overbar/underbar 与 limit gap 的较大值；stretchy 走 **variants → h_assembly** |

### 3.4 Radical

| 项 | 状态 | 要点 |
|------|------|------|
| 横线间隙 | ✅ | 见上 |
| 符号顶对齐 overbar | ✅ | `shiftDown = ascent - ruleTop` |
| 次数定位 | ✅ | `RadicalDegreeBottomRaisePercent`（`percentConstant`，不按 font unit 缩放） |
| 超高 assembly | ✅ | variants → `constructVerticalGlyph`；宽度取各 part 最大 advance |
| extender stretch | ✅ | 多余长度优先加在 **extender joints**（与水平 assembly 共用逻辑） |

### 3.5 Accents

| 项 | 状态 | 要点 |
|------|------|------|
| 普通 `\hat` 等 | ✅ | signed MATH attachment + `AccentBaseHeight` |
| `\widehat` / `\widetilde` | ✅ | h-variants；不够宽时 `sizedHorizontal` / `h_assembly` |
| Below：`\utilde` / `\underbar` / under-arrows | ✅ | `isBelow`；优先 `*belowcmb`；宽 base 居中 |
| 通用 `\accent` / `\overaccent` / `\underaccent` | ✅ | `Accent.mark`（script mark 列表）或单 glyph 路径 |
| bare mark 名 | ✅ | `\underaccent{\tilde}{x}` / `\tilde{}`；无 base 不吞后续参数 |
| 负 skew 左伸 | ✅ | base/accent 整体右移，避免裁切 |
| Flattened accents | ✅ 基础 | base 高于 `FlattenedAccentBaseHeight` → flat 名 / 更矮 variant |
| Bottom attachment | ✅ | `accentAttachmentX` / `hasAccentAttachment`；竖直仍用 underbar gap |
| 多字符 base italic | ✅ | 半 italic + 与居中混合；单字母仍用 last-glyph attach + 全 italic |

### 3.6 字体 / API

| API / 能力 | 说明 |
|------------|------|
| `percentConstant` | 单位无关百分比常量 |
| `horizontalVariants` / `findHorizontalVariant` / `findHorizontalVariantSized` | 含 cmb 别名 |
| `FontTable.hAssembly` | 可选；缺省 `[:]` 兼容无表字体 |
| `sizedHorizontal` / `constructHorizontalGlyph` | variants → 水平拼装 |
| `constructAssembly` | 竖/水平共用；connector overlap + extender 优先 stretch |
| `flattenedAccentBaseHeight` + `pickFlattenedAccentIfNeeded` | 高 base 压扁 accent |
| `accentAttachmentX` / `hasAccentAttachment` | signed 水平 attachment |
| `sizedRadical` / `sizedDelimiter` | 竖直 variants + assembly |
| `GlyphRun.glyphOffsetsX` / `glyphOffsetsY` | draw 与 layout 对称 |

### 3.7 测试基建

| 文件 | 作用 |
|------|------|
| `Tests/.../LayoutClearanceHelpers.swift` | fraction/radical/line/op/stack 查找；rule 间隙；`allGlyphRuns` |
| `LayoutGeometryTests.swift` | 尺寸 golden + clearance 不变量；嵌套 / aligned / Taylor；`InkProjectionClearanceTests` |
| `DelimiterRadicalAccentTests.swift` | radical / accent / underaccent / h-assembly / nested corpus |
| `LargeOperatorLayoutTests.swift` | limits + side-script axis |
| `FontMetricsTableTests.swift` | MATH 常量、水平 assembly、below attachment、assembly 单调性 |
| `Goldens/*.png` | 几何变更后已重生成（fraction, quadratic, big_delims, cfrac, overset, operatorname 等） |
| `README.md` | Feature matrix + **Accent commands** 用户可见命令表 |

`LayoutClearance` 扩展：

- 深度搜索 `firstNode`（进 fraction / radical / stack 等）
- `allFractions` / `placedFractions`（绝对原点，对齐 draw 的 num/den offset）
- `assertFractionRuleClearances`

代表性用例（不全列）：

- `fractionDenominatorClearsRule`
- `radicalOverbarClearsRadicand` / `radicalGlyphTopAlignsWithOverbar`
- `overlineUnderlineClearContent`
- `largeOperatorAxisAndLimitGaps` / `sideScriptLargeOpCentersOnAxis`
- `dualScriptsKeepGap` / `stackOversetClearsBase`
- `horizontalStrikeOnAxis`
- `widehatWiderThanPlainHatOnLongBase` / `utildeSitsBelowBase`
- `underaccentMarkListSitsBelow` / `parseUnderaccentAndAccentCommands`
- `underaccentBareTildeCommandParses` / `underaccentBareTildeLayoutsBelow`
- `tallRadicalGrowsBeyondSingleVariantFloor`
- `nestedRadicalFractionClearances` / `nestedSqrtFracDoublePrimeClearances`
- `deepNestedFractionClearances` / `taylorSeriesNestedClearances` / `alignedWithFractionsClearances`
- `multiLetterHatMoreCenteredThanLastItalicAlone`
- `fractionRuleInkHasClearBandsBesideContent` / `radicalOverbarInkClearsRadicandBand` / `nestedSqrtFracInkClearance`
- `horizontalAssemblyCoversWideTarget` / `overrightarrowGrowsWithLongBase`
- `hatOnTallBaseStillPositiveAscent`
- `belowAccentGlyphHasAttachmentEntry` / `verticalAssemblyExtenderStretchIsMonotonic`

### 3.8 涉及的主要源文件

```
Sources/SwiftTexMathCore/
  Display/DisplayList.swift
  Display/CGContext+DisplayList.swift
  Font/FontMetrics.swift
  Font/FontTable.swift
  Layout/FractionLayout.swift
  Layout/RadicalLayout.swift
  Layout/LineLayout.swift
  Layout/LargeOperatorLayout.swift
  Layout/AccentLayout.swift
  Layout/BoxLayout.swift
  Layout/DelimiterLayout.swift
  Layout/StackLayout.swift
  Layout/Typesetter.swift
  Parse/MathParser+Commands.swift
  Syntax/MathAtom.swift
  Syntax/AtomFactory.swift
  Syntax/LatexSerializer.swift
  Normalize/MathNormalizer.swift

Tests/SwiftTexMathCoreTests/
  LayoutClearanceHelpers.swift
  LayoutGeometryTests.swift
  DelimiterRadicalAccentTests.swift
  LargeOperatorLayoutTests.swift
  FontMetricsTableTests.swift
  Goldens/*.png

docs/layout-geometry-status.md   ← 本文
README.md                        ← Accent commands 表
```

---

## 4. 排查方法（可复用）

1. **成对审计**：每个 `*Layout.make` 与 `CGContext+DisplayList` 对应 `draw` 对读。  
2. **静态搜索**：`_ = `、`y: 0` 硬编码 rule、`GapMin` 是否只出现在 layout。  
3. **几何不变量测试**：clearance ≥ metrics gap（比纯尺寸 golden 更能抓「线错位」）。  
4. **Golden PNG**：`REGENERATE_GOLDENS=1 swift test --filter goldenPNGsMatchCommittedFixtures`。  
5. **对照**：OpenType MATH 常量名 + TeX Appendix G / iosMath 同类逻辑。

历史优先级（均已落地主体）：

```text
1. 所有画水平线的路径
2. axis 居中（delimiter / large op）
3. 上下成对（script / limits / stack）
4. box / cancel / accent / radical 细节
5. h_assembly + flattened + bare underaccent + extender stretch
```

---

## 5. 待做 / 可选优化

### 5.1 高优先级（发布 / 集成）

| 项 | 说明 | 状态 |
|------|------|------|
| **提交 SwiftTexMath** | 工作区改动尚未 commit；需 review 后提交 | ⏳ 待用户决策 |
| **更新 Cappuccino submodule 指针** | 父仓引用子模块新 commit | ⏳ 依赖上项 |
| **StreamMark / 主应用目视回归** | 真实笔记公式：`2!` 分母、长 `\overrightarrow`、Taylor 式 | ⏳ |
| **`codegraph build .`** | 按 Cappuccino `Agents.md` 同步知识图（改动后建议跑） | ⏳ |

### 5.2 中优先级（数据 / 表现）

| 项 | 说明 | 状态 |
|------|------|------|
| **其它字体 `h_assembly` 数据** | 目前主要 **Latin Modern** plist 含 `h_assembly`；Asana/XITS/… 等靠 h-variants | ⏳ 数据侧 |
| **Flattened accents 深化** | 字体若提供真正 flat 形，可扩展映射；当前为 flat 名 + 矮 variant 启发式 | ⏳ 可选 |
| **Bottom accent 竖直附件** | OpenType 若将来分表 bottom vertical，可替换 underbar gap 近似；当前表无独立竖直 bottom attach | ⏳ 暂无数据 |
| **Radical 拼装再贴 HarfBuzz** | extender 优先已做；connector overlap 细节 / 视觉还可对照 | ⏳ 微调 |

### 5.3 低优先级（质量 / 工程）

| 项 | 说明 | 状态 |
|------|------|------|
| **PNG 墨迹投影自动检贴线** | 列向 median clear（分数 / radical / 嵌套）；`locateRuleRow` 兼顾 bitmap 行向 | ✅ 完成 |
| **嵌套 / aligned clearance corpus** | 深层嵌套、`aligned` 双行、Taylor 级数、`\sqrt{\frac{f''(0)}{2!}}` | ✅ 完成 |
| **Accent 多字符 base 的 italic** | 半 italic + 与居中混合；单字母路径不变 | ✅ 完成 |
| **LayoutClearance 再收敛** | `allFractions` / `placedFractions` / `assertFractionRuleClearances` | ✅ 本轮 |
| **无参 accent 在更多上下文** | bare mark 已覆盖 underaccent/accent；其它宏若需可再扩 | ⏳ 按需 |
| **墨迹 y 映射固化** | 当前对 flipped/unflipped 预测取 densest；若 `MathImage` 固定 top-origin 可再收紧 | ⏳ 可选 |

### 5.4 明确不做或暂缓

| 项 | 原因 |
|------|------|
| 把 gap 只调大 ascent 而不改 draw | 会掩盖 bug，禁止 |
| 无 MATH 表时的启发式乱调 | 优先读表；缺省再 fallback |
| 为体验硬编码 TeX 魔法数绕过 MATH | 与引擎设计冲突 |

---

## 6. 命令速查（重音相关）

| 命令 | 行为 |
|------|------|
| `\hat` `\tilde` `\bar` `\vec` `\dot` `\ddot` `\check` `\breve` `\acute` `\grave` | 上方 combining / 字形 |
| `\widehat` `\widetilde` | 上方 + 水平变体（及 assembly） |
| `\utilde` `\underbar` | 下方 |
| `\underrightarrow` `\underleftarrow` | 下方箭头类（可 stretch） |
| `\accent{mark}{base}` / `\overaccent{mark}{base}` | mark 在上（script 列表或 bare 名） |
| `\underaccent{mark}{base}` | mark 在下；支持 `\underaccent{\tilde}{x}` |

仍推荐语义清晰写法：`\utilde{x}` 或 `\underaccent{\sim}{x}`。避免把带 base 的 accent 嵌进 mark（如 `\underaccent{\tilde{y}}{x}`）。

更完整用户表见仓库根目录 **README.md → Accent commands**。

### 验证命令

```bash
cd SwiftTexMath
swift test
# 更新 PNG 基线（改布局后）
REGENERATE_GOLDENS=1 swift test --filter goldenPNGsMatchCommittedFixtures
```

---

## 7. 变更状态（工作区）

截至 2026-07-23，SwiftTexMath 子模块 **尚未 git commit**，大致包括：

**已修改（tracked）**

- Display：`DisplayList`、`CGContext+DisplayList`（`glyphOffsetsX`、assembly 绘制）
- Font：`FontMetrics`、`FontTable`（`h_assembly`、水平拼装、attachment API）
- Layout：Fraction / Radical / Line / LargeOperator / Accent / Box / Delimiter / Stack / Typesetter
- Parse / Syntax / Normalize：accent bare mark、atom 字段等
- 测试与若干 Goldens；`README.md`

**未跟踪（untracked）**

- `Tests/SwiftTexMathCoreTests/LayoutClearanceHelpers.swift`
- `docs/`（含本文）

**父仓 Cappuccino**

- 子模块指针与上述工作区未同步为正式提交前，集成侧仍应用本地 checkout 验证。

---

## 8. 相关讨论脉络（摘要）

1. 诊断：分母贴线 → `FractionLayout` 分母 clearance 未应用 + rule 画在 y=0。  
2. 修复 fraction → 系统审计 radical / line / large-op / scripts。  
3. 有效 ascent + side-script axis → accent 水平变体 + radical 顶对齐。  
4. below accents + radical assembly → `\underaccent` / `\accent` 通用 mark。  
5. 固化文档；水平 `h_assembly` + flattened + 嵌套 `\sqrt{\frac{f''(0)}{2!}}`。  
6. bare `\underaccent{\tilde}`、signed accent attachment、extender 优先 stretch、README 命令表。  
7. 本文：总览表 + 完成项与待办拆分更新。  
8. 墨迹列向 median clear、aligned/Taylor/深层嵌套 corpus、多字母 `\hat` 居中混合。

---

## 9. 建议下一动作

| 顺序 | 动作 | 说明 |
|------|------|------|
| 1 | Review + **commit** SwiftTexMath | 含 untracked helpers / docs |
| 2 | 父仓更新 **submodule 指针** | 再 Archive / 跑主应用 |
| 3 | **StreamMark 目视** | Taylor 分式、长箭头、underaccent、多字母 `\hat{xyz}` |
| 4 | 可选数据 | 其它字体 `h_assembly`、flattened 映射深化 |
| 5 | 可选 | `codegraph build .`（主仓依赖图） |

---

## 10. 修订记录

| 日期 | 摘要 |
|------|------|
| 2026-07-23 | 初版：fraction/radical/axis/scripts 完成项 + 待办 |
| 2026-07-23 | h_assembly、flattened、嵌套 clearance；测试 ~252 |
| 2026-07-23 | bare underaccent、signed attachment、extender stretch；测试 **256** |
| 2026-07-23 | 文档重排：§0 总览、§3 仅完成、§5 仅待办、工作区与下一动作对齐现状 |
| 2026-07-23 | 墨迹列向检贴线、嵌套/aligned/Taylor corpus、多字母 accent italic；测试 **263**（10 suites） |
