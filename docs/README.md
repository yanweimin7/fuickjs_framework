# FuickJS Framework 官方文档

## 项目结构

### JS 框架层 (`fuickjs/`)
- `src/widgets`: 映射到 Flutter 组件的 React 组件。
- `src/services`: 用于 JS-Native 通信的原生桥接服务。
- `src/ex`: 浏览器标准 API 补丁 (fetch, storage 等)。
- `src/renderer.ts`: 核心 React 渲染器 (Reconciler) 与渲染逻辑。

### Flutter 框架层 (`fuickjs_flutter/`)
- `lib/core/widgets/parsers`: 将 JS DSL 转换为 Flutter Widget 的解析器。
- `lib/core/service`: 桥接服务的原生实现。
- `lib/core/engine`: QuickJS 引擎集成与 Isolate 管理。

## 文档索引

- [技术介绍（原理、架构、功能、使用示例）](./introduction.md)
- [UI 组件 (Widgets)](./widgets.md)
- [原生服务 & 浏览器 API](./services.md)
- [Community 扩展包](./community.md)
- [fuickjs_dart — Dart 动态渲染方案](./fuickjs_dart.md)
- [框架审计报告](./audit-report.md)

## 开发规范

**重要：** 任何代码修改或新增都**必须**同步更新本目录下的相关文档。

---

## 核心特性

### 1. Fuick.expose（暴露 JS 对象给 Native）

`Fuick.expose` 将 JS 侧对象实例挂载到全局，使 Flutter 侧可通过 `ctx.invoke` 主动调用。

```typescript
import { Fuick } from 'fuickjs';

const MyManager = {
  doSomething(data: any) {
    console.log('Native called JS with:', data);
    return { success: true };
  }
};

Fuick.expose('MyManager', MyManager);
```

**Native 侧调用 (Dart)**
```dart
final result = await ctx.invoke('MyManager', 'doSomething', [{'key': 'value'}]);
```

---

### 2. NativeEvent（双向事件总线）

`NativeEvent` 是标准的发布/订阅系统，用于 JS 与 Native 之间的异步事件通信。默认已通过 `Fuick.expose('NativeEvent', ...)` 暴露给原生侧。

**JS 侧**
```typescript
import { NativeEvent } from 'fuickjs';

// 监听原生事件
const unlisten = NativeEvent.on('onDeviceRotation', (data) => {
  console.log('设备旋转:', data);
});
unlisten(); // 组件卸载时取消

// 向原生发送事件
NativeEvent.emit('jsReady', { version: '1.0.0' });
```

**Native 侧 (Dart)**
```dart
final eventService = controller.getService<NativeEventService>();

// 发送事件给 JS
eventService?.emit('onDeviceRotation', {'angle': 90});

// 监听来自 JS 的事件
final unbind = eventService?.on('jsReady', (data) {
  print('收到来自 JS 的事件: $data');
});
unbind?.call(); // 不需要时取消
```

---

### 3. Router（路由系统）

轻量级路由注册，管理路径到 React 页面的映射。

```typescript
import { Router } from 'fuickjs';
import HomePage from './pages/HomePage';
import DetailPage from './pages/DetailPage';

Router.register('/', () => <HomePage />);
Router.register('/detail', (params) => <DetailPage id={params.id} />);
```

---

### 4. Hooks（React 钩子）

| Hook | 说明 |
|---|---|
| `usePageId()` | 获取当前页面唯一 ID |
| `useNavigator()` | 获取导航对象，含 `push` / `pop` / `showModal` / `showDialog` |
| `useVisible(cb)` | 页面进入前台时触发 |
| `useInvisible(cb)` | 页面进入后台时触发 |
| `usePageConfig(config)` | 配置页面级渲染参数（`incrementalMode` / `dslCacheEnabled`） |

```typescript
import { useNavigator, useVisible, usePageConfig } from 'fuickjs';

export function MyPage() {
  const nav = useNavigator();

  usePageConfig({ dslCacheEnabled: false }); // 高动态页面可关闭 DSL 缓存

  useVisible(() => {
    console.log('页面进入前台');
  });

  return <Button text="跳转" onTap={() => nav.push('/next')} />;
}
```

---

### 5. DSL 渲染与缓存

React 组件树被转换为 JSON DSL 发送给 Flutter，Flutter 根据 DSL 构建真实 Widget 树。

**缓存失效规则**
- 节点 props 变更 → 该节点 DSL 标记 dirty
- 子节点增删 → 该节点及父节点缓存失效
- 失效信号递归向上传播；透明节点（如 `FlutterProps`）自动穿透，确保最近实体 Widget 重新生成 DSL

**页面级配置**：通过 `usePageConfig({ dslCacheEnabled: false })` 关闭缓存，适用于大量动画或高频更新的页面。

---

### 6. Sourcemap 错误还原

线上 JS Bundle 压缩后，错误堆栈行列号指向压缩代码。工具位于 `fuickjs_framework/tools/resolve-sourcemap.mjs`。

**安装依赖（首次）**
```bash
cd fuickjs_framework/tools && npm install
```

**还原单个行列号**
```bash
node resolve-sourcemap.mjs ../../fuickjs_demo/js/dist/bundle.js.map 35194 1
```

**还原完整 stack trace**
```bash
# 从文件
node resolve-sourcemap.mjs <mapFile> --stack ~/stack.txt
# 直接传文本
node resolve-sourcemap.mjs <mapFile> --text "at parseUserData (bundle.js:35194:1)"
```

**构建时开启 sourcemap**（`fuickjs_demo/js/esbuild.js`）
```js
const commonOptions = {
  sourcemap: true,  // prod 也要开，.map 文件不打包进 App，保存到构建服务器
  minify: isProd,
};
```

**注意**：QuickJS 内部将 bundle 命名为 `input.js`，保存 stack 文件时需将 `input.js` 替换为 `bundle.js` 后再查询 sourcemap。
