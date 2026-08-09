# FuickJS 技术介绍

## 概述

FuickJS 是一个基于 **React + QuickJS + Flutter** 的跨平台动态化渲染框架。开发者使用 React/TypeScript 编写 UI，代码在 Flutter App 内嵌的 QuickJS 引擎中执行，产出 JSON DSL，Flutter 端解析 DSL 实时构建原生 Widget 树。

核心设计理念：**用 React 的开发体验，写 Flutter 的原生性能**。

### 关键能力

- **原生渲染**：React 组件 → JSON DSL → Flutter 原生 Widget 树，无 WebView、无桥接卡顿。
- **动态下发**：业务代码以 QuickJS 字节码 / JS 源码形式动态下发，Ed25519 验签 + SHA-256 + 状态机 + 回滚（详见 [bundle-delivery.md](./bundle-delivery.md)）。
- **完整生态**：导航 / 路由守卫 / i18n / 主题 / 媒体 / 网络等 17+ 内置服务，以及 fetch / WebSocket / localStorage 等浏览器 API polyfill。
- **无障碍（Accessibility）**：widget 工厂在唯一汇聚点统一包裹 `Semantics`，业务用 `props.semantics` / `semanticLabel` 透传语义即可被读屏识别（详见 [widgets.md §7](./widgets.md)）。
- **错误可观测性**：JS 运行时错误被捕获并经 sourcemap 还原后，可通过可插拔 `ErrorSink` 聚合到 Sentry / Bugly / 自建平台（详见 [services.md](./services.md)）。
- **高性能增量更新**：IncrementalStrategy 只发送最小变更集；二进制协议 v2（varint + 字符串表）进一步压低传输体积（详见 [binary-protocol-v2.md](./binary-protocol-v2.md)）。

---

## 架构图

```
┌─────────────────────────────────────────────────────────────────┐
│                         Flutter App                                │
│                                                                   │
│  ┌──────────────────────────┐    ┌─────────────────────────────┐ │
│  │      QuickJS Engine       │◄───│    Flutter Widget Tree      │ │
│  │     (Isolate 隔离运行)     │    │   (根据 DSL 实时构建)        │ │
│  └──────────────┬───────────┘    └─────────────────────────────┘ │
│                 │                                                     │
│         ┌───────▼────────┐                                           │
│         │   JS Runtime   │                                           │
│         │   (fuickjs)    │                                           │
│         └───────┬────────┘                                           │
│                 │                                                     │
│  ┌──────────────┼───────────────────────────────────────────────┐  │
│  │              │                                                │  │
│  │  ┌───────────▼──────────┐   ┌──────────────┐   ┌────────────┐ │  │
│  │  │   React Reconciler   │──▶│  Node Tree   │──▶│   DSL      │ │  │
│  │  │     (hostConfig)     │   │  (PageContainer) │   │  (JSON)   │ │  │
│  │  └─────────────────────┘   └──────────────┘   └─────┬──────┘ │  │
│  │                                                     │          │  │
│  │  ┌──────────────────────────────────────────────────▼──────┐   │  │
│  │  │              Services / Polyfills                       │   │  │
│  │  │  NavigatorService │ TimerService │ fetch │ WebSocket   │   │  │
│  │  └────────────────────────────────────────────────────────┘   │  │
│  └────────────────────────────────────────────────────────────────┘  │
│                                                                   │
│  ┌──────────────────────────┐                                     │
│  │    Flutter Services       │                                     │
│  │  NavigationService │ UIService │ NativeEventService              │
│  └────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 核心模块

### 1. JS 端 (fuickjs)

| 模块             | 文件                                      | 职责                                                           |
| ---------------- | ----------------------------------------- | -------------------------------------------------------------- |
| React Reconciler | `core/renderer.ts` + `core/hostConfig.ts` | 实现 React 的 host config，将 React Element 转为内部 Node 树   |
| Node 树          | `core/node.ts`                            | 虚拟 DOM 节点，管理属性、回调、DSL 序列化                      |
| 页面容器         | `core/PageContainer.ts`                   | 单页面状态管理，持有回调映射表，触发增量更新                   |
| 渲染策略         | `strategies/`                             | DiffStrategy / IncrementalStrategy 计算最小变更集              |
| 运行时           | `runtime/runtime.ts`                      | `bindGlobals()` 注入 `window`、`fuickjs.*` 到 QuickJS 全局对象 |
| 路由             | `router/router.ts`                        | 页面注册与匹配，`Router.register(path, factory)`               |
| 服务             | `services/`                               | NavigatorService、NetworkService、TimerService 等              |
| Polyfills        | `polyfill/` + `ex/`                       | fetch、WebSocket、Storage、EventTarget 等 Web 标准 API         |

### 2. Flutter 端 (fuickjs_flutter)

| 模块                      | 职责                                           |
| ------------------------- | ---------------------------------------------- |
| `FuickAppView`            | Flutter Widget，作为 JS 引擎的宿主入口         |
| `FuickAppController`      | 管理页面生命周期、路由导航、服务绑定           |
| `FuickNavigationDelegate` | 实现 push / pop / showDialog / showBottomSheet |
| `WidgetParser`            | 将 JSON DSL 解析为 Flutter Widget              |
| `NativeEventService`      | JS ←→ Flutter 双向事件通道                     |

### 3. 引擎层 (fuickjs_core)

| 模块        | 职责                                                              |
| ----------- | ----------------------------------------------------------------- |
| QuickJS FFI | 通过 Flutter FFI 调用 QuickJS C 引擎                              |
| JSContext   | QuickJS 执行上下文管理，支持 `eval` / `evalBinary` / `compile`   |
| 字节码编译  | `compile()` 在端上将 JS 源码本地编译为 QuickJS 字节码（详见 README） |

---

## 渲染流程

### 首次渲染

```
1. Flutter 调用 fuickjs.render(pageId, path, params)
2. Router.match(path) 找到页面组件工厂函数
3. 工厂函数执行 React.createElement() 创建 React Element 树
4. React Reconciler 调用 hostConfig 的 appendChild / insertChild 等方法
5. hostConfig 创建 Node 对象并建立父子关系
6. Node.applyProps() 注册事件回调到 PageContainer 的回调表
7. 所有 Node 构建完成后，调用 root.commit() 触发 toDsl()
8. Node.toDsl() 递归将子树序列化为 JSON DSL
9. PageContainer 批量发送 renderUI + patchOps 到 Flutter
10. Flutter 端 WidgetParser 解析 DSL 生成 Widget 树并渲染
```

### 状态更新 (setState)

```
1. setState() 触发 React 进入重新渲染流程
2. Reconciler 调用 updateHostComponent() 对比新旧 Node
3. hostConfig 调用 Node.applyProps() 计算属性变更
4. hostConfig 调用 IncrementalStrategy.recordUpdate()
5. IncrementalStrategy 合并同一节点的多次更新
6. 批量发送 patchOps (UPDATE / INSERT / REMOVE) 到 Flutter
7. Flutter 端直接更新对应节点的 Widget，无需重建整棵树
```

---

## 增量更新策略

### DiffStrategy

比较新旧两棵 Node 树的差异，计算出最小变更集后一次性发送到 Flutter。

### IncrementalStrategy (默认)

只记录本次 commit 中实际发生变更的操作，合并同一节点的多次更新后批量发送。适用于高频更新场景（如列表滚动、动画）。

| OpCode       | 说明         |
| ------------ | ------------ |
| `1` (UPDATE) | 更新节点属性 |
| `2` (INSERT) | 插入新节点   |
| `3` (REMOVE) | 删除节点     |
| `4` (MOVE)   | 移动节点位置 |

---

## 事件系统

### Flutter → JS (事件派发)

```
用户点击 Flutter 按钮
  → Flutter 端查找 nodeId 对应的 callback
  → 调用 ctx.invoke('dispatchEvent', { pageId, nodeId, eventKey, payload })
  → JS 端 Renderer.dispatchEvent() 查找并执行回调函数
  → 回调函数可能触发 setState → 触发增量更新
```

### JS → Flutter (双向事件)

```typescript
// JS 监听 Native 事件
NativeEvent.on('onEventName', (data) => { ... });

// JS 向 Native 发事件
NativeEvent.emit('jsReady', { version: '1.0.0' });
```

---

## 核心 Hooks

| Hook                                   | 说明                                                  |
| -------------------------------------- | ----------------------------------------------------- |
| `usePageId()`                          | 获取当前页面 ID                                       |
| `useNavigator()`                       | 返回导航器：push / pop / showDialog / showBottomSheet |
| `useVisible(callback)`                 | 页面可见时触发 callback                               |
| `useInvisible(callback)`               | 页面不可见时触发 callback                             |
| `usePageConfig(config)`                | 配置 incrementalMode / dslCacheEnabled                |
| `useRouteTransitionComplete(callback)` | 路由动画结束后触发 (pageId, path)                     |
| `useTheme()`                           | 订阅宿主 ThemeData 快照，主题切换时自动重渲染          |
| `useMediaQuery()`                      | 订阅 MediaQuery 快照，屏幕旋转/键盘弹起/暗黑切换时重渲染 |

---

## 组件延迟加载

`LazyView` 组件支持 builder 模式，实现子组件的延迟加载：

```tsx
// children 在 JS bundle 加载时就已创建 React Element
<LazyView load={isReady}>
  <HeavyComponent />
</LazyView>

// builder 只在 load=true 时才执行，真正实现延迟加载
<LazyView load={isReady} builder={() => <HeavyComponent />} />
```

---

## 社区生态

fuickjs_community 维护独立功能包，通过 npm 发布：

| 包                                       | 说明       |
| ---------------------------------------- | ---------- |
| `@fuickjs-community/video_player`        | 视频播放   |
| `@fuickjs-community/web_view`            | WebView    |
| `@fuickjs-community/connectivity`        | 网络状态   |
| `@fuickjs-community/haptics`             | 触感反馈   |
| `@fuickjs-community/share`               | 分享       |
| `@fuickjs-community/app_info`            | App 信息   |
| `@fuickjs-community/permissions`         | 权限请求   |
| `@fuickjs-community/media`               | 媒体文件   |
| `@fuickjs-community/launcher`            | 启动器     |
| `@fuickjs-community/visibility_detector` | 可见性检测 |

---

## 快速开始

```typescript
// 1. 注册页面
Router.register('/home', (params) => <HomePage {...params} />);

// 2. 页面组件
function HomePage() {
  const nav = useNavigator();
  return (
    <Column>
      <Text text="Hello FuickJS" />
      <Button text="Go Detail" onTap={() => nav.push('/detail', { id: 1 })} />
    </Column>
  );
}

// 3. Flutter 集成
FuickAppView(
  appName: 'myapp',
  initialRoute: '/home',
)
```

---

## 性能优化

1. **IncrementalStrategy**：高频更新场景下只发送最小增量补丁
2. **DSL 缓存**：Node 树有 dirty 标记，只重新序列化变更节点
3. **DSL 解码快速路径**：`renderUI` / `patchUI` / `patchOps` 跳过扩展类型二次转换，减少 Dart 侧整树遍历
4. **字符串零拷贝解码**：二进制协议解码字符串时直接读取原始缓冲区片段，避免额外 `Uint8List` 分配
5. **二进制协议 v2（varint + 字符串表）**：整数用 zigzag/LEB128 变长编码（小整数 1 字节），重复的键名/字符串走流式字符串表回引。相比 v1 定长编码体积约降到 28%，相比 JSON 体积约 40%；编解码往返耗时比 JSON 快 2.5~3.3×、比 v1 快 1.14~1.47×（节点越多优势越大，5 轮实测波动 <5%）。默认开启，可用 `QuickJsFFI.setBinaryCodecV2(false)` 回退到 v1。详见 [binary-protocol-v2.md](./binary-protocol-v2.md)
6. **LazyView builder 模式**：heavy 组件延迟到 ready=true 时才创建
7. **回调引用稳定**：函数引用变化只更新 JS 侧回调映射，不触发 Flutter UI 重建
