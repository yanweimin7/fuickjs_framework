# 原生服务 & 浏览器 API

本文档覆盖两类桥接能力：
1. **原生服务**（`fuickjs/src/services/` ↔ `fuickjs_flutter/lib/core/service/`）：JS 主动通过服务类调用 Flutter。
2. **浏览器 API 补丁**（`fuickjs/src/ex/` & `fuickjs/src/polyfill/`）：将 Web 标准 API 模拟到 QuickJS 环境，底层仍依赖原生服务桥接。

---

## 一、原生服务（Native Services）

### 1. 导航 (NavigatorService)
- `push(path, params?)`: 推入新页面
- `pushReplace(path, params?)`: 替换当前页面
- `pop(result?)`: 关闭当前页面并向上一页返回结果
- `popTo(routeName)`: 回退到指定路由
- `showModal(path, params?, options?: { minHeight?, maxHeight? })`: 弹半屏 BottomSheet
- `showDialog(pathOrComponent, params?)`: 弹对话框（支持路径或 React 组件）

### 2. 界面与交互

**Dialog（对话框）**
- `show(content, options?: { pageId?, barrierDismissible?, barrierColor? })`: 弹自定义 DSL 对话框，支持多层嵌套
- `dismiss(result?)`: 关闭最上层对话框

**Toast（简短提示）**
- `show(message, duration?)`: 显示全局 Toast

**Overlay（全局悬浮层）**
- `show(key, element, pageId?)`: 在视图层之上显示悬浮组件
- `hide(key)`: 移除指定 key 的悬浮层

**UIService（底层 UI 控制）**
- `isWidgetRegistered(type): boolean`: 检查 Widget 类型是否已在 Flutter 侧注册 parser
- `componentCommand(pageId, refId, method, args, nodeType)`: 向原生组件发指令（如滚动列表跳转）

**PickerService（选择器）**
- `showPicker({ range, value?, title?, cancelText?, confirmText? })`: 单列选择
- `showMultiPicker({ range: string[][], value?: number[], ... })`: 多列联动选择
- `showDatePicker({ value?: 'YYYY-MM-DD', start?, end? })`: 日期选择

**MediaService（多媒体）**
- `chooseImage(count?, sourceType?: ('album' | 'camera')[])`: 选图，返回 `{ tempFilePaths, tempFiles }`
- `chooseVideo(sourceType?)`: 选视频，返回 `{ tempFilePath, size, type }`

**SoundService（声音/触觉，仅 Flutter 侧）**
- `Sound.play({ type: 'move' | 'capture' | 'check' | 'win' })`: 播放系统音效并触发 HapticFeedback，通过 `dartCallNative('Sound.play', ...)` 调用

### 3. 系统能力

**ClipboardService（剪贴板）**
- `setData(text): Promise<void>` / `getData(): Promise<string>`

**DeviceInfo（设备信息）**
- `getDeviceInfo(): Promise<DeviceInfoData>`: OS、版本、屏幕宽高、像素比等

**LocalStorage（本地存储）**
- `getItem(key) / setItem(key, value) / removeItem(key) / clear()` — 均为异步

**TimerService（定时器）**
- 驱动 JS 侧全局 `setTimeout` / `setInterval`，开发者直接用全局函数即可

### 4. 网络与文件

**NetworkService（网络）**
- `fetch(url, method, headers, body?, requestId?)`: 底层 fetch 实现
- `cancel(requestId)`: 中断请求

**fs（FileSystem）**
- `readFile(path, options?)` / `writeFile(path, data, options?)`
- `unlink(path)` / `mkdir(path, options?)` / `rmdir(path, options?)`
- `readdir(path)` / `stat(path)` / `exists(path)`
- `rename(oldPath, newPath)` / `copyFile(src, dest)`
- `getDirectories()`: 系统常用目录（Documents、Temp 等）

**WebSocketService（仅 Flutter 侧，JS 侧通过 `WebSocket` polyfill 使用）**
- Client 模式：`connect` / `send` / `close`
- Server 模式：`listen` / `sendToClient` / `stopListen`

### 5. 调试与事件

**ConsoleService**
- 拦截 JS `console.log/warn/error`，转发到原生

**NativeEventService**
- 双向事件总线，详见 [README.md §2 NativeEvent](./README.md#2-nativeevent双向事件总线)

---

## 二、浏览器 API 补丁

FuickJS 在 QuickJS 环境中补齐了 Web 标准 API，通过 Flutter 原生能力高性能模拟。

### 网络通信
- **fetch**: 支持 GET/POST/PUT/DELETE/PATCH；通过 `AbortController` + `AbortSignal` 真正取消请求；响应支持 `.json()` / `.text()`
- **XMLHttpRequest**: 完整 `readyState` 状态机；事件 `onload/onerror/onreadystatechange`；`responseType = 'json'`；仅异步（同步调用会回退为异步）
- **WebSocket**: W3C 标准接口（`new WebSocket(url, protocols?)`、`onopen/onmessage/onerror/onclose`、`send/close`），底层由 `WebSocketService` 驱动

### 数据存储
- **localStorage**: Web 一致接口（`setItem/getItem/removeItem/clear`），持久化到 Flutter `SharedPreferences`
- **sessionStorage**: 会话级存储，JS 上下文销毁前有效

### 工具与编码
- **atob / btoa**: Base64 编解码；**Unicode 增强**：原生 `btoa` 不支持非 Latin1 字符，内部自动 UTF-8 转换
- **URL / URLSearchParams**: 完整 URL 解析与查询字符串构造
- **TextEncoder / TextDecoder**: 字符串 ↔ `Uint8Array` 编解码
- **Buffer**: Node.js 兼容 API 子集
- **structuredClone(value)**: 标准深拷贝，支持 `Date / RegExp / Map / Set / ArrayBuffer / TypedArray`、循环引用；不支持 Function / DOM 节点（QuickJS 环境无 DOM）
- **Blob**: `new Blob(parts, { type })`、`size`、`type`、`slice(start, end, contentType?)`、`arrayBuffer()`、`text()`；`stream()` 未支持

### 定时器与异步
- **setTimeout / setInterval / clearTimeout / clearInterval**: 毫秒级精度，底层由 Flutter `Timer` 驱动

### 事件与性能
- **EventTarget / Event / CustomEvent**: 完整 DOM 事件模型（`addEventListener/removeEventListener/dispatchEvent`）
- **performance**: `performance.now()` 返回自引擎启动以来的高精度毫秒数

### 其他 Polyfill
- **crypto**:
  - `getRandomValues(array)`: 填充随机字节
  - `randomUUID()`: 生成 RFC 4122 v4 UUID
  - `subtle`: 部分 SubtleCrypto（digest / importKey / deriveBits(PBKDF2) / AES 加解密等，源码 `polyfill/crypto.ts`）
- **process**: Node.js 兼容对象（`process.env` / `process.nextTick` 等）

### Console 扩展
除 `log / warn / error / info / debug / trace / clear` 外，额外支持：
- `console.time(label?)` / `console.timeLog(label?, ...args)` / `console.timeEnd(label?)`
- `console.group(...args)` / `console.groupCollapsed(...args)` / `console.groupEnd()`（无 UI 折叠，语义等同 group）
- `console.table(data, columns?)`：输出 ASCII 表格，`data` 支持对象数组 / 普通对象 / 标量数组

### 全局别名
- `window` 指向 `globalThis`
- `self` 指向 `globalThis`

### 实现说明
- **代码位置**: `fuickjs/src/ex/`（浏览器标准 API）与 `fuickjs/src/polyfill/`（Node 兼容 & 其他 polyfill）
- **挂载时机**: `fuickjs/src/runtime.ts` 的 `setupPolyfills()` 中定义到全局
- **桥接依赖**: fetch、storage、WebSocket 等依赖 `services/` 下的桥接服务调用 Flutter 能力

---

## 如何添加新服务

1. **Flutter 侧**
   - 在 `fuickjs_flutter/lib/core/service/` 创建实现类，继承 `BaseFuickService`
   - 用 `registerMethod`（同步）/ `registerAsyncMethod`（异步）注册方法
   - 在 `NativeServiceManager` 中注册服务
2. **JS 侧**
   - 在 `fuickjs/src/services/` 创建对应 TS 类
   - 用全局 `dartCallNative` / `dartCallNativeAsync` 调用
   - 在 `fuickjs/src/index.ts` 导出
3. **同步文档**：更新本列表
