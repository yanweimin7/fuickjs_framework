# fuickjs_dart — Dart 动态渲染方案

## 概述

`fuickjs_dart` 是 FuickJS 框架的 Dart 语言支持层。开发者用 Dart 编写 UI 代码，通过 `dart2js` 编译成 JS Bundle，经由 QuickJS 引擎执行，产出与 TS/React 完全兼容的 DSL JSON，最终由 Flutter WidgetFactory 渲染为真实 Widget 树。

全链路保留了动态下发能力——Bundle 可以从服务器下发，不需要重新发版。

---

## 完整链路

```
Dart 代码 (fuickjs_dart)
  ↓ dart2js 编译
JS Bundle (dart-demo.js)
  ↓ Flutter 加载 + QuickJS eval
QuickJS 执行环境
  ↓ dartCallNative('UI.renderUI', { pageId, renderData })
Flutter UIService
  ↓ controller.render(pageId, dsl)
WidgetFactory 解析 DSL
  ↓
Flutter Widget 树
```

---

## 目录结构

```
fuickjs_framework/fuickjs_dart/
├── pubspec.yaml
├── build.sh                          # 一键编译脚本
├── lib/
│   ├── fuickjs_dart.dart             # 统一导出入口
│   └── src/
│       ├── core/
│       │   ├── node.dart             # DslNode + ID 分配
│       │   ├── page_container.dart   # 页面状态、事件注册、rebuild、DSL 推送
│       │   ├── renderer.dart         # 多页面管理、事件分发
│       │   └── router.dart           # 路由注册 / 匹配
│       ├── state/
│       │   └── stateful_widget.dart  # FuickWidget / StatelessWidget / StatefulWidget / State
│       ├── widgets/
│       │   ├── types.dart            # EdgeInsets / BoxDecoration / BorderRadius / BoxConstraints
│       │   ├── widget_helpers.dart   # registerEvent 辅助
│       │   ├── container.dart        # container()
│       │   ├── text.dart             # text()
│       │   ├── column.dart           # column()
│       │   ├── row.dart              # row()
│       │   └── stack.dart            # stack() / positioned()
│       └── runtime/
│           ├── globals.dart          # bindGlobals() — 暴露 fuickjs 全局对象给 QuickJS
│           └── native.dart           # callNative() / callNativeAsync()
└── example/
    ├── main.dart                     # 示例页面（dart2js 编译入口）
    └── bundle.js                     # dart2js 编译产物（不提交）
```

---

## 核心设计

### DSL 节点格式

与 TS/React 运行时产出的格式完全一致：

```json
{
  "id": 123,
  "type": "Container",
  "props": {
    "width": 100,
    "color": "#FF0000",
    "onTap": {
      "id": 123,
      "nodeId": 123,
      "eventKey": "onTap",
      "pageId": 1,
      "isFuickEvent": true
    }
  },
  "children": [...]
}
```

### 状态管理

`StatefulWidget` + `State<T>` 模式，与 Flutter 原生 API 对齐：

```dart
class CounterPage extends StatefulWidget {
  @override
  State<CounterPage> createState() => _CounterState();
}

class _CounterState extends State<CounterPage> {
  int count = 0;

  @override
  void initState() {
    count = 0; // 初始化
  }

  @override
  DslNode build() {
    return column(children: [
      text('$count', fontSize: 24),
      container(
        onTap: () => setState(() => count++),
        children: [text('Increment')],
      ),
    ]);
  }
}
```

`setState` 触发流程：

```
setState(fn)
  → fn()              // 同步修改状态
  → _container.rebuild()
      → _callbacks.clear()           // 清空旧事件注册
      → state.build()                // 重新构建 DSL 树（重新注册事件）
      → dartCallNative('UI.renderUI', { pageId, renderData: dsl })
          → Flutter UIService → WidgetFactory 重渲染
```

### 事件机制

事件回调存储为 `void Function()`，dart2js 编译为 `.call$0()`，与 QuickJS 调用方式匹配：

```dart
// widget_helpers.dart
void registerEvent(DslNode node, String eventKey, void Function() fn) {
  final page = requirePage();
  node.props[eventKey] = page.registerEvent(node.id, eventKey, fn);
}
```

Flutter 通过 `ctx.invoke('fuickjs', 'dispatchEvent', [eventObj, payload])` 触发回调：

```
Flutter dispatchEvent
  → globals.dart _dispatchEvent(JSAny?, JSAny?)
      → dartify() 转成 Dart Map
  → renderer.dart dispatchEvent(map, payload)
      → page_container.dart dispatch(map, payload)
          → _callbacks[nodeId][eventKey]?.call()
```

### JS ↔ Flutter 双向通信

| 方向 | 函数 | 说明 |
|------|------|------|
| Dart → Flutter（同步） | `callNative(method, args)` | 等价于 TS 的 `dartCallNative` |
| Dart → Flutter（异步） | `callNativeAsync(method, args)` | 等价于 TS 的 `dartCallNativeAsync` |
| Flutter → Dart | `ctx.invoke('fuickjs', 'dispatchEvent', ...)` | 触发事件回调 |
| Flutter → Dart | `ctx.invoke('fuickjs', 'render', ...)` | 触发页面渲染 |

`callNative` / `callNativeAsync` 通过 JSON 序列化传参（绕开 dart2js 的 `jsify()` 扩展方法动态分发问题）：

```dart
// 同步调用 Native Service
callNative('Navigator.push', {'path': '/detail', 'params': {'id': 1}});

// 异步调用 Native Service
final result = await callNativeAsync<bool>('Dialog.showModal', {
  'title': '确认',
  'content': '是否继续？',
  'confirmText': '确定',
  'showCancel': true,
});
```

---

## QuickJS 环境兼容性

dart2js 编译产物依赖一些浏览器/Node.js 环境 API，QuickJS 不原生提供。目前通过以下方式解决：

| 缺失能力 | 解决方式 |
|----------|----------|
| `scheduleImmediate` | dart2js 微任务调度器 hook，`fuick_app_context.dart` 在 bundle eval 前注入（待实现） |
| `setImmediate` | 同上 |
| `self` / `window` | `globals.dart` 的 `bindGlobals()` 里设置 |

> **当前临时方案**：`scheduleImmediate` 和 `setImmediate` 由 `build.sh` 在 bundle 头部 prepend。
> **计划**：统一在 Flutter 引擎层 `fuick_app_context.dart` 的 `_doInit()` 完成后、`_loadBundle()` 之前注入，所有 bundle 类型（TS / Dart）共享同一套环境初始化。

---

## 构建流程

### 开发构建

```bash
cd fuickjs_framework/fuickjs_dart
./build.sh
# 等价于：
# dart compile js example/main.dart -o example/bundle.js
# cp example/bundle.js ../../fuickjs_demo/app/assets/js/dart-demo.js
```

### 指定自定义入口

```bash
./build.sh my_app/main.dart
```

### 静态分析

```bash
dart analyze
```

---

## 使用方式

### 1. 入口文件

```dart
import 'package:fuickjs_dart/fuickjs_dart.dart';

void main() {
  bindGlobals();  // 暴露 globalThis.fuickjs 给 QuickJS 引擎

  Router.register('/', (_) => const HomePage());
  Router.register('/detail', (params) => DetailPage(id: params?['id']));
}
```

### 2. Stateless 页面

```dart
class HomePage extends StatelessWidget {
  const HomePage();

  @override
  DslNode build() {
    return column(
      padding: const EdgeInsets.all(16),
      children: [
        text('Hello FuickJS Dart', fontSize: 24, fontWeight: 'bold'),
      ],
    );
  }
}
```

### 3. Stateful 页面

```dart
class CounterPage extends StatefulWidget {
  final int initial;
  const CounterPage({this.initial = 0});

  @override
  State<CounterPage> createState() => _CounterState();
}

class _CounterState extends State<CounterPage> {
  late int count;

  @override
  void initState() {
    count = widget.initial;
  }

  @override
  DslNode build() {
    return column(
      mainAxisAlignment: 'center',
      spacing: 12,
      children: [
        text('$count', fontSize: 32),
        container(
          onTap: () => setState(() => count++),
          children: [text('+ 1')],
        ),
      ],
    );
  }
}
```

### 4. 调用 Native Service

```dart
// 同步
callNative('Navigator.push', {'path': '/detail', 'params': {'id': 42}});

// 异步（fire-and-forget，不等返回值）
callNativeAsync('Dialog.showModal', {
  'title': '提示',
  'content': '操作成功',
  'confirmText': '好的',
  'showCancel': false,
});

// 异步（等待返回值）
final confirmed = await callNativeAsync<bool>('Dialog.showModal', {
  'title': '确认删除',
  'content': '此操作不可撤销',
  'confirmText': '删除',
  'cancelText': '取消',
});
if (confirmed == true) { ... }
```

---

## 已支持组件

| 函数 | 对应 Flutter Widget | 主要参数 |
|------|---------------------|----------|
| `container()` | `Container` | width/height/color/padding/margin/decoration/alignment/onTap/onLongPress |
| `text()` | `Text` | text/fontSize/color/fontWeight/textAlign/maxLines/overflow |
| `column()` | `Column` | mainAxisAlignment/crossAxisAlignment/mainAxisSize/spacing/padding |
| `row()` | `Row` | mainAxisAlignment/crossAxisAlignment/mainAxisSize/spacing/padding |
| `stack()` | `Stack` | alignment/fit/padding |
| `positioned()` | `Positioned` | top/left/right/bottom/width/height/child |

---

## 已知限制

- 目前只支持单层 `StatefulWidget`（根页面），嵌套 StatefulWidget 的 setState 尚未支持
- `onTap` 回调只支持 `void Function()`，暂不支持携带事件参数（如坐标、手势详情）
- `ListView` / `Image` / `Button` 等组件尚未实现，需后续扩展
- dart2js 产物体积较大（~250KB），可通过 `--minify` 压缩

---

## 与 TS/React 方案对比

| 维度 | TS/React 方案 | Dart 方案 |
|------|--------------|-----------|
| 开发语言 | TypeScript + React JSX | Dart |
| 状态管理 | React Hooks (useState) | StatefulWidget + setState |
| 编译工具 | esbuild | dart2js |
| Bundle 大小 | ~200KB | ~250KB |
| 动态下发 | ✅ | ✅ |
| 字节码支持 | ✅ | ❌（dart2js 不支持 QuickJS 字节码） |
| DSL 兼容性 | 原生支持 | 完全兼容 |
| Native Service 调用 | `dartCallNative` / `dartCallNativeAsync` | `callNative()` / `callNativeAsync()` |
