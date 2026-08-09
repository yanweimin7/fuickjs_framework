# FuickJS Framework 审计报告

> 审计日期：2026-04-11
> 覆盖范围：`fuickjs_framework/fuickjs/`（JS 核心）、`fuickjs_framework/fuickjs_flutter/`（Flutter 层）、`taro-fuickjs/`（Taro 适配层）

---

## 总览

| 层 | 当前状态 | 评分 |
|---|---|---|
| JS 框架核心 | 所有已知 bug 已修复，2 个设计约束已知 | 8.5/10 |
| Flutter 框架层 | 所有已知 bug 已修复，1 个设计约束已知 | 9/10 |
| Taro 适配层 | 所有已知 bug 已修复，1 个平台限制已知 | 8.5/10 |

**P0 / P1 全部已修复，无遗留功能性 bug。**

---

## 审计后补充（2026-08）

本审计（2026-04-11）为历史快照。此后在离线包（offline）与 widget 层新增了若干**健壮性加固与能力**，均未推翻原审计结论，仅作为补充记录：

| 类别 | 内容 | 说明 |
| --- | --- | --- |
| 健壮性 | 验签 isolate 看门狗 | `BundleVerifyIsolate` 原为"worker 抛错即 `Isolate.exit()` 杀全 isolate + 无超时"，会导致 in-flight `verify()` 永久 hang（软 brick）。改为纵深防御：worker 自愈 / 每条请求 15s 超时 / 崩溃看门狗监听 `addOnExitListener`。详见 `docs/bundle-delivery.md` §17.1 |
| 健壮性 | `Offline` 初始化守卫 | 移除易被误用的公开 `initialized` 布尔标志，改为 `await whenInitialized`；`promoteAndGetRoot` 等公开方法在 init 未完成前阻塞等待，而非早退返回 null |
| 健壮性 | `IsolateWorker.ensureInitialized` 失败重试 | 原实现 init 抛错后 `_ready` Completer 永不完成、且因 `_initialized=true` 早设导致后续调用永久 hang 且不可重试；改为失败后 `completeError` + 换新 `_ready` 允许重试 |
| 能力 | 无障碍（Accessibility） | widget 工厂在唯一汇聚点统一包裹 `Semantics`，业务用 `props.semantics` / `semanticLabel` 透传语义，读屏可用。原审计未评估此维度 |
| 能力 | 错误可观测性 | 新增可插拔 `ErrorSink` / `ErrorSinks`，JS 错误经 sourcemap 还原后聚合到 Sentry / Bugly / 自建平台（原仅打印日志 + 红屏，错误被丢弃） |

> 上述加固对应代码改动均通过 `dart analyze`；整库分析与 `flutter test` 建议在 CI 环境跑（本地受限）。

---

## 一、JS 框架核心（`fuickjs_framework/fuickjs/`）

### 架构概览

```
renderer.ts          全局入口，持有 containers/roots
  └── createRenderer()
        ├── PageContainer    每页 DSL 生成、回调管理、增量/Diff 策略
        ├── hostConfig.ts    React Reconciler 宿主配置
        ├── FuickNode        DSL 节点，支持 DSL 缓存
        └── ErrorHandler     全局错误回调分发
```

### 当前状态：无已知 Bug ✅

### 设计约束（非 bug，已知）

#### D1-JS：全局单例 containers/roots

`renderer.ts` 顶层两个全局 `Record`：

```typescript
const containers: Record<number, PageContainer> = {};
const roots: Record<number, unknown> = {};
```

多页并发场景下，pageId 必须全局唯一。当前 Flutter 侧通过 `nextPageId`（单调递增全局计数器）保证唯一性，无需内部校验。若未来有调用方绕过 `nextPageId` 传入固定 pageId，会产生冲突。

#### D2-JS：`dispatchEvent` 跨页容器回退搜索

`renderer.ts`，当 `containers[pageId]` 找不到时会遍历所有活跃容器查回调：

```typescript
for (const id in containers) {
  const c = containers[id];
  if (c.getCallback(nodeId, eventKey)) { container = c; break; }
}
```

在 nodeId 重用场景（如 Dialog 与某 Page 使用相同 nodeId），会把事件路由到错误容器。目前靠 nodeId 实际全局唯一来规避，属于防御性兜底逻辑。

#### D3-JS：renderer 重试逻辑字符串匹配

`isRenderInProgressError()` 通过字符串匹配识别 React 内部"render in progress"错误：

```typescript
return msg.includes('327') || msg.includes('already being rendered') || msg.includes('working');
```

已提取为独立函数（避免散落魔法字符串），但本质上仍是字符串匹配。React 版本升级若修改错误消息格式，重试能力会静默失效。当前 React 版本下功能正常。

---

## 二、Flutter 框架层（`fuickjs_framework/fuickjs_flutter/`）

### 架构概览

```
WidgetFactory                 DSL → Flutter Widget，持有 WidgetParser 注册表（50+ parsers）
  ├── ContainerParser         Container + GestureDetector（onTap/onLongPress）
  ├── ColumnParser / RowParser  Column/Row + alignSelf + spacing + textBaseline
  ├── AnimatedContainerParser  AnimatedContainer + GestureDetector + constraints
  ├── TextParser               Text + TextStyle 全属性 + SelectableText
  ├── ImageParser              网络/Asset/本地/base64（含 SVG）
  ├── DecoratedBoxOutlineParser  CSS outline 实现
  ├── ClipPathParser           CSS clip-path 实现（circle/ellipse/inset/polygon）
  ├── ColorFilteredParser      CSS mix-blend-mode 实现（ShaderMask）
  └── ... 50+ parsers
WidgetUtils                   颜色/EdgeInsets/BorderRadius/Transform 等工具函数
FuickAction                   事件分发中枢
BaseFuickService              所有 Native 服务基类
```

### 当前状态：无已知 Bug ✅

### 设计约束（非 bug，已知）

#### D1-Flutter：手势包裹代码散落多处

`ContainerParser`、`AnimatedContainerParser`、`GestureDetectorParser`、`InkWellParser`、`ImageParser`、`TextFieldParser` 各自独立实现了相同的 `GestureDetector` 包裹逻辑。可提取 `WidgetUtils.wrapGesture()` 统一处理，但属于重构性工作，不影响功能。

#### D2-Flutter：`wrapMarginAndPadding` 用 Padding 实现 margin

`widget_utils.dart:141`：

```dart
if (margin != null && margin != EdgeInsets.zero) {
  c = Padding(padding: margin, child: c);  // 语义上应为 margin，实现为 Padding
}
```

`Padding` ≠ `margin`：不影响点击区域扩展。此函数仅被 Row/Column parser 调用，`ContainerParser` 本身正确地使用 `Container(margin:...)`。影响范围有限，属已知 tradeoff。

---

## 三、Taro 适配层（`taro-fuickjs/`）

### 架构概览

```
css-to-props.ts        CSS 字符串 → FuickProps（第一层）
View.tsx               读取元属性，包裹 Flutter Widget（第二层）
ContainerParser 等     只消费自身 Widget 原生 props（第三层）
```

**三层严格分离，禁止跨层操作。**

### 当前状态：无已知 Bug ✅

### 平台限制（非 bug）

- **Flutter 不支持 dashed/dotted border**：`_borderStyle` 中 dashed/dotted 降级为 solid，注释已说明
- **`overflow: hidden` + flex 不能同时使用**：Flutter ClipBehavior 影响 Flex 布局约束，架构上难以兼容
- **`Video` 无 `onPlay` 事件**：Flutter `VideoPlayerController` 仅提供 `onInitialized`（初始化一次），无法映射 Taro 的每次播放触发语义；`poster` prop 同样无法透传
- **`Text.selectable`**：透传 `selectable` prop 给 Flutter `TextParser`，由其决定是否使用 `SelectableText`

---

## 四、已修复问题完整记录

| ID | 优先级 | 描述 | 文件 |
|---|---|---|---|
| FIX-01 | P0 | `_opacity` 早返回阻止 `Expanded` 包裹 | `View.tsx` |
| FIX-02 | P0 | `filterBlur`/`backdropBlur`/`writingMode` 只在主路径生效 | `View.tsx` → `applyVisualEffectWraps` |
| FIX-03 | P0 | `AnimatedContainerParser` 缺 `onTap`/`onLongPress` + `constraints` | `animated_container_parser.dart` |
| FIX-04 | P0 | `ColumnParser` 缺 `textBaseline`（`baseline` 对齐崩溃） | `column_parser.dart` |
| FIX-05 | P0 | `outline`/`clip-path`/`mix-blend-mode` 已解析但无 View.tsx 包裹 | `View.tsx` + 新建 3 个 Flutter Parser |
| FIX-06 | P1 | `flex: 1 0 auto` 简写只解析 grow，忽略 shrink/basis | `css-to-props.ts` |
| FIX-07 | P1 | `_zIndex` 在无 transform 时被丢失（Positioned/flex+container 路径） | `View.tsx` |
| FIX-08 | P1 | `_zIndex` 在默认路径（普通 Container/Text 等）被丢失 | `View.tsx` + `style-resolver.ts` |
| FIX-09 | P1 | `inset` CSS 简写 2/3 值形式完全失效（误用 vertical/horizontal 语义） | `css-to-props.ts` |
| FIX-10 | P1 | `Radio.tsx` 用字符串字面量 `'Radio'` 而非 `WidgetNames.Radio` | `Radio.tsx` |
| FIX-11 | P1 | `RadioGroup` 用字符串字面量 `'Column'` 而非 `WidgetNames.Column` | `Radio.tsx` |
| FIX-12 | P1 | renderer.ts 重试条件散落魔法字符串 | `renderer.ts` → `isRenderInProgressError()` |
| FIX-13 | P2 | Positioned 无容器属性时 `onClick` 被静默丢弃 | `View.tsx` |
| FIX-14 | P2 | `OpacityParser` 不跳过 opacity=1.0，插入无用渲染 Layer | `opacity_parser.dart` |
| FIX-15 | P2 | `AspectRatioParser` 传入 ≤ 0 值触发 assertion 崩溃 | `aspect_ratio_parser.dart` |
| FIX-16 | P2 | `Slider`/`Progress`/`Loading` 用字符串字面量代替 `WidgetNames` | 各组件 + `widgetNames.ts` |
| FIX-17 | P2 | `recentlyDestroyed` 5s 窗口逻辑意义不大，增加理解负担 | `renderer.ts`（已删除） |

---

## 五、整体设计评价

### 优点

1. **三层分离架构清晰**：CSS 解析 → View.tsx 包裹 → Flutter Parser 消费，职责边界明确，有显式的"禁止跨层"约定，新增 CSS 属性流程规范
2. **DSL 缓存设计合理**：`_dslCacheDirty` 脏标记 + 父节点失效传播，避免全树重新序列化，性能好
3. **React Reconciler 集成完整**：`flushSync` 首次渲染 + 异步后续更新，符合 React 更新模型；首帧同步保证页面立即可见
4. **错误处理双保险**：`try/catch` + `ErrorHandler.notify`，异常不会静默消失
5. **WidgetUtils 工具函数完善**：颜色（含 rgba/named color/CSS 命名色）、EdgeInsets（含 3-value shorthand）、Transform（含 skew/rotate3d/perspective）、Curve 映射等覆盖全面
6. **WidgetNames 集中管理**：所有组件名通过 `widgetNames.ts` 常量引用，避免字符串散落

### 已知架构约束

| 约束 | 原因 | 影响 |
|---|---|---|
| Flutter 不支持 dashed/dotted border | 平台限制 | 降级为 solid，已注释说明 |
| `overflow: hidden` + flex 不能同时使用 | Flutter ClipBehavior 影响 Flex 约束 | 需拆分为两个元素 |
| `margin` 在 Column/Row 用 Padding 实现 | DSL 结构约束 | 语义偏差，但 Container 路径正确 |
| Video `onPlay`/`poster` 无法实现 | Flutter video_player 包限制 | 需等待包支持或自定义实现 |
| renderer 重试依赖字符串匹配 | React 未暴露错误类型 | React 版本升级时需同步验证 |
