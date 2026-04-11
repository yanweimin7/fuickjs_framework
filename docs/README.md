# FuickJS Framework 官方文档

欢迎查阅 FuickJS Framework 文档。

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

## 模块文档

- [核心特性](./core_features.md) - 包含事件通信、路由、Hooks 以及 **DSL 渲染缓存机制**。
- [UI 组件 (Widgets)](./widgets.md)
- [原生服务 (Native Services)](./services.md)
- [浏览器标准 API](./browser_apis.md)
- [框架审计报告](./audit-report.md) - 覆盖 JS/Flutter/Taro 三层的 Bug 清单、设计评价与待处理优先级

## 开发规范

请参考项目根目录下的 `.cursorrules` 文件了解详细的开发指南。
**重要：** 任何代码修改或新增都**必须**同步更新本目录下的相关文档。
