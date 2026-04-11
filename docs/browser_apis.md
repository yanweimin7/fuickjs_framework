# 浏览器标准 API 补丁详尽指南

为了最大化兼容 Web 生态，FuickJS 在 QuickJS 环境中补齐了许多 Web 标准 API。这些 API 并非通过真实的浏览器内核实现，而是通过 Flutter 原生能力进行的高性能模拟。

## 1. 网络通信 API
- **fetch**:
    - 支持常用的 HTTP 方法 (GET, POST, PUT, DELETE, PATCH)。
    - **AbortSignal 支持**: 允许通过 `AbortController` 真正取消正在进行的网络请求，节省资源。
    - 响应对象支持 `.json()` 和 `.text()` 方法。
- **XMLHttpRequest (AJAX)**:
    - 完整实现了 `readyState` 状态机。
    - 支持事件监听 (`onload`, `onerror`, `onreadystatechange` 等)。
    - 支持 `responseType = 'json'`。
    - **注意**: 目前仅支持异步请求，同步请求将回退为异步执行。

## 2. 数据存储 API
- **localStorage**:
    - 接口与 Web 完全一致 (`setItem`, `getItem`, `removeItem`, `clear`)。
    - **持久化**: 数据会自动映射到 Flutter 的 `SharedPreferences` 或相应平台的原生存储中，重启不丢失。
- **sessionStorage**:
    - 会话级存储，数据在 JS 引擎上下文销毁前有效。

## 3. 工具与编码 API
- **atob / btoa**:
    - 实现了 Base64 编解码。
    - **Unicode 增强**: 专门修复了原生 `btoa` 不支持非 Latin1 字符（如中文、Emoji）的问题，内部自动处理 UTF-8 转换。
- **URL / URLSearchParams**:
    - 提供了完整的 URL 解析能力。
    - 方便管理和构造复杂的查询字符串。

## 4. 定时器与异步 API
- **setTimeout / setInterval**:
    - 毫秒级精度，底层由 Flutter `Timer` 驱动。
- **clearTimeout / clearInterval**:
    - 能够即时停止对应的定时任务。

## 5. 事件与性能 API
- **EventTarget / Event / CustomEvent**:
    - 完整的 DOM 事件模型基类实现。
    - 支持 `addEventListener`, `removeEventListener` 和 `dispatchEvent`。
- **performance**:
    - `performance.now()`: 返回自 JS 引擎启动以来的高精度毫秒数（相对于 `performance.timeOrigin`）。

---

## 全局环境说明

为了兼容性，FuickJS 在全局作用域挂载了以下别名：
- `window` 指向 `globalThis`。
- `self` 指向 `globalThis`。

---

## 内部实现逻辑

1.  **代码位置**: 所有补丁实现位于 `fuickjs/src/ex/` 目录下。
2.  **挂载时机**: 在 `fuickjs/src/runtime.ts` 的 `setupPolyfills` 方法中，这些类和函数被定义到全局。
3.  **桥接依赖**: 复杂的补丁（如 fetch, storage）依赖于 `services/` 下定义的桥接服务来调用 Flutter 能力。
