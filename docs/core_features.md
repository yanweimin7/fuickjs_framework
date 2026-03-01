# FuickJS 核心特性指南

本文档介绍 FuickJS 框架的核心功能，包括 JS 与 Native 的双向通信机制、全局对象暴露以及路由系统。

## 1. Fuick.expose (暴露 JS 对象给 Native)

`Fuick.expose` 是框架提供的一个关键工具，用于将 JS 侧的对象实例挂载到全局，使其能够被 Flutter 侧通过 `ctx.invoke` 主动调用。

### 使用方法
```typescript
import { Fuick } from 'fuickjs';

const MyManager = {
  doSomething(data: any) {
    console.log('Native called JS with:', data);
    return { success: true };
  }
};

// 暴露给 Native
Fuick.expose('MyManager', MyManager);
```

### Native 侧调用 (Dart)
```dart
final result = await ctx.invoke('MyManager', 'doSomething', [{'key': 'value'}]);
```

## 2. NativeEvent (双向事件总线)

`NativeEvent` 是一个标准的发布/订阅系统，专门用于 JS 与 Native 之间的异步事件通信。它已默认通过 `Fuick.expose('NativeEvent', ...)` 暴露给原生侧。

### JS 侧使用
- **监听原生事件**:
  ```typescript
  import { NativeEvent } from 'fuickjs';

  const unlisten = NativeEvent.on('onDeviceRotation', (data) => {
    console.log('设备旋转:', data);
  });

  // 在组件卸载时取消监听
  unlisten();
  ```
- **向原生发送事件**:
  ```typescript
  NativeEvent.emit('jsReady', { version: '1.0.0' });
  ```

### Native 侧使用 (Dart)
- **发送事件给 JS**:
  原生侧通过获取 `NativeEventService` 实例并调用其 `emit` 方法：
  ```dart
  final eventService = controller.getService<NativeEventService>();
  eventService?.emit('onDeviceRotation', {'angle': 90});
  ```
  该方法内部会自动调用 JS 侧暴露的 `NativeEvent.receive`。

- **监听来自 JS 的事件**:
  原生侧通过 `NativeEventService` 的 `on` 方法进行监听：
  ```dart
  final unbind = eventService?.on('jsReady', (data) {
    print('收到来自 JS 的事件: $data');
  });
  
  // 在不需要时取消监听
  unbind?.call();
  ```

## 3. Router (路由系统)

FuickJS 提供了一个轻量级的路由注册机制，用于管理不同路径对应的 React 页面。

### 注册路由
```typescript
import { Router } from 'fuickjs';
import HomePage from './pages/HomePage';
import DetailPage from './pages/DetailPage';

Router.register('/', () => <HomePage />);
Router.register('/detail', (params) => <DetailPage id={params.id} />);
```

## 4. Hooks (React 钩子)

框架提供了一系列自定义 Hook，方便在函数组件中访问框架能力。

- **usePageId()**: 获取当前页面的唯一 ID。
- **useNavigator()**: 获取导航对象，包含 `push`, `pop`, `showModal`, `showDialog` 等方法。
- **useDialog()**: 获取对话框控制对象，包含 `show` 和 `dismiss`。
- **useVisible(callback)**: 监听页面变为可见状态的生命周期。
- **useInvisible(callback)**: 监听页面变为不可见状态的生命周期。

### 使用示例
```typescript
import { useNavigator, useVisible } from 'fuickjs';

export function MyPage() {
  const nav = useNavigator();
  
  useVisible(() => {
    console.log('页面进入前台');
  });

  return (
    <Button text="跳转" onTap={() => nav.push('/next')} />
  );
}
```

## 5. 渲染核心概念

- **PageContainer**: 每个页面都有一个独立的 `PageContainer` 容器，负责持有 React 根节点、管理该页面的回调函数（Callbacks）以及生成渲染 DSL。
- **DSL (Domain Specific Language)**: React 组件树被转换为一个 JSON 结构的 DSL 发送给 Flutter，Flutter 根据该结构构建真实的 Widget 树。
- **节点更新**: 框架支持全量渲染（Full Render）和增量更新（Patch/Ops），以确保复杂的 UI 变动也能保持流畅。
