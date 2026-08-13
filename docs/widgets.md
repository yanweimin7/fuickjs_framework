# UI 组件 (Widgets) 详尽指南

FuickJS 通过 DSL 映射，将 React 组件实时转换为 Flutter 原生组件。以下是目前已支持的所有组件及其功能描述。

## 1. 基础布局组件

- **Container**: 最常用的容器组件，支持 padding, margin, color, width, height, alignment 以及复杂的 decoration (圆角、阴影、边框)。
- **Column / Row**: 线性布局组件，支持主轴 (`mainAxisAlignment`) 和交叉轴 (`crossAxisAlignment`) 对齐。
- **Stack / Positioned**: 绝对定位布局，允许组件重叠。
- **Flex / Flexible / Expanded**: 弹性布局，用于按比例分配剩余空间。
- **SizedBox**: 固定尺寸容器，常用于撑开间距。
- **Padding**: 专门用于设置内边距的封装组件。
- **Center**: 将子组件居中对齐。
- **Align**: 精确控制子组件在父容器中的位置。Props: `alignment`（topLeft/topCenter/topRight/centerLeft/center/centerRight/bottomLeft/bottomCenter/bottomRight），`widthFactor`（可选，>0 时父容器宽度=子节点×factor），`heightFactor`（同 widthFactor，作用于高度）。当 factor 为 null 时父容器保持原大小。
- **ConstrainedBox**: 为子组件设置额外的约束（最大/最小宽高度）。
- **Wrap**: 流式布局，当空间不足时自动折行。
- **AspectRatio**: 按指定宽高比约束子组件尺寸，props: `aspectRatio`（必填）。
- **FractionallySizedBox**: 按父容器的百分比控制子组件尺寸，props: `widthFactor`, `heightFactor`, `alignment`。

## 2. 交互与输入

- **Button**: 原生按钮。Props: `text`, `onTap`, `disabled`, `loading`, `backgroundColor`, `textColor`, `fontSize`, `borderRadius`, `elevation`, `outlined`（OutlinedButton 变体）, `borderColor`, `borderWidth`, `minWidth`, `minHeight`, `paddingH`, `paddingV`。
- **InkWell**: 水波纹点击效果，可包裹任何组件使其具备交互能力。
- **GestureDetector**: 万能手势检测。基础手势：`onTap`, `onLongPress`, `onDoubleTap`。扩展手势（2026-08 新增）：
  - 缩放：`onScaleStart(e)` / `onScaleUpdate(e)` / `onScaleEnd(e)` —— `e: { scale, focalX, focalY, pointerCount }`（scale 由 native 计算）
  - 水平拖动：`onHorizontalDragStart(e)` / `onHorizontalDragUpdate(e)` / `onHorizontalDragEnd(e)` / `onHorizontalDragCancel(e)` —— `e: { dx, dy, x, y }`（`velocityX/velocityY` 见下）
  - 垂直拖动：`onVerticalDrag*` 同上，垂直方向
  - 自由拖拽（pan）：`onPanStart(e)` / `onPanUpdate(e)` / `onPanEnd(e)` / `onPanCancel(e)` —— `e: { dx, dy, x, y }`
  - 长按拖动：`onLongPressStart(e)` / `onLongPressMoveUpdate(e)` / `onLongPressEnd(e)` / `onLongPressCancel(e)` —— `e: { dx, dy, x, y }`（`x/y` 为自起点累计位移）
  - 回调参数类型 `PointArgs` 为 `{ dx, dy, x, y }`；缩放回调用 `ScaleArgs`；开始/结束回调无 velocity 字段（native 侧已裁剪），需要速度请自行基于 update 增量计算。
- **TextField**: 文本输入框。Props: `text`（受控值）, `hintText`/`hint`, `onChanged`, `onSubmitted`, `onFocus`, `onBlur`, `maxLines`, `maxLength`, `enabled`, `obscureText`, `keyboardType`（text/multiline/number/phone/datetime/emailAddress/url/visiblePassword）, `textInputAction`（done/go/next/search/send/none）, `autofocus`, `textAlign`（left/center/right/justify/start/end）, `readOnly`, `border`（`'none'` 或 `'outline'`）。Ref 命令: `setText(text)`, `clear()`, `focus()`, `unfocus()`, `setSelection(start, end)`, `selectAll()`。
- **Checkbox**: 复选框组件。
- **Switch**: 开关组件。

## 3. 展示类组件

- **Text**: 文本显示，支持样式 (fontSize, color, fontWeight)、行数限制 (`maxLines`)、溢出处理 (`overflow`)。
- **Image**: 图片加载，支持以下来源类型：
  - 网络图片 `https://...`（含 SVG）：自动缓存，支持 `placeholderColor`、`errorSrc` 备用图
  - Asset 图片 `assets/images/logo.png`（含 SVG）
  - 本地文件 `/data/user/.../img.jpg` 或 `file:///...`（含 SVG）：自动检测绝对路径
  - base64 内联 `data:image/png;base64,...`（含 SVG）
  - 核心 props：`src`（推荐）/ `url`（兼容）、`fit`、`tintColor`（推荐）/ `color`（兼容）、`placeholderColor`、`errorSrc`、`gaplessPlayback`、`centerSlice`、`onLoad`、`onError`
  - `centerSlice`：九宫格拉伸（9-patch），坐标以图片原始像素为单位。【硬约束 1】必须配 `fit="fill"`；【硬约束 2】边框（`left + imageWidth - right`）必须 <= widget 宽高，否则 parser 自动丢弃并打 warning
- **Icon**: 显示 Material Design 图标。
- **RichText**: 富文本组件，支持在同一行显示不同样式的文本片段。
- **CircularProgressIndicator**: 圆形进度条。
- **Divider**: 分割线。
- **BackdropFilter**: 对背景施加模糊或图像滤镜效果，props: `sigmaX`, `sigmaY`, `blendMode`。需配合 `ClipRRect` 或透明容器使用。
- **DecoratedBoxOutline**: CSS `outline` 实现，在子组件外侧绘制边框。Props: `width`, `color`, `style`, `offset`。由 View.tsx 从 CSS `outline` 属性自动包裹。
- **ClipPath**: CSS `clip-path` 实现。支持 `circle()`/`ellipse()`/`inset()`/`polygon()` 形式。Props: `path`（CSS clip-path 值字符串）。
- **ColorFiltered**: CSS `mix-blend-mode` 实现，通过 `ShaderMask` + `BlendMode` 模拟混合模式。Props: `blendMode`。

## 4. 滚动列表

- **ListView**: 高性能线性列表，支持 `itemBuilder` 按需渲染（Lazy Loading）。Props: `itemCount`, `itemBuilder(index)`, `itemExtent`（固定 item 高度，滚动命令可精确定位）, `onScroll(e: { pixels, maxScrollExtent })`, `onScrollEndReached`（滑到底触发）。Ref 命令（通过 `useRef<ListView>(null)` 获取）：
  - `scrollToIndex(index, { offset? = 0, animated? = true, duration? = 200 })` —— 有 `itemExtent` 时精确定位；否则按 `maxScrollExtent / (count - 1) * index` 估算
  - `scrollToTop({ animated? = true, duration? })`
  - `scrollToBottom({ animated? = true, duration? })`
  - `jumpTo(pixels)` / `animateTo(pixels, durationMs)`
- **GridView**: 网格列表，支持固定列数或最大宽度配置。Props 同 ListView 的滚动命令；`itemExtent` 映射为 `SliverGridDelegate` 的 `mainAxisExtent`（网格行高固定，`scrollToIndex` 按 `row = index ~/ crossAxisCount` 定位）。
- **SingleChildScrollView**: 滚动单个子组件，适用于表单等长页面。Ref 命令: `scrollToTop()`, `scrollToBottom()`。
- **CustomScrollView / Sliver系列**: 支持高级滚动效果（如吸顶 Header、混合列表等）。包含 `SliverAppBar`, `SliverList`, `SliverGrid`, `SliverToBoxAdapter`。
- **PageView**: 页面滑动切换组件。
- **NestedScrollView**: 嵌套滚动视图，用于协调外部 Sliver 头部与内部可滚动 body。通过 `FlutterProps propsKey="headerSliverBuilder"` 传入 Sliver 列表，`FlutterProps propsKey="body"` 传入主体组件。支持 `scrollDirection`, `reverse`, `physics`。

### itemBuilder 约束：无 React 生命周期

`itemBuilder` / `renderItem` 构造的 item **不经过 React Reconciler**，每次 Flutter 滚动到新位置时直接调用函数求值并生成 DSL，等价于"模板函数"而非真实组件。

**以下在 item 内无效：**

- `useState` / `useEffect` / `useRef` 等任意 Hook（会抛 "Invalid hook call"）
- `this.setState()`（能调但不触发重渲染）
- `componentDidMount` / `componentWillUnmount`

**根本原因**：Flutter `ListView.builder` 在 Dart 侧按需请求 item Widget，每次请求是一次跨线程同步 `ctx.invoke`，不维护 JS 侧 Fiber 状态。

#### 正确用法：状态上移

将所有 item 状态提升到父组件，通过 props 下传；父组件 setState 后，`itemBuilder` 闭包自动读到最新值。

```tsx
function MyList() {
  const [selected, setSelected] = useState<Set<number>>(new Set());

  return (
    <ListView
      itemCount={100}
      itemBuilder={(index) => (
        // item 本身是纯函数，无内部状态
        <ItemRow
          index={index}
          selected={selected.has(index)}
          onTap={() => setSelected((prev) => new Set(prev).add(index))}
        />
      )}
    />
  );
}

// ItemRow：纯函数组件，无 Hook
function ItemRow({
  index,
  selected,
  onTap,
}: {
  index: number;
  selected: boolean;
  onTap: () => void;
}) {
  return (
    <Container
      onTap={onTap}
      decoration={{ color: selected ? "#e0f0ff" : "#ffffff" }}
      padding={12}
    >
      <Text text={`Item ${index}${selected ? " ✓" : ""}`} />
    </Container>
  );
}
```

## 5. 动画组件

### 程序化动画（useAnimation Hook）

**`useAnimation(spec)`** 返回控制句柄，命令式驱动动画，与 Transition 系列互补（2026-08 新增）：

```tsx
const { id, value, transform, start, stop, reverse, reset, setValue, setTo, onComplete } =
  useAnimation({
    from: 0,          // 起始值
    to: 300,          // 目标值
    duration: 800,    // 毫秒
    curve: "easeInOut", // ease/easeIn/easeOut/linear/decelerate/linear
    loop: false,      // 循环播放
    reverse: false,   // 反向播放（配合 loop 可做往返）
    autoStart: false, // 挂载后自动播放
  });
```

- `value`：当前动画值（在 from~to 之间实时插值），可直接用于 `width/height/opacity` 等数值 prop
- `transform`：便捷变换对象 `{ scale, scaleX, scaleY, rotate, translateX, translateY }`（rotate 单位度），可直接传给 `Transform` 组件的同名 props
- 控制方法：`start()`, `stop()`, `reverse()`, `reset()`, `setValue(v)`（立即跳值，无动画）, `setTo(v)`（从当前值动画到目标值）
- `onComplete(fn)`：动画结束后回调（`loop` 时每次循环结束都会触发）
- 支持绑定动画引用的组件：`Opacity`（`opacity` prop 传 `anim` 对象）, `Transform`（`scale/scaleX/scaleY/rotate/translateX/translateY` 传 `anim` 对象）, `SizedBox`（`width/height`）, `Container`（`width/height`）
- 内部基于 `AnimationService` 注册表实现，同一页面内多个动画 id 唯一；页面销毁自动清理

### 隐式动画组件

- **AnimatedContainer**: 属性变更时自动执行补间动画的容器。支持 `onTap`/`onLongPress` 手势，以及 `constraints` 约束（与 Container 行为对齐）。
- **AnimatedOpacity**: 自动淡入淡出。
- **AnimatedAlign / AnimatedPadding**: 自动位置/边距动画。
- **AnimatedPositioned**: Stack 中的自动位移动画。
- **Transition系列**: `SlideTransition`, `ScaleTransition`, `RotationTransition` 等基于控制器驱动的动画。所有 Transition 组件统一支持以下动画驱动模式：
  - **静态终态**（默认）：未传 `duration` 时以 `AlwaysStoppedAnimation` 包装，常显目标值（向后兼容）。
  - **隐式动画驱动**：传 `duration`（毫秒）后走 `TweenAnimationBuilder`，在前一次值与当前值之间插值。可同时传 `curve` 缓动曲线（取值见 WidgetUtils.parseCurve：`ease`/`easeIn`/`easeOut`/`easeInOut`/`linear`/`decelerate`/`fastOutSlowIn`/`bounceIn`/`bounceOut`/`bounceInOut`/`elasticIn`/`elasticOut`/`elasticInOut`）。
- **FadeTransition**: 透明度过渡。Props: `opacity`（0.0~1.0，必填），`duration?`，`curve?`。
- **SizeTransition**: 沿指定轴对子节点做尺寸裁剪的过渡。Props: `sizeFactor`（0.0~1.0，必填），`axis`（horizontal/vertical，默认 vertical），`axisAlignment`（`top*`/`center*`/`bottom*` 字符串映射 0.0/0.5/1.0），`duration?`，`curve?`。
- **ScaleTransition**: Props: `scale`（必填），`alignment?`，`duration?`，`curve?`。
- **RotationTransition**: Props: `turns`（必填，1.0 = 一圈），`alignment?`，`duration?`，`curve?`。
- **SlideTransition**: Props: `position: { dx, dy }`（必填），`transformHitTests?`，`duration?`，`curve?`。
- **PositionedTransition**: 必须在 `Stack` 内使用的位移动画。Props: `end?: { left?, top?, right?, bottom? }`（终态），`begin?: { ... }`（起点，仅在传 duration 时生效；缺省与 end 相同），`duration?`，`curve?`。
- **Hero**: 用于两个路由间相同 `tag` 的"飞行"过渡。Props: `tag`（必填，唯一标识）。源/目标页 Hero 的 tag 一致时，Flutter 会在 Overlay 上自动播放飞行体动画。tag 缺失时安全降级为渲染子节点（不抛错）。
- **AnimatedSwitcher**: 当子组件 `key` 变化时自动执行切换动画，props: `duration`, `reverseDuration`, `switchInCurve`, `switchOutCurve`。
- **AnimatedCrossFade**: 在两个子组件之间执行交叉淡入淡出，通过 `FlutterProps propsKey="firstChild"` / `"secondChild"` 传入两个子组件，用 `crossFadeState: 'showFirst' | 'showSecond'` 控制显示。支持 `duration`, `firstCurve`, `secondCurve`, `sizeCurve`, `alignment`。

## 6. 功能性组件

- **Scaffold**: 页面脚手架，包含 `appBar`, `body`, `bottomNavigationBar`, `floatingActionButton` 等槽位。
- **AppBar**: 标准导航栏。
- **SafeArea**: 自动避开屏幕刘海和底部状态栏。
- **PopScope**: 拦截页面返回拦截（如二次确认退出）。
- **Visibility / VisibilityDetector**: 控制显隐及检测组件是否进入/离开可视区域。
- **RepaintBoundary**: 性能优化组件，通过隔离重绘区域提升渲染效率。
- **KeepAlive**: 在 PageView 或 Tab 中保持页面状态，避免重复触发生命周期。
- **Drawer**: 侧边抽屉导航组件，需通过 `Scaffold` 的 `drawer` / `endDrawer` prop 引用。支持 `backgroundColor`, `elevation`, `width`。
- **NavigationLink**: 声明式导航链接组件，带预热（prewarm）优化。Props: `url`（目标路由）, `params?`（路由参数）, `rootNavigator?`, `prewarmMs?`（默认 50ms，onTapDown 触发预热）, `hitSlop?`（点击热区 padding，默认 8）。用法：`<NavigationLink url="/detail" params={{ id: 1 }}><Text text="进入详情" /></NavigationLink>`。
  - 预热流程：`onTapDown` 触发 `NavigatorService.prewarm()` 提前渲染目标页面 DSL → `onTap` 调用 `push()` 时命中缓存，降低页面打开延迟。
  - `onTapCancel`（手指移出热区）自动取消预热。
- **LazyView**: 延迟加载视图。Props: `load?: boolean`（是否加载）, `fallback?: ReactNode`（未加载时占位，默认 `SizedBox(0,0)`）, `builder: () => ReactNode`（仅在 load=true 时执行）。`builder` 模式实现真正的延迟加载——只有 `load=true` 时才创建子组件，避免未展示组件的 DSL 生成开销。详见 [introduction.md §组件延迟加载](./introduction.md#组件延迟加载)。

---

## 7. 无障碍（Accessibility）

FuickJS 在 Flutter 侧 **widget factory 的唯一汇聚点**统一包裹 `Semantics`，因此**全部组件**自动获得无障碍语义能力，无需逐个组件单独适配。业务侧只需在 DSL 的 `props` 里透传语义属性即可被读屏（VoiceOver / TalkBack）识别。

### 7.1 两种写法

**完整写法** —— 传 `props.semantics` 对象，支持全部语义字段：

```tsx
<Button
  text="提交订单"
  semantics={{ label: '提交订单', hint: '双击提交', button: true }}
  onTap={submit}
/>
```

**简写** —— 仅需要标签时，直接用 `props.semanticLabel`：

```tsx
<Image src="images/logo.png" semanticLabel="公司 Logo" />
```

> 只在**显式传入** `semantics`（非空对象）或 `semanticLabel` 时才包裹 `Semantics`；不传则原样返回，**存量 UI 零影响**。

### 7.2 支持的语义字段

| 字段 | 类型 | 含义 |
| --- | --- | --- |
| `label` | string | 读屏朗读的主标签（最常用） |
| `hint` | string | 操作提示（如"双击提交"） |
| `value` | string | 当前值（如滑块当前数值） |
| `increasedValue` / `decreasedValue` | string | 增减后的提示值 |
| `onTapHint` / `onLongPressHint` | string | 点按 / 长按的语义提示 |
| `button` / `link` / `header` / `image` | bool | 标记节点语义角色 |
| `textField` / `readOnly` | bool | 标记可输入 / 只读 |
| `liveRegion` | bool | 内容变化时自动播报 |
| `hidden` | bool | 对读屏隐藏该节点 |
| `scopesRoute` / `namesRoute` | bool | 路由作用域 / 命名路由 |
| `enabled` | bool | 是否可交互 |
| `obscured` / `multiline` | bool | 密码遮罩 / 多行文本 |
| `selected` | bool | 是否被选中 |
| `toggled` | `'on' \| 'off' \| bool` | 开关态（三态） |
| `checked` | bool | 勾选态（如 Checkbox） |

> 字段与 Flutter `Semantics` 具名参数一一对应，跨 Flutter 版本兼容。完整实现见 `fuickjs_flutter/lib/core/widgets/widget_factory.dart` 的 `_applySemantics`。

### 7.3 最佳实践

- **交互组件必标 `label`**：`Button` / `Image`(可点) / `GestureDetector` 包裹区等，至少给一个 `label`，否则读屏用户无法感知用途。
- **列表项标 `value`**：`ListView` 的 `itemBuilder` 里，给每行 `semantics.value` 描述数据，避免只读坐标。
- **装饰性节点标 `hidden: true`**：纯分割线、背景图等对读屏无意义，隐藏减少干扰。
- 无障碍是**能力**不是**自动生效**：框架只负责把语义透传到 Flutter，业务需对关键交互组件补 `semantics` 字段才会被读屏识别。

---

## 如何添加新组件

1.  **JS 侧定义**:
    - 在 `fuickjs/src/widgets/` 下创建 `.tsx` 文件。
    - 定义 Props 接口，并使用 `React.createElement('WidgetName', props)` 返回。
2.  **Flutter 侧解析**:
    - 在 `fuickjs_flutter/lib/core/widgets/parsers/` 下创建 `widget_name_parser.dart`。
    - 继承 `WidgetParser` 并实现 `parse` 方法，将 JSON 映射为 Flutter Widget。
3.  **工厂注册**:
    - 在 `FuickWidgetFactory` 中关联新 Parser。
4.  **同步文档**:
    - 更新本列表，保持功能描述同步。
