# 日志行排版重构设计

## 背景

详细日志页(`LogRow`)和总览页(`CompactLogRow`)在引入 `FAST` 徽章和实际生产数据后,排版出现两类问题:

1. **`LogRow` 模型名被严重截断** — 右侧 4 个固定列(TOK 48 + CACHE 56 + Cost 62 + Perf 76 = 242pt)挤占顶行,模型名只能显示 `gpt-...`,叠加 `FAST` 徽章后状态 capsule 也开始被压。
2. **`CompactLogRow` 视觉错位** — 右侧每列是 3 行布局(`TITLE` / `top` / `bottom`),左侧只有 2 行,造成上下不对齐;同时 `TOK`/`CACHE` 标签在每一行重复出现,在密集列表里是噪音。

文件位置: `CCHBar/MenuBarView.swift`
- `LogRow` — 3286-3395 行
- `CompactLogRow` — 3397-3504 行
- `UsageMetricColumn` — 2807-2828 行
- `CompactUsageMetric` — 2830-2854 行
- `MoneyValue` — 12-49 行
- `FastTierBadge` — 2924-2940 行
- `StatusCapsule` — 2907-2922 行

## 设计目标

- 模型名(顶行最关键的识别信息)必须能完整显示常见模型名(到 ~20 字符)。
- `FAST` 徽章出现不破坏排版。
- 视觉上左右块高度对齐,减少错位感。
- 保留所有现有信息(成本、耗时、TTFB、吞吐、缓存等),只调整位置。

## 设计方案 — 成本下沉 + 状态归位

### 1. `LogRow`(详细日志页)

**顶行**:`[●] [图标] 模型名 [FAST] [x0.12] [200]`
- 移除右侧的 cost 列,顶行模型名可用宽度增加约 71pt(62pt cost 列 + 9pt 间距)。
- 模型名仍使用现有 `lineLimit(1) + truncationMode(.tail)`,顶行其他元素保持现有 `fixedSize` 行为,只是空间更宽松。

**副行**:`Chen · Xixi-Codex-Pro · 18:10 · $0.007`
- 在现有副行末尾追加 `· $0.007`,沿用副行的 `caption` 字号和 `textSecondary` 颜色。
- 成本使用 `MoneyValue` 渲染,`majorSize: 10.5`(配合 `caption`),`minorSize` 不变(7位精度的上标尾数继续支持)。
- 当成本为 0(请求中/失败),不显示成本段(连同前导 `· ` 一起省略),避免出现 `· $0.000`。

**右侧列**:删掉 cost 列,只保留 TOK 48pt + CACHE 56pt + Perf 76pt。整体右侧从 4 列变 3 列,腾出的 ~71pt 全归顶行。

### 2. `CompactLogRow`(总览页)

**顶行**:`提供商名 [x0.12] [FAST] [200]`
- 将 `StatusCapsule` 从右侧独立列(原 50pt)移到顶行末尾,与 `MultiplierBadge`、`FastTierBadge` 形成统一的 badge 群。
- 提供商名继续使用 `textAdaptiveWidth(... limit: 128, compactThreshold: 15)`,但顶行可用宽度增加(50pt status + 8pt 间距)。

**副行**(不变):`Chen · [模型图标] 模型名 · 18:20`

**右侧 3 列**:
- 去掉 `CompactUsageMetric` 的 `TITLE` 行(`TOK`/`CACHE` 标签)。
- 每列从 3 行变 2 行,与左侧的 2 行对齐。
- **不**新增列表表头 — 与详细日志页保持一致(详细页右侧本就无标签),用户已熟悉这种约定。

### 3. 不动的部分

- `LogRow` 的 `LogStatusIndicator`、`ModelBrandIcon`、`MultiplierBadge`、`FastTierBadge`、`StatusCapsule` 组件本身不修改。
- `MoneyValue` 组件不修改。
- `UsageMetricColumn` 不修改(只是 `LogRow` 不再把它用在 cost 位置)。
- `CompactUsageMetric` **会修改**:去掉 `title` 参数和顶部 `Text(title)`,变成 2 行布局。`width` 微调(42 → 44,留出更多数字空间)。

### 4. 边界与细节

- **副行行内成本前的间隔符**:用现有副行的 `·` 风格,保持一致(`Text("· ")`)。
- **成本为 0**(请求中、或确实免费):副行直接省略 `· $0.000` 段,避免视觉噪音。判定条件 `log.costUsd > 0`。
- **错误状态**(`statusCode >= 400`):成本可能仍 > 0(部分错误也计费),按正常逻辑显示;若 0 则按上一条省略。
- **`LogRow` 现有列宽**:TOK 48 / CACHE 56 / Perf 76 全部不变。删除 cost 列(62pt + 9pt 间距 = 71pt)是唯一的右侧改动。
- **`CompactLogRow` `CompactUsageMetric` 列宽**:42 → 44,微调以补偿去掉标签后的视觉密度。
- **总览页 status capsule 在顶行**:沿用现有 `StatusCapsule(text:color:)`,不再需要 `frame(width: 50, alignment: .trailing)` 包裹。

## 数据流影响

无。只是 SwiftUI 视图层重排,数据来源(`CCHLogEntry`)、`providerMultiplier`、`cacheStatus` 等参数全部保留。

## 验证

- 静态预览(SwiftUI Preview / 启动 app):
  - 短模型名(如 `gpt-5.5`)、长模型名(如 `gpt-5.5-mini-thinking`)、超长模型名(如 `claude-sonnet-4.5-20251022`)三档场景。
  - 普通行 / 带 `FAST` 行 / 请求中行 / 错误行 4 档状态。
  - 成本 = 0 / 小额($0.0001)/ 大额($1.234)三档金额,确认上标尾数仍正常。
- 手动:在总览页和日志页都滚动几屏,确认对齐感和模型名可读性。

## 不做的事

- 不重新设计成本的精度显示(`MoneyValue` 的上标小数继续用)。
- 不调整字号、间距、配色之外的视觉层级(只是搬位)。
- 不动 `RunningRequestRow`、`LogDetailView` 等其他展示组件。
- 不增加列表表头(若 `CompactLogRow` 无合适挂载点则直接去标签)。

## 风险

- 副行变长后,在极窄窗口下 `Chen · Xixi-Codex-Pro · 18:10 · $0.007` 可能溢出。副行已有 `lineLimit(1)`,但提供商名的 `textAdaptiveWidth` 上限是 160pt — 极端情况成本可能被截断到看不全。缓解:成本段使用 `fixedSize(horizontal: true)`,优先保证成本完整,让提供商名先被截。
