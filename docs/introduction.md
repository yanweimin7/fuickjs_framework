# FuickJS 技术介绍

## 概述

FuickJS 是一个运行在 QuickJS 引擎中的动态化框架，其核心设计思想是：**用 React 的开发体验，写 Flutter 的原生性能**。JS 侧负责页面逻辑和组件树描述（React DSL），Flutter 侧负责根据 DSL 实时构建原生 Widget 树并渲染。两者之间通过双向桥接进行通信，JS 引擎嵌入在 Flutter App 的 Isolate 中。

---

## 核心原理

### 1. 三层架构

```
┌─────────────────────────────────────────────────────────┐
│                      Flutter App                         │
│  ┌─────────────────┐    ┌─────────────────────────────┐│
│  │  FuickJS Engine │    │    Flutter Widget Tree       ││
│  │  (QuickJS Isolate)│◄───│  (根据 JS DSL 实时构建)      ││
│  └────────┬────────┘    └─────────────────────────────┘│
│           │                                                   │
│           │  dartCallNative / dartCallNativeAsync             │
│           │  (Flutter → JS 同步/异步调用)                      │
│           ▼                                                   │
│  ┌─────────────────────────────────────────────────────────┐│
│  │                    JS 运行时 (fuickjs)                   ││
│  │  ┌──────────┐  ┌──────────┐  ┌──────────────────────┐  ││
│  │  │  React    │  │  Widgets  │  │  Services / Polyfills │  ││
│  │  │  Reconciler│  │  (DSL)    │  │  (fetch/WebSocket等)  │  ││
│  │  └──────────┘  └──────────┘  └──────────────────────┘  ││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────┘
```

**数据流向（渲染）**：

1. JS 侧 React 组件树通过 `hostConfig` 生成内部 Node 树
2. Node 树序列化为 JSON DSL
3. DSL 通过 `dartCallNative('UI.renderUI')` 发送到 Flutter
4. Flutter 侧的 DSL Parser 将 JSON 转换为 Widget 树

**数据流向（事件）**：

1. 用户在 Flutter 侧点击按钮
2. Flutter 通过 `invoke` 调用 JS 侧的 `dispatchEvent`
3. `dispatchEvent` 根据 `pageId` + `nodeId` + `eventKey` 找到对应回调并执行
4. 回调可能触发 `setState` → 产生新的 React 树 → 触发新的渲染

### 3. 增量更新策略（IncrementalStrategy）

为避免每次状态变化都全量重建 Widget 树，FuickJS 实现了两种渲染策略：

**DiffStrategy（全量 diff）**：比较新旧两棵 Node 树，计算出最小变更集后发送 patchOps 到 Flutter。

**IncrementalStrategy（增量更新）**：只记录本次 commit 中实际发生变更的操作（INSERT / REMOVE / UPDATE），合并同一节点的多次更新后批量发送到 Flutter。

Flutter 侧根据 `pageId` 维护自己的 Element 树，收到增量补丁后直接更新对应节点，无需重建整个树。

### 4. 双向桥接

| 方向                | 机制                                | 用途               |
| ------------------- | ----------------------------------- | ------------------ |
| Flutter → JS        | `ctx.invoke(method, args)`          | 事件派发、命令调用 |
| JS → Flutter (同步) | `dartCallNative(method, args)`      | UI 渲染、导航      |
| JS → Flutter (异步) | `dartCallNativeAsync(method, args)` | 文件 I/O、网络请求 |

### 5. Widget DSL 映射

JS 侧的每个 React 组件都对应一个 Flutter Widget。组件通过 `createElement` 产生 React Element，Element 的 `type` 决定生成的 Widget 类型。例如：

```typescript
// JS 侧
<Column>
  <Text text="Hello" />
  <Button text="Click" onTap={handleClick} />
</Column>

// 生成的 DSL (简化)
{
  type: "Column",
  children: [
    { type: "Text", props: { text: "Hello" } },
    { type: "Button", props: { text: "Click", eventHandlers: { onTap: "callback_0" } } }
  ]
}
```

Flutter 收到 DSL 后，通过 `WidgetParser` 映射表找到对应的 Widget 类型并构建真实 Widget。

---

## 支持的功能

### 1. 页面管理

- **页面挂载/卸载**：JS 侧维护 `PageContainer`，对应 Flutter 侧一个 `FuickPage`
- **页面生命周期**：`useVisible` / `useInvisible` hook 监听页面可见性变化
- **路由导航**：`NavigatorService.push` / `pop` / `showDialog` / `showBottomSheet`
- **页面配置**：`usePageConfig({ incrementalMode, dslCacheEnabled })`

### 2. 组件体系

完整覆盖 Flutter 基础组件，包括：

- **布局类**：`Container`, `Column`, `Row`, `Stack`, `Flex`, `Expanded`, `Wrap`, `Padding`, `Center`, `Align`
- **列表类**：`ListView`, `GridView`, `SliverList`, `SliverGrid`, `PageView`
- **交互类**：`Button`, `TextField`, `Checkbox`, `Switch`, `Slider`, `GestureDetector`, `InkWell`
- **展示类**：`Text`, `Image`, `Icon`, `CircularProgressIndicator`, `Divider`
- **动画类**：`AnimatedContainer`, `AnimatedOpacity`, `AnimatedScale`, `AnimatedSlide`, `AnimatedPositioned`, `AnimatedRotation`, `AnimatedCrossFade`, `AnimatedSwitcher`
- **高级**：`CustomScrollView`, `NestedScrollView`, `SliverAppBar`, `RefreshIndicator`, `BackdropFilter`, `ClipRRect`, `ClipPath`, `ColorFiltered`
- **表单**：`TextField`（支持 `ref` 命令：`setText`, `focus`, `unfocus`, `selectAll` 等）
- **导航**：`AppBar`, `BottomNavigationBar`, `Drawer`, `Scaffold`
- **列表项命令**：`ListView` / `GridView` 支持 `updateItem(index, dsl)` / `updateItems(items)` 局部更新

### 3. 原生服务（Services）

| 服务                  | 说明                                                            |
| --------------------- | --------------------------------------------------------------- |
| `NavigatorService`    | 页面导航（push/popReplace/showDialog/showBottomSheet）          |
| `TimerService`        | `setTimeout` / `setInterval` / `clearTimeout` / `clearInterval` |
| `NetworkService`      | HTTP 请求（对应 Flutter 侧的 `http` package）                   |
| `LocalStorageService` | 持久化键值存储                                                  |
| `FileSystemService`   | 文件读写（readFile/writeFile 等，同步/异步均有）                |
| `ClipboardService`    | 剪贴板读写                                                      |
| `DeviceInfoService`   | 设备信息（appVersion, osVersion 等）                            |
| `ToastService`        | 轻提示                                                          |
| `DialogService`       | 原生对话框                                                      |
| `PickerService`       | 选择器                                                          |
| `UIService`           | Flutter Widget 命令（componentCommand / patchOps 等）           |

### 4. 浏览器 Polyfill

完整实现了 Web 标准 API，确保业务代码无需修改即可在 JS 引擎中运行：

- **`fetch`**：完整的 `fetch` API + `Headers` / `Request` / `Response`
- **`XMLHttpRequest`**：传统 Ajax 请求
- **`WebSocket`**：双向实时通信，与 Flutter 侧 WebSocket 桥接
- **`AbortController` / `AbortSignal`**：请求取消，支持 `AbortSignal.timeout()`
- **`Storage`**：`localStorage` / `sessionStorage`，通过 `LocalStorageService` 持久化
- **`Event`** / **`CustomEvent`** / **`EventTarget`**：标准事件系统
- **`URL`** / **`URLSearchParams`**：URL 解析
- **`Blob`**：二进制大对象
- **`btoa`** / **`atob`**：Base64 编解码
- **`performance.now()`**：高精度时间

### 5. React Hooks

| Hook                     | 说明                                                 |
| ------------------------ | ---------------------------------------------------- |
| `usePageId()`            | 获取当前页面 ID                                      |
| `useNavigator()`         | 获取导航器（含 push/pop/showDialog/showBottomSheet） |
| `useVisible(callback)`   | 页面可见时触发 callback                              |
| `useInvisible(callback)` | 页面不可见时触发 callback                            |
| `usePageConfig(config)`  | 配置增量模式 / DSL 缓存                              |

### 6. 状态管理

- **`useState`**：React 标准用法，支持在函数组件中管理局部状态
- **`useEffect`**：React 标准用法，支持副作用清理
- **`FlutterProps`**：特殊组件，用于向 Flutter 原生 Widget 传递结构化属性（如 AppBar 的 title 组件）

### 7. JS-Native 双向事件

```typescript
// JS 监听 Native 事件
NativeEvent.on("onEventName", (data) => {
  /* ... */
});

// JS 向 Native 发事件
NativeEvent.emit("jsReady", { version: "1.0.0" });
```

### 8. 错误处理

- **`ErrorBoundary`**：React 错误边界组件，捕获子组件渲染异常
- **`ErrorHandler.notify(error, source, detail)`**：全局错误上报
- **Sourcemap 还原**：线上压缩代码的错误堆栈可通过 `tools/resolve-sourcemap.mjs` 还原

---

## 使用示例

### 1. 页面定义与导航

```typescript
import React, { useState, useEffect } from 'react';
import { Column, Text, Button, useNavigator, usePageId } from 'fuickjs';

export default function HomePage() {
  const nav = useNavigator();
  const pageId = usePageId();

  return (
    <Column>
      <Text text="首页" />
      <Button
        text="跳转到详情"
        onTap={() => nav.push('/detail', { id: 123 })}
      />
      <Button
        text="显示弹窗"
        onTap={() => nav.showDialog(<MyDialog />)}
      />
    </Column>
  );
}
```

### 2. 带状态的列表页面

```typescript
import React, { useState, useEffect } from 'react';
import { ListView, Text, Image, Column, GestureDetector } from 'fuickjs';
import { fetch } from 'fuickjs';

interface Item {
  id: number;
  title: string;
  imageUrl: string;
}

export default function ListPage() {
  const [items, setItems] = useState<Item[]>([]);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    loadData();
  }, []);

  async function loadData() {
    setLoading(true);
    try {
      const res = await fetch('/api/items');
      const data = await res.json();
      setItems(data);
    } finally {
      setLoading(false);
    }
  }

  return (
    <ListView
      itemCount={items.length}
      itemBuilder={(index) => (
        <GestureDetector
          onTap={() => console.log('点击了', items[index].id)}
        >
          <Column>
            <Image src={items[index].imageUrl} />
            <Text text={items[index].title} />
          </Column>
        </GestureDetector>
      )}
    />
  );
}
```

### 3. 动态更新列表项

```typescript
import React, { useState, useRef } from 'react';
import { ListView, Button, Text, Column } from 'fuickjs';

export default function DynamicListPage() {
  const listRef = useRef<ListView>(null);
  const [count, setCount] = useState(5);

  function updateItem(index: number) {
    listRef.current?.updateItem(index, (
      <Text text={`更新后的文本 #${index}`} />
    ));
  }

  function updateMultiple() {
    listRef.current?.updateItems([
      { index: 0, dsl: <Text text="新的第0项" /> },
      { index: 2, dsl: <Text text="新的第2项" /> },
    ]);
  }

  return (
    <Column>
      <ListView
        ref={listRef}
        itemCount={count}
        itemBuilder={(index) => <Text text={`第 ${index} 项`} />}
      />
      <Button text="更新第0项" onTap={() => updateItem(0)} />
      <Button text="批量更新" onTap={updateMultiple} />
      <Button text="添加一项" onTap={() => setCount(c => c + 1)} />
    </Column>
  );
}
```

### 4. 页面可见性监听

```typescript
import React, { useEffect, useState } from 'react';
import { Text, useVisible, useInvisible } from 'fuickjs';
import { fetch } from 'fuickjs';

export default function PollingPage() {
  const [price, setPrice] = useState(0);
  let intervalId: number;

  useVisible(() => {
    // 页面进入前台，开始轮询
    intervalId = setInterval(async () => {
      const res = await fetch('/api/price');
      const data = await res.json();
      setPrice(data.price);
    }, 5000);
  });

  useInvisible(() => {
    // 页面进入后台，停止轮询
    clearInterval(intervalId);
  });

  return <Text text={`当前价格: $${price}`} />;
}
```

### 5. Dialog 和 BottomSheet

```typescript
import React from 'react';
import { Column, Text, Button, useNavigator } from 'fuickjs';

function MyDialog() {
  const nav = useNavigator();

  return (
    <Column>
      <Text text="这是一个 Dialog" />
      <Button text="关闭" onTap={() => nav.pop()} />
    </Column>
  );
}

function MyBottomSheet() {
  const nav = useNavigator();

  return (
    <Column>
      <Text text="这是 BottomSheet" />
      <Button text="关闭" onTap={() => nav.pop()} />
    </Column>
  );
}

// 使用
<Button text="打开 Dialog" onTap={() => nav.showDialog(<MyDialog />)} />
<Button
  text="打开 BottomSheet"
  onTap={() => nav.showBottomSheet(<MyBottomSheet />, { minHeight: 200 })}
/>
```

### 6. 使用 WebSocket 实时通信

```typescript
import React, { useEffect, useState } from 'react';
import { Text, Column } from 'fuickjs';

export default function WebSocketPage() {
  const [ws, setWs] = useState<WebSocket | null>(null);
  const [messages, setMessages] = useState<string[]>([]);

  useEffect(() => {
    const socket = new WebSocket('wss://example.com/ws');

    socket.onopen = () => console.log('连接已建立');
    socket.onmessage = (event) => {
      setMessages(prev => [...prev, event.data]);
    };
    socket.onerror = (error) => console.error('WebSocket 错误:', error);
    socket.onclose = () => console.log('连接已关闭');

    setWs(socket);

    return () => {
      socket.close();
    };
  }, []);

  function sendMessage() {
    ws?.send('Hello from JS');
  }

  return (
    <Column>
      <Button text="发送消息" onTap={sendMessage} />
      {messages.map((msg, i) => <Text key={i} text={msg} />)}
    </Column>
  );
}
```

### 7. 使用 fetch + AbortController 取消请求

```typescript
import React, { useEffect } from 'react';
import { Text, Button, Column } from 'fuickjs';
import { fetch, AbortController } from 'fuickjs';

export default function FetchPage() {
  let controller: AbortController;

  async function fetchWithCancel() {
    controller = new AbortController();

    try {
      const res = await fetch('/api/slow-endpoint', {
        signal: controller.signal,
      });
      const data = await res.json();
      console.log('数据:', data);
    } catch (e: any) {
      if (e.name === 'AbortError') {
        console.log('请求已取消');
      }
    }
  }

  function cancelRequest() {
    controller?.abort();
  }

  return (
    <Column>
      <Button text="发起请求" onTap={fetchWithCancel} />
      <Button text="取消请求" onTap={cancelRequest} />
    </Column>
  );
}
```

---
