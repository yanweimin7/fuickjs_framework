# FuickJS Framework 官方文档

> 文档总入口。本目录（`docs/`）收录框架的设计、使用与内部方案文档；包级说明见 [`fuickjs_flutter/README.md`](../fuickjs_flutter/README.md)。

## 目录

- [项目结构](#项目结构)
- [文档总览（按主题分类）](#文档总览)
- [推荐阅读路线](#推荐阅读路线)
- [核心特性速览（5 分钟上手）](#核心特性速览)
- [开发规范](#开发规范)

## 项目结构

### JS 框架层 (`fuickjs/`)

- `src/widgets`: 映射到 Flutter 组件的 React 组件。
- `src/services`: 用于 JS-Native 通信的原生桥接服务。
- `src/ex`: 浏览器标准 API 补丁 (fetch, storage 等)。
- `src/renderer.ts`: 核心 React 渲染器 (Reconciler) 与渲染逻辑。

### Flutter 框架层 (`fuickjs_flutter/`)

- `lib/fuickjs_flutter.dart`: **公开 API 入口**，宿主与扩展包统一从此导入。
- `lib/core/widgets/parsers`: 将 JS DSL 转换为 Flutter Widget 的解析器。
- `lib/core/service`: 桥接服务的原生实现。
- `lib/core/engine`: QuickJS 引擎集成与 Isolate 管理。
- `lib/offline`: Bundle 动态下发（Ed25519 验签 + SHA-256 + 状态机 + 回滚）。
- `lib/core/fuick_config.dart`: 全局配置（debug/logLevel/hotReload/devPage）。

## 文档总览

按主题分为六类，每类给出一句话定位，便于按角色取用。

### 一、入门与概念

| 文档 | 定位 |
| --- | --- |
| [技术介绍 introduction.md](./introduction.md) | 原理、架构、功能全景与使用示例，**新手必读** |

### 二、开发指南（业务侧怎么写）

| 文档 | 定位 |
| --- | --- |
| [UI 组件 widgets.md](./widgets.md) | 已支持的全部 Flutter 组件清单与用法 |
| [FlutterProps flutter-props.md](./flutter-props.md) | React children → Flutter 命名属性（`flex`/`margin` 等）映射机制 |
| [原生服务 & 浏览器 API services.md](./services.md) | JS↔Native 桥接能力（storage/network/toast…） |
| [多语言 i18n.md](./i18n.md) | 文案在 DSL 生成前解析，Flutter 侧无感知 |
| [路由系统 router.md](./router.md) | 路径参数、命名路由、守卫、重定向、404 |
| [Community 扩展包 community.md](./community.md) | 官方可选扩展的接入方式（npm + flutter 双端） |

### 三、引擎与底层（框架侧怎么跑）

| 文档 | 定位 |
| --- | --- |
| [fuickjs_dart fuickjs_dart.md](./fuickjs_dart.md) | 纯 Dart 动态渲染方案（无 JS 引擎路径） |
| [二进制协议 v2 binary-protocol-v2.md](./binary-protocol-v2.md) | JS↔Dart 经 FFI 传输 DSL 的序列化层（varint + 字符串表） |

### 四、动态下发（Bundle 怎么更新）

| 文档 | 定位 |
| --- | --- |
| [Bundle 动态下发 bundle-delivery.md](./bundle-delivery.md) | Ed25519 验签 + SHA-256 + 状态机 + 回滚 + 图片透明加载 |
| [页面级分包加载 page-split-loading.md](./page-split-loading.md) | 主包 + 页面 chunk 按需 eval（**技术可行，但当前收益偏小、不建议实施**） |

### 五、质量与审计

| 文档 | 定位 |
| --- | --- |
| [框架审计报告 audit-report.md](./audit-report.md) | 安全/健壮性专项审计结论 |

### 六、包级文档

| 文档 | 定位 |
| --- | --- |
| [fuickjs_flutter/README.md](../fuickjs_flutter/README.md) | Flutter 端包说明（公开 API 入口） |
| [fuickjs_flutter/CHANGELOG.md](../fuickjs_flutter/CHANGELOG.md) | 版本记录 |

## 推荐阅读路线

- **业务 / 新手开发**：`introduction` → `widgets` → `services` → `router` → `i18n`
- **宿主集成 / 原生扩展**：`services` → `community` → `bundle-delivery` → `page-split-loading` → `fuickjs_flutter/README`
- **引擎 / 框架贡献者**：`fuickjs_dart` → `binary-protocol-v2` → `audit-report`

## 开发规范

**重要：** 任何代码修改或新增都**必须**同步更新本目录下的相关文档。

---

## 核心特性速览（5 分钟上手）

### 1. Fuick.expose（暴露 JS 对象给 Native）

`Fuick.expose` 将 JS 侧对象实例挂载到全局，使 Flutter 侧可通过 `ctx.invoke` 主动调用。

```typescript
import { Fuick } from "fuickjs";

const MyManager = {
  doSomething(data: any) {
    console.log("Native called JS with:", data);
    return { success: true };
  },
};

Fuick.expose("MyManager", MyManager);
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
import { NativeEvent } from "fuickjs";

// 监听原生事件
const unlisten = NativeEvent.on("onDeviceRotation", (data) => {
  console.log("设备旋转:", data);
});
unlisten(); // 组件卸载时取消

// 向原生发送事件
NativeEvent.emit("jsReady", { version: "1.0.0" });
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

轻量级路由系统，支持路径参数、命名路由、守卫、重定向与 404 兜底。详见 [路由系统](./router.md)。

```typescript
import { Router } from 'fuickjs';
import HomePage from './pages/HomePage';
import DetailPage from './pages/DetailPage';

// 旧 API（仍支持）
Router.register('/', () => <HomePage />);

// 声明式配置（推荐）
Router.config({
  routes: [
    { path: '/detail/:id', name: 'detail', component: (p) => <DetailPage id={p.id} /> },
    { path: '/profile', component: () => <ProfilePage />, meta: { requiresAuth: true } },
    { path: '/old', redirect: '/' },
    { path: '*', component: () => <NotFoundPage /> },
  ],
  guards: [authGuard],
});

// 跳转
const nav = useNavigator();
nav.push('/detail/123');
nav.pushByName('detail', { id: 123 });
const result = await nav.pushAndWait('/picker');
```

---

### 4. Hooks（React 钩子）

| Hook                    | 说明                                                                                                                                            |
| ----------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| `usePageId()`           | 获取当前页面唯一 ID                                                                                                                             |
| `useNavigator()`        | 获取导航对象，含 `push` / `pushAndWait` / `pushByName` / `replace` / `redirect` / `pop` / `popTo` / `popAll` / `showDialog` / `showBottomSheet` |
| `useRoute()`            | 获取当前路由位置信息（path / params / name / meta），详见 [路由系统](./router.md)                                                               |
| `useVisible(cb)`        | 页面进入前台时触发                                                                                                                              |
| `useInvisible(cb)`      | 页面进入后台时触发                                                                                                                              |
| `usePageConfig(config)` | 配置页面级渲染参数（`incrementalMode` / `dslCacheEnabled`）                                                                                     |
| `useTranslation()`      | 多语言翻译，返回 `{ t, locale, setLocale, locales }`，语言切换自动重渲染（详见 [i18n](./i18n.md)）                                              |
| `useLocale()`           | 返回 `[locale, setLocale]`                                                                                                                      |

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

### 4.1 多语言 (i18n)

文案在生成 DSL 前由 JS 层 `t(key)` 解析为目标语言，Flutter Parser 无需感知语言。支持插值、复数、回退链、持久化与 `NativeEvent` 广播。详见 [多语言 (i18n)](./i18n.md)。

```tsx
import { i18n, useTranslation } from 'fuickjs';

i18n.configure({ fallbackLocale: 'en', resources: { en: {...}, 'zh-CN': {...} } });
await i18n.init(); // 持久化偏好 → 系统语言 → fallback

function Home() {
  const { t, setLocale } = useTranslation();
  return <Text text={t('home.greeting', { name: 'Tom' })} onTap={() => setLocale('zh-CN')} />;
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
  sourcemap: true, // prod 也要开，.map 文件不打包进 App，保存到构建服务器
  minify: isProd,
};
```

**注意**：QuickJS 内部将 bundle 命名为 `input.js`，保存 stack 文件时需将 `input.js` 替换为 `bundle.js` 后再查询 sourcemap。

---

### 7. 本地字节码编译（运行时 compile）

除了构建期用 `qjsc -b` 预编译 `.qjc` 外，引擎现在支持在运行时把 JS 源码本地编译为 QuickJS 字节码，并导出给 Dart 端使用。适用于：动态下发的源码在端上预编译缓存、热更新包落盘为字节码、按需把脚本编译后多次执行等场景。

**Dart API**（`IQuickJsContext`）

```dart
/// 将 JS 源码本地编译为 QuickJS 字节码。
/// isModule    : true 按 ES Module 编译，false 按全局脚本编译
/// stripSource : 默认 true，去除内嵌源码文本以减小体积（不影响行列调试信息，
///               sourcemap 堆栈还原仍可正常工作）
Future<Uint8List> compile(String code, {bool isModule = false, bool stripSource = true});
```

**使用示例**

```dart
final ctx = runtime.createContext();

// 1. 把源码编译成字节码
final Uint8List bytecode = await ctx.compile('var x = 40 + 2; x;');

// 2. 直接执行字节码
final result = await ctx.evalBinary(bytecode, returnValue: true); // 42

// 3. 或落盘缓存，下次启动直接加载执行（直接传 fs 路径，C 层 fopen，避免内存拷贝）
await File('cache/bundle.qjc').writeAsBytes(bytecode);
await ctx.evalBinaryFileFromPath('cache/bundle.qjc', returnValue: false);
```

底层链路：

```
ctx.compile(code)
  → FFI qjs_compile_to_bytecode_out
      → JS_Eval(JS_EVAL_FLAG_COMPILE_ONLY)
      → JS_WriteObject(JS_WRITE_OBJ_BYTECODE)
  → Uint8List（可传给 evalBinary / 落盘为 .qjc）
```

> **版本约束**：字节码与引擎 `BC_VERSION` 强绑定，只能被相同版本的引擎加载执行。升级 QuickJS 后需重新编译。
> **平台说明**：QuickJS 引擎支持该能力；iOS/macOS 的 JSC 回退实现（`JscContext`）不支持字节码，调用 `compile` 会抛出 `UnsupportedError`。
> **stripSource 与 sourcemap**：`stripSource`（默认 true）仅剥离内嵌源码文本，保留行列调试信息（pc2line），错误堆栈的 `行:列` 仍准确，sourcemap 还原不受影响。底层从不设置 `JS_WRITE_OBJ_STRIP_DEBUG`，后者才会破坏行列号。

**Demo 体验**：演示 App 首页右上角「内存」图标进入「字节码编译测试」页（`fuickjs_demo/app/lib/compile_test_page.dart`），可输入任意 JS 源码，实时查看 `compile → evalBinary` 全流程的字节码大小、十六进制预览、执行结果及与直接 `eval` 的一致性对比。

---

### 8. ES Module 加载

引擎支持注册命名模块，供 `import` 语句解析。先用 `registerModule(name, source)` 注册依赖模块源码，再用 `evalModule(entrySource)` 执行带 `import` 的入口模块；QuickJS 在解析 `import` 时通过模块加载器按名查找已注册的源码并编译。

```dart
// 注册被依赖的模块
ctx.registerModule('math', 'export function add(a, b) { return a + b; }');

// 执行引用该模块的入口
await ctx.evalModule(
  'import { add } from "math";'
  'globalThis.result = add(2, 3);',
);
final r = await ctx.eval('globalThis.result'); // 5
```

要点：

- 模块按上下文（`JSContext`）隔离，不同上下文注册的同名模块互不影响。
- 必须先 `registerModule` 再 `evalModule`，否则 `import` 找不到模块。
- 模块源码缓冲区在底层会以零结尾方式存储，满足 QuickJS `JS_Eval` 的零结尾约定。
- **平台限制**：iOS/macOS 的 JSC 回退实现（`JscContext`）基于 `JSEvaluateScript`，不支持 ES Module 的 `import/export`，`registerModule` 会以脚本方式执行并报错。需要模块能力时请使用 QuickJS 引擎。
