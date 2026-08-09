# fuickjs_flutter

FuickJS 框架的 Flutter 端：基于 React Reconciler + QuickJS + Flutter 的动态化渲染框架。

本包提供：

- **DSL 渲染**：React 组件树 → Flutter Widget 树（JS 侧 reconciler，Flutter 侧 widget factory）
- **Widget 工厂**：99 个内置 widget parser，可注册自定义 parser
- **Native 服务**：17 个内置服务（Navigator/Toast/Dialog/Storage/Network/FileSystem/WebSocket/...），可注册自定义服务
- **引擎管理**：QuickJS / JSC 双引擎切换，Isolate 工作线程
- **Bundle 动态下发**：内置 zip（Ed25519 验签 + SHA-256）+ 远程增量更新 + 状态机 + 回滚
- **离线缓存**：staged → active → history 状态机，懒解压
- **无障碍（Accessibility）**：widget 工厂统一包裹 `Semantics`，业务用 `semantics` / `semanticLabel` 透传语义，读屏可用（见 `docs/widgets.md` §7）
- **错误可观测性**：JS 错误经 sourcemap 还原后通过可插拔 `ErrorSink` 聚合到 Sentry / Bugly / 自建平台（见 `docs/services.md`）
- **i18n / Hooks / 浏览器 Polyfill**：JS 侧完整生态

## 集成

```yaml
dependencies:
  fuickjs_flutter:
    path: ../fuickjs_framework/fuickjs_flutter
```

## 快速开始

```dart
import 'package:fuickjs_flutter/fuickjs_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. 引擎预加载（Isolate 内初始化 QuickJS）
  EngineInit.preload();

  // 2. 注册自定义服务（可选）
  NativeServiceManager().registerService(() => MyService());

  // 3. 注册自定义 Widget parser（可选）
  widgetFactory.register(MyParser());

  // 4. 初始化离线包（可选；内置 zip 验签 + 懒解压）
  await Offline.init(OfflineConfig(
    envGetter: () => 'release',
    appVersionGetter: () => '1.0.0',
    signaturePublicKeysB64: {'demo-key': '<base64-pubkey>'},
    offlinePackagesGetter: () async => null,
  ));

  runApp(MaterialApp(home: FuickAppView(appName: 'my-app')));
}
```

## 主要 API

| 名称 | 类型 | 说明 |
|---|---|---|
| `FuickAppView` | Widget | 宿主集成主入口 |
| `FuickAppController` | 类 | 页面/导航/服务控制器 |
| `widgetFactory` | 全局变量 | Widget parser 注册中心 |
| `NativeServiceManager` | 单例 | Native 服务注册中心 |
| `EngineInit` | 静态类 | 引擎初始化（QuickJS/JSC） |
| `Offline` | 静态类 | Bundle 动态下发 |
| `OfflineConfig` | 配置类 | 离线包配置（公钥、版本、远程元数据） |
| `FuickNavigationDelegate` | 类 | 导航代理（含根导航回调 `onRootPush`） |
| `BaseFuickService` | 抽象类 | 自定义服务基类 |
| `WidgetParser` | 抽象类 | 自定义 Widget parser 基类 |
| `FuickCommandListenerMixin` | mixin | 命令式 Widget 监听 ref 命令 |
| `FuickConfig` | 单例 | 全局配置（debug/logLevel/hotReload） |
| `DevFuickAppPage` | Widget | 调试控制台页 |

## 文档

完整文档见 [`docs/`](../docs)：

- [introduction.md](../docs/introduction.md) — 框架总览
- [bundle-delivery.md](../docs/bundle-delivery.md) — Bundle 动态下发设计
- [widgets.md](../docs/widgets.md) — Widget 列表
- [services.md](../docs/services.md) — 服务列表
- [audit-report.md](../docs/audit-report.md) — 架构审计报告

## 平台支持

- Android / iOS / macOS（主要平台）
- Linux / Windows / Web（基础支持）
- iOS 默认走 JSC，可通过 `EngineInit.useJscOnIos = false` 强制 QuickJS（启用字节码与 ES Module）
