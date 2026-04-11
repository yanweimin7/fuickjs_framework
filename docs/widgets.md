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
- **Align**: 精确控制子组件在父容器中的位置。
- **ConstrainedBox**: 为子组件设置额外的约束（最大/最小宽高度）。
- **Wrap**: 流式布局，当空间不足时自动折行。
- **AspectRatio**: 按指定宽高比约束子组件尺寸，props: `aspectRatio`（必填）。
- **FractionallySizedBox**: 按父容器的百分比控制子组件尺寸，props: `widthFactor`, `heightFactor`, `alignment`。

## 2. 交互与输入
- **Button**: 原生按钮。Props: `text`, `onTap`, `disabled`, `loading`, `backgroundColor`, `textColor`, `fontSize`, `borderRadius`, `elevation`, `outlined`（OutlinedButton 变体）, `borderColor`, `borderWidth`, `minWidth`, `minHeight`, `paddingH`, `paddingV`。
- **InkWell**: 水波纹点击效果，可包裹任何组件使其具备交互能力。
- **GestureDetector**: 万能手势检测，支持 `onTap`, `onLongPress`, `onDoubleTap` 等。
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
  - 核心 props：`src`（推荐）/ `url`（兼容）、`fit`、`tintColor`（推荐）/ `color`（兼容）、`placeholderColor`、`errorSrc`、`gaplessPlayback`、`onLoad`、`onError`
- **Icon**: 显示 Material Design 图标。
- **RichText**: 富文本组件，支持在同一行显示不同样式的文本片段。
- **CircularProgressIndicator**: 圆形进度条。
- **Divider**: 分割线。
- **BackdropFilter**: 对背景施加模糊或图像滤镜效果，props: `sigmaX`, `sigmaY`, `blendMode`。需配合 `ClipRRect` 或透明容器使用。
- **DecoratedBoxOutline**: CSS `outline` 实现，在子组件外侧绘制边框。Props: `width`, `color`, `style`, `offset`。由 View.tsx 从 CSS `outline` 属性自动包裹。
- **ClipPath**: CSS `clip-path` 实现。支持 `circle()`/`ellipse()`/`inset()`/`polygon()` 形式。Props: `path`（CSS clip-path 值字符串）。
- **ColorFiltered**: CSS `mix-blend-mode` 实现，通过 `ShaderMask` + `BlendMode` 模拟混合模式。Props: `blendMode`。

## 4. 滚动列表
- **ListView**: 高性能线性列表，支持 `itemBuilder` 按需渲染（Lazy Loading）。
- **GridView**: 网格列表，支持固定列数或最大宽度配置。
- **SingleChildScrollView**: 滚动单个子组件，适用于表单等长页面。
- **CustomScrollView / Sliver系列**: 支持高级滚动效果（如吸顶 Header、混合列表等）。包含 `SliverAppBar`, `SliverList`, `SliverGrid`, `SliverToBoxAdapter`。
- **PageView**: 页面滑动切换组件。
- **NestedScrollView**: 嵌套滚动视图，用于协调外部 Sliver 头部与内部可滚动 body。通过 `FlutterProps propsKey="headerSliverBuilder"` 传入 Sliver 列表，`FlutterProps propsKey="body"` 传入主体组件。支持 `scrollDirection`, `reverse`, `physics`。

## 5. 动画组件
- **AnimatedContainer**: 属性变更时自动执行补间动画的容器。支持 `onTap`/`onLongPress` 手势，以及 `constraints` 约束（与 Container 行为对齐）。
- **AnimatedOpacity**: 自动淡入淡出。
- **AnimatedAlign / AnimatedPadding**: 自动位置/边距动画。
- **AnimatedPositioned**: Stack 中的自动位移动画。
- **Transition系列**: `SlideTransition`, `ScaleTransition`, `RotationTransition` 等基于控制器驱动的动画。
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
