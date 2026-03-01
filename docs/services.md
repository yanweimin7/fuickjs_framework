# 原生服务 (Native Services / Bridge) 详尽指南

原生服务是 JS 与 Flutter 通信的核心桥梁。开发者可以通过 JS 类调用 Flutter 侧实现的功能。

## 1. 核心导航服务 (NavigatorService)
用于管理页面的跳转与返回。
- `push(path: string, params?: any)`: 推入一个新页面。
- `pushReplace(path: string, params?: any)`: 替换当前页面。
- `pop(result?: any)`: 关闭当前页面并向上一页返回结果。
- `popTo(routeName: string)`: 回退到指定名称的路由页面。
- `showModal(path: string, params?: any, options?: { minHeight?: number, maxHeight?: number })`: 弹出半屏模态窗 (BottomSheet)。
- `showDialog(pathOrComponent: string | ReactNode, params?: any)`: 弹出对话框。支持传入路由路径或直接传入 React 组件。

## 2. 界面与交互服务
### Dialog (对话框)
- `show(content: ReactNode, options?: { pageId?: number, barrierDismissible?: boolean, barrierColor?: string })`: 弹出自定义 DSL 对话框。支持多层嵌套管理。
- `dismiss(result?: any)`: 关闭当前最上层的对话框。

### Toast (简短提示)
- `show(message: string, duration?: number)`: 显示全局 Toast 提示。

### Overlay (全局悬浮层)
- `show(key: string, element: ReactNode, pageId?: number)`: 在全局视图层之上显示悬浮组件。
- `hide(key: string)`: 移除指定 key 的悬浮层。

### UIService (底层 UI 控制)
- `isWidgetRegistered(type: string): boolean`: 检查某个 Widget 类型是否已在 Flutter 侧注册解析器。
- `componentCommand(pageId, refId, method, args, nodeType)`: 向特定原生组件发送指令（如滚动列表跳转到指定位置）。

## 3. 系统能力服务
### ClipboardService (剪贴板)
- `setData(text: string): Promise<void>`: 写入剪贴板。
- `getData(): Promise<string>`: 读取剪贴板内容。

### DeviceInfo (设备信息)
- `getDeviceInfo(): Promise<DeviceInfoData>`: 获取详尽的设备信息，包括 OS、版本、屏幕宽高度、像素比等。

### LocalStorage (本地存储)
- `getItem(key: string): Promise<string | null>`: 异步获取持久化数据。
- `setItem(key: string, value: string): Promise<boolean>`: 异步存储数据。
- `removeItem(key: string)`: 移除数据。
- `clear()`: 清空所有存储。

### TimerService (定时器)
- 驱动 JS 侧的标准 `setTimeout` 和 `setInterval`。通常开发者直接使用全局函数即可。

## 4. 网络与文件服务
### NetworkService (网络)
- `fetch(url, method, headers, body?, requestId?)`: 底层 fetch 实现。
- `cancel(requestId: string)`: 中断指定 ID 的网络请求。

### fs (FileSystem / 文件系统)
提供了丰富的文件操作 API。
- `readFile(path, options?)`: 读取文件内容。
- `writeFile(path, data, options?)`: 写入文件。
- `unlink(path)`: 删除文件。
- `mkdir(path, options?)`: 创建目录。
- `rmdir(path, options?)`: 删除目录。
- `readdir(path)`: 列出目录内容。
- `stat(path)`: 获取文件/目录状态信息（大小、修改时间等）。
- `exists(path)`: 检查路径是否存在。
- `rename(oldPath, newPath)`: 重命名。
- `copyFile(src, dest)`: 复制文件。
- `getDirectories()`: 获取系统常用目录路径（如 Documents, Temp 等）。

## 5. 调试与事件
### ConsoleService (日志)
- 拦截 JS `console` 日志并转发到原生侧，支持 `log`, `warn`, `error` 级别。

### NativeEventService (原生事件)
- `emit(event: string, data: any)`: JS 侧向原生侧发送自定义事件。
- **原生侧 API**: 原生侧也可通过 `NativeEventService.emit` 向 JS 发送事件，或使用 `on` 监听 JS 事件（详见 [核心特性](./core_features.md)）。

---

## 如何添加新服务

1.  **Flutter 侧**:
    - 在 `fuickjs_flutter/lib/core/service/` 创建实现类，继承 `BaseFuickService`。
    - 使用 `registerMethod` (同步) 或 `registerAsyncMethod` (异步) 注册方法。
    - 在 `NativeServiceManager` 中添加注册。
2.  **JS 侧**:
    - 在 `fuickjs/src/services/` 创建对应的 TS 类。
    - 使用全局的 `dartCallNative` 或 `dartCallNativeAsync` 进行调用。
    - 在 `fuickjs/src/index.ts` 导出供外部使用。
3.  **同步文档**: 更新本列表。
