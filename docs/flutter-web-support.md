# fuickjs + Flutter Web 支持

> 状态：**Phase 1（渲染闭环）与 Worker DSL 生产均已实现**，Phase 2（服务打磨）+ Worker Phase 2/3 待做。
> 目标读者：fuickjs 框架维护者与 Web 接入方。
> 核心原则：**JS 代码的发布与加载完全遵循传统 Web 方式**——bundle 就是一个普通静态 JS 文件，
> 用 `<script src>` 加载，靠 HTTP 缓存 / CDN / content-hash 文件名分发。
> fuickjs 只复用「React → DSL → Flutter 渲染」这一条链，**不移植任何 native 端的分发基础设施**。

## 实现记录（与方案的差异）

1. **窄接口 `JsBridge`**（`fjs_engine/lib/core/js_bridge.dart`）：渲染层（`FuickAppController` /
   `AppServiceBinder` / `BaseFuickService` / `FuickJsProxy`）依赖窄接口而非 `IQuickJsContext`。
   `IQuickJsContext implements JsBridge`，native 分支零变化；Web 分支由 `HostJsContext` 直接实现。
   需要引擎能力的 native 专用代码（`FuickAppContext(native)` 的 bundle 加载、
   `WebSocketService` 的 `ctx.eval` 推送、`MemoryMonitorOverlay`）在使用点窄化回
   `IQuickJsContext`；`MemoryMonitorOverlay` 用 `ctx is! IQuickJsContext` 直接跳过。
2. **conditional import 放在 fuickjs_flutter 层**，而非 fjs_engine 顶层。原因是
   `flutter analyze`（VM 目标）对 `dart.library.io` 条件导出的解析指向 stub，会导致
   fjs_engine 测试文件里的 `QuickJsFFI` 等符号「未定义」。fuickjs_flutter 通过子路径导入
   fjs_engine，Web 隔离在 fuickjs_flutter 层做更干净：
   - `core/engine/fuick_app_context.dart` → 条件导出 native / web 两版；
   - `core/service/{file_system,websocket}_service_web.dart`、`core/service/platform_info_*.dart`、
     `parsers/image_local_file_*.dart` 等 `dart:io` 面按平台拆分；
   - `lib/fuickjs_flutter.dart` 的 engine / offline / dev 工具导出在 Web 上落到空 stub
     （`core/_web_absent.dart`；同一 URI 多次导出会触发 analyzer 的 `duplicate_export`
     误报，已在文件头 `ignore_for_file` 掉）。
3. **`HostJsContext`**（`fjs_engine/lib/core/web/host_js_context.dart`）：`loadScript` +
   `invoke`/`invokeAsync` + 同步/异步双桥 + `dartify` 出口。三条容易踩的约束：
   - **双桥的 `args` 参数必须声明为可选可空 `[JSAny? argsAny]`**。业务侧存在
     `dartCallNativeAsync('Lifecycle.getState', null)` 这样传 null 的调用，以及只传
     method 的单参调用；若声明成非空必填的 `JSAny`，dart2js 会分别抛
     `JSNull is not a subtype of Object` 和 `NoSuchMethodError: call$1`。
   - **`invokeAsync` 先 `_isThenable` 鸭子判定**再决定是否 `.toDart`：用 JS
     `typeof === 'object'` + `then` 函数判断（不依赖 `isA<JSPromise>()`，它对
     extension type 的擦除语义判不出普通对象与 Promise 的区别）。非 thenable 的
     同步返回值直接 `dartify` 返回，否则调到普通同步函数会在非 thenable 上抛
     `NoSuchMethodError: 'then'`。
   - **`globalThis.dartCallNative*` 全页面只有一份**，`HostJsContext` 用静态
     `_bridgeOwner` 记录持有者：`dispose()` 只删自己装的桥，后建实例抢占时告警。
     一个页面里跑两个 fuickjs app 不受支持（`globalThis.fuickjs` 也会冲突）。
     Worker 模式每个 app 独占一个 Worker，JS 全局环境天然隔离，这条限制自动消失（见 §6.1.2）。
4. **`FuickAppContext` 两个分支的公开面与语义对齐**：`isReady` 表示「桥/引擎就绪」
   （web 在装完桥后立即置 true，native 在引擎 init 后置 true），bundle 加载结果由
   `appController.isBundleLoaded` 表达——`FuickPageView` 监听的是后者。两边
   `_loadBundle` 失败都只记日志不外抛，因为 `FuickAppView.initState` 里的
   `_initContext()` 没有 catch，外抛会变成未捕获异步异常 + 永久 loading。
   web 分支的 `activeBundleRoot` 恒为 null（无离线包解压目录）。
5. **平台标识不要一刀切换成 `defaultTargetPlatform`**。`DeviceInfo.getDeviceInfo` 的
   `os`/`osVersion`/`locale`/`isXxx` 走 `core/service/platform_info_*.dart`：native 保留
   `dart:io Platform`（`operatingSystem` 能返回 `TargetPlatform` 枚举里没有的 `ohos`；
   `operatingSystemVersion` 是唯一的真实系统版本来源，`navigator.userAgent` 的拼装依赖它），
   Web 才用 `defaultTargetPlatform` + `PlatformDispatcher.locale`，`osVersion` 返回 `'unknown'`。
6. **fuickjs JS 侧的浏览器兼容修复**：
   - `src/runtime/runtime.ts` 的 `bindGlobals`：原 `Object.assign(globalThis, { window, self,
     fuickjs })` 在浏览器里因 `window`/`self` 是只读 getter 而抛错，导致 `fuickjs` 不被赋值。
     改为仅在缺失时注入 `window`/`self`，`fuickjs` 始终直接赋值（QuickJS 端行为不变）。
   - `src/polyfill/globals.ts`：浏览器宿主整段跳过 native-API 替换。Dart 在 Web 上的
     `console`/`Timer` 实现本身就走浏览器原生，替换会与之成环导致死循环爆栈。
   - 宿主判定统一走 `src/utils/env.ts` 的 `isBrowserHost()`，判据是 `document` 而非
     `window`——`bindGlobals` 自己会往 QuickJS 全局挂 `window` 别名，拿它判环境会自指。
   - **`src/core/hostConfig.ts` 的 `commitUpdate` 修了 React 18/19 参数错位**（`Cannot use
     'in' operator` 的根因）：React 18（reconciler 0.29）调用是
     `commitUpdate(instance, updatePayload, type, oldProps, newProps, handle)`，React 19
     （0.33）是 `commitUpdate(instance, type, oldProps, newProps, handle)`——第 3 参一个是
     `type`（string）一个是 `oldProps`（object）。原实现按 React 19 签名写死，React 18
     下 `diffProps` 把组件类型 `"Text"` 当 props 遍历，`for (const key in "Text")` 抛错。
     改为用 `typeof arg3 === 'string'` 区分两版（对齐 hostConfig 头部「同一 hostConfig
     兼容两个 reconciler」的既有意图）。**此 bug 非 web 独有**，native 端 React 18 的
     xiangqi 在 `commitUpdate`（如状态更新）同样会踩。
   - **已知遗留**：浏览器主线程跳过 `localStorage`/`sessionStorage` polyfill 后，
     `globalThis.localStorage` 是浏览器原生的，而直接 import `LocalStorageService` 的代码仍走
     `dartCallNativeAsync('LocalStorage.*')` → Dart 的 shared_preferences，Web 上会出现两套
     互不相通的存储。Phase 2 待统一。
     注意判据后来拆成了 `hasNativeStorage()`（见 `utils/env.ts`）：Worker 里没有 Web Storage，
     所以 Worker 模式**会**注入 polyfill，与主线程模式看到的数据不同（见 §6.5.5）。
7. **demo**：`xiangqi/web_demo`（Flutter Web）+ `xiangqi/esbuild.web.js`（浏览器 bundle，
   `buffer`/`crypto-js` 走 `web_shims/` 打入）。`flutter build web` 通过，headless Chrome
   冒烟验证 bundle 加载 + 桥注册 + `invoke('fuickjs','render')` 无报错。demo 左上角有
   `WorkerModeBadge` 角标，实时显示当前是 Worker 模式还是主线程（及回退原因）。

## 0. 总纲：Web 端的价值边界（先读这个）

fuickjs 的四大核心价值，在 Web 上**只保留一个**：

| 价值 | native 端 | Web 端 | 结论 |
|------|----------|--------|------|
| **DSL 渲染层复用**（React → DSL → WidgetFactory） | ✅ | ✅ **唯一保留** | 本方案的全部内容 |
| **动态化下发** | ✅ 引擎 + 离线包体系 | 平台已有：重新部署 JS 文件就是发布。**不做任何分发层** | 交给传统 Web |
| **沙箱隔离** | ✅ QuickJS isolate，必须 | ❌ 不需要也不做（一手可信代码；隔离需求用平台原生 iframe/Worker） | 放弃 |
| **引擎价值** | ✅ 宿主非 JS 环境 | ❌ 宿主就是 JS 环境，再嵌引擎（含 QuickJS-WASM）是重复造轮子 | 放弃 |

一句话：**native 端 fuickjs = 引擎 + 沙箱 + 离线分发 + 渲染；Web 端 fuickjs = 只有渲染。**

**适用条件（硬边界）**：本方案只对「已是 fuickjs native 用户、想让同一套组件代码顺带跑上 Web」
的场景成立。若是独立的 Web 技术选型，同一坨 React 代码走 React DOM 是零额外成本，走本方案
要付 canvaskit（≈2.8MB）+ canvas 渲染的无障碍/SEO/文本选择劣势——买到的唯一东西是
「与 native 像素级一致 + 一套组件代码」。接入方若对 Web 的诉求不是「复用同一套 fuickjs
组件代码」，直接用平台原生能力（普通 JS 开发）更划算，本方案不覆盖那种场景。

## 1. 背景与决策前提

之所以绕开「Taro 多端」，是因为 **Taro 的 CSS→Flutter Widget 转换存在根本性的语义鸿沟**
（`css-to-props.ts` 1002 行、112 个手工 case，Flexbox/选择器优先级/动画长期填不平）。
fuickjs 原生路径**从头到尾不经过 CSS 层**（业务直接写 `Container/Text/Row/Stack`，props 本就是
Flutter 语义），因此 native + web 共用 `WidgetFactory` 时渲染语义天然一致。

**前提**：本方案的「无 CSS 兼容问题」只对「业务用 fuickjs 组件体系写 UI」成立。若业务方有 CSS
输入（存量 H5/设计稿/生态 UI 库），兼容问题会以「组件表达能力」的形式回归，不属本方案范围。

## 2. 架构总览

### 2.1 构建与发布（纯传统 Web 流程）

```
业务 React/TS ──esbuild──> bundle.js          # 现有构建链不变
flutter build web ──> build/web/               # main.dart.js + canvaskit + index.html

发布：两者一起丢 CDN / 静态服务器。
bundle 用 content-hash 文件名（bundle.a1b2c3.js）做缓存控制——这就是全部"版本管理"。
```

**没有** manifest.json / latest.json / 下载 / 解压 / 验签 / 包状态机。要更新 JS 就重新部署，
浏览器缓存策略就是全部分发逻辑。完整性由 TLS + 同源保证；需要更强完整性时用平台原生
**SRI**（`<script integrity="sha384-...">`），而非自造 Ed25519 验签。

### 2.2 运行时链路

```
index.html（只放 flutter_bootstrap.js）
  └─ Dart main()
       1. js_interop 注册桥：globalThis.dartCallNative / dartCallNativeAsync
       2. 动态创建 <script src="bundle.[hash].js">，await onload
          → bundle 在 globalThis 挂好 fuickjs 运行时（与 native 相同的 bindGlobals）
          → onload 触发前 microtask 已 flush，时序语义干净（无 native 的 runJobs 问题）
       3. invoke('fuickjs', 'render', [pageId, path, params]) → DSL 对象树
          （dartify 一次过界为 Map，非 JSON string，见 §3.7）
       4. WidgetFactory → Flutter Widget 树（与 native 完全相同）
```

由 Dart 侧驱动 script 加载（而非写死在 index.html），加载顺序和桥注册时序完全确定。
多 bundle / 多页面 = 多个 script 标签，同一机制。

### 2.3 资源与静态文件

native 端的 `file://<bundleRoot>/assets/...` 在 Web 上**就是普通 URL**：图片、字体等随 bundle
一起部署，`Image.network` / 常规 web 资源路径直接消费。`__FUICK_BUNDLE__.root` 注入一个 URL
前缀（或 null），且注入本身用 js_interop 直接写 `globalThis`，**不需要 eval**。

## 3. 改造点（主线程方案）

### 3.1 `fjs_engine`：隔离 FFI，新增窄接口与 Web 桥

`dart:ffi` 在 Web 上编不过，必须编译期隔离。**实际实现**（见实现记录第 2 点）：
conditional import 放在 fuickjs_flutter 层而非 fjs_engine 顶层——`flutter analyze`（VM 目标）
对 `dart.library.io` 条件导出的解析指向 stub，会让 fjs_engine 测试里的 `QuickJsFFI` 等符号
「未定义」。fjs_engine 本身新增两个文件，native 侧零变化：

- `core/js_bridge.dart`：窄接口，渲染层依赖它而非 `IQuickJsContext`；
- `core/web/host_js_context.dart`：Web 端 `JsBridge` 实现（js_interop 桥）。

Web 构建完全不触碰 `quickjs_ffi.dart` / `jsc_ffi.dart` / `jscontext.dart` / `jsc_context.dart`
（这些文件由 fuickjs_flutter 的 conditional import 挡掉）。

### 3.2 `HostJsContext`：瘦身为「桥」

Web 端不再需要"引擎"概念。`IQuickJsContext` 是为 isolate/FFI 设计的胖接口（15 个方法，
Web 端一半只能抛 `UnsupportedError`），Web 侧**不实现它**，而是定义窄接口 `JsBridge`：

| 能力 | Web 实现 |
|------|---------|
| bundle 加载 | 动态 `<script src>` + await onload（**不是 eval**） |
| `invoke(obj, method, args)` | js_interop 读 `globalThis[obj][method]` 后调用 |
| `invokeAsync(...)` | 返回值若为 Promise 转 `Future` |
| `onCallNative` / `onCallNativeAsync` | js_interop 把 Dart 函数注册到 globalThis |

`FuickAppContext` 依赖这个窄抽象（native 分支由现有 `JsContextDelegate` 适配），
不背僵尸接口。

### 3.3 isolate 消除

Web 单线程、无 `dart:isolate`：`FuickAppContext` 的 Web 分支直接持有 `HostJsContext`，
不经过 `IsolateWorker` / `JsContextDelegate`（这两个文件 Web 不编译，代码不动）。

### 3.4 同步桥 `dartCallNative`（核心机制，与 native 语义对齐）

- 业务代码跑在宿主 globalThis，`dartCallNative` 是 js_interop 注册的**同步 Dart 函数**，
  同线程同步返回——无 WASM 边界、无句柄序列化。
- **严格策略**（等价于 native 主 isolate 的 `allowSyncToAsyncFallback: false`）：
  sync 桥只命中 sync handler（Timer/Console 等白名单），业务 async 方法必须走
  `dartCallNativeAsync`，未命中抛错。`AppServiceBinder` 逻辑不变。
- js_interop 类型映射集中在单个桥文件，只覆盖实际用到的类型（bool/num/String/List/Map）。

### 3.5 Service 与 Parser 的 Web 化

`dart:io` 使用面（grep 全量清单）按平台拆分或降级：

| 文件 | Web 处理 |
|------|---------|
| `service/websocket_service.dart` | 改用 `package:web` 的 WebSocket |
| `service/device_info_service.dart` | 改用 `navigator.userAgent` 等 |
| `service/file_system_service.dart` | 降级：不支持或 localStorage 兜底 |
| `widgets/parsers/image_parser.dart` | 去掉 `Image.file` 分支，Web 只走网络/资源 URL |
| `container/dev_fuick_app_page.dart` | Web 不编译（dev 工具） |

### 3.6 编译期屏蔽 offline 模块

`offline/` 整个目录依赖 `dart:io`，**Web 不编译、代码不动**：

- `fuickjs_flutter.dart` 的导出做条件化，Web 导出不包含 offline；
- `fuick_app_context.dart` 按平台拆分（或抽工厂），Web 分支不引用 `Offline`、
  不注入磁盘路径相关的 bundle 元数据。

### 3.7 DSL 传输编码：免 JSON 序列化

**「DSL 作为契约」保留，「JSON string 作为编码」去掉。** JSON.stringify/parse 是
native 端 isolate 边界的过路费（两边不共享内存，只能传字节流）；Web 端 dart2js 产物与
业务 JS 同 VM 同堆，stringify 再立刻 parse 是纯浪费。

```
native: toDsl() → JSON.stringify → [isolate 边界] → jsonDecode → Map → WidgetFactory
web:    toDsl() → 直接返回对象树 → dartify() 一次深转 → Map → WidgetFactory
```

- `toDsl()` 产出的本是纯数据（回调按 ID 引用，函数实体留在 PageContainer），
  `dartify()` 对其无损，语义与 `jsonDecode` 一致（int/double 判定规则相同）；
- 改动只在 `HostJsContext.invoke` 出口：JSObject → `dartify()`，替代 `jsonDecode`。
  **WidgetFactory / PageContainer / hostConfig 零改动**；
- 反向（Dart → JS 传 params）对称用 `jsify()`；
- **dart2wasm 约束**：禁止 js_interop 逐属性懒读 JS 对象（每次访问都过 wasm↔JS 边界，
  比序列化更慢），必须在边界处 dartify 一次性批量过界；dart2js 下懒读可行，但为两个
  编译目标共用一套下游代码，统一选 dartify；
- 收益定位是架构正确性而非性能救星：大页面首帧省 stringify+parse+字符串分配（几 ms
  量级），小更新可忽略。调试快照仍可随时 `JSON.stringify`。

## 4. 明确不做（从旧方案中删除）

- ❌ offline 模块移植（下载/验签/包管理/清理/强制更新）——平台已有 HTTP 缓存 + CDN
- ❌ Dio 下载 bundle、blob URL 加载、BundleStorage 抽象、IndexedDB 持久化
- ❌ 字节码 `.qjc` 与 `BundleCompiler`
- ❌ QuickJS-WASM（解释器套解释器，慢 1~2 个数量级；沙箱理由在 Web 上不成立）
- ❌ `eval` / `Function` 执行 bundle（script 标签取代；**因此也不需要 CSP `unsafe-eval`**）

## 5. 关键约束与风险

| 项 | 说明 |
|----|------|
| **单 globalThis = 单实例** | 同一页面只能跑一个 fuickjs 应用（`dartCallNative`、`fuickjs.*` 是全局单例）。多实例需 iframe，不纳入本方案。Worker 模式下每个 app 独占一个 Worker，天然隔离（见 §6.1.2） |
| **同步桥稳定性** | js_interop 同步返回 Dart 结果需实测，Phase 1 冒烟首验 |
| **主线程长任务** | native 端 React reconcile + DSL 生成在独立 isolate，不卡 UI；Web 端主线程模式下与 UI 同线程，大列表/深树首帧渲染会阻塞输入。**已有解法**：给 `FuickAppView` 传 `workerUrl`，把 reconcile + DSL 生成迁进 Web Worker，不支持的浏览器自动回退主线程（见 §6） |
| **浏览器路由边界** | 浏览器前进/后退、URL 深链与 fuickjs 页面栈的关系**不在框架范围内**，由接入方自行管理 |
| **首屏体积** | canvaskit ≈ 2.8MB + main.dart.js + bundle.js。Web 端成本项，接入前算账 |
| **CSP** | 无 eval → 无需 `unsafe-eval`；同源 script 无需任何 CSP 放宽 |
| **dart2wasm** | js_interop 对 dart2js/dart2wasm 均可用，不作为风险 |

## 6. Web Worker：DSL 生产迁入 Worker

> 状态：**Phase 1（链路打通）已实现**。Phase 2/3 见 §6.7。
> 一句话结论：**可行，且工作量远小于直觉**——因为 JS→Dart 的 DSL 投递链路今天已经全部是异步的，
> 唯一的硬约束是同步桥 `dartCallNative`，而它在 Web 上的使用面可以被完全消除。
>
> **接入只需一个参数**：给 `FuickAppView` 传 `workerUrl`。浏览器不支持 Worker、脚本取不到、
> CSP 拦截或握手超时都会自动回退主线程渲染，功能不受影响。见 §6.3.6。

### 6.1 要解决的问题

§5 把「主线程长任务」列为已知风险：

> native 端 React reconcile + DSL 生成在独立 isolate，不卡 UI；Web 端与 UI 同线程，
> 大列表/深树首帧渲染会阻塞输入。

native 端的 `IsolateWorker` 把 JS 引擎放在独立 isolate，Dart 主 isolate 只做 WidgetFactory。
Web 端 Phase 1 为了先打通闭环，把 React + DSL 生成放在浏览器主线程，与 Flutter 的
build/layout/paint 抢同一个线程。本方案用 Web Worker 补回这个隔离。

#### 6.1.1 收益边界（先说清楚，避免过度承诺）

一帧的成本可以拆成两段：

| 阶段 | 现在 | 迁入 Worker 后 |
|------|------|---------------|
| React reconcile + `toDsl()` | 主线程 | **Worker 线程** |
| structured clone 反序列化 + `dartify()` | 主线程（仅 dartify） | 主线程（clone + dartify） |
| WidgetFactory 建树 + Flutter layout/paint | 主线程 | 主线程 |

**只有第一段被搬走。** dart2js 产物本身就是主线程代码，Flutter Web（canvaskit）的渲染也在主线程，
这两段搬不走。所以：

- 页面越大越深、业务组件计算越重 → 收益越大；
- 小页面、高频小补丁 → 收益接近 0，甚至因多一次 structured clone 而略负。

**先量后做**：`utils/perf-timing.ts` 已有分段计时（`t_js_to_dsl` / `t_transfer` / `t_total`）。
接入方应先在真实页面上测 `t_js_to_dsl` 占比，低于 ~20% 的场景不值得引入 Worker 的复杂度。

#### 6.1.2 顺带解决的问题

Phase 1 有一条硬限制：`globalThis.dartCallNative*` 与 `globalThis.fuickjs` 全页面只有一份，
**同一页面只能跑一个 fuickjs 应用**（见 `HostJsContext._bridgeOwner` 的告警）。
每个 app 独占一个 Worker 后，JS 全局环境天然隔离，这条限制自动消失。

### 6.2 可行性判定

结论先行：**可行**。逐条核对下来，这条链路的异步化改造在做 native isolate 支持时就已经完成了绝大部分，
Web Worker 复用的是同一套语义。

#### 6.2.1 JS → Dart 的 DSL 投递：已经全是异步 ✅

DSL 出口只有三个，全部走异步桥：

```5:15:fuickjs_framework/fuickjs/src/services/UIService.ts
  static renderUI(pageId: number, renderData: unknown) {
    void dartCallNativeAsync('UI.renderUI', { pageId, renderData });
  }

  static patchUI(pageId: number, patches: unknown[]) {
    void dartCallNativeAsync('UI.patchUI', { pageId, patches });
  }

  static patchOps(pageId: number, ops: unknown[]) {
    void dartCallNativeAsync('UI.patchOps', { pageId, ops });
  }
```

调用方是 `DiffStrategy.commit` / `IncrementalStrategy.commit`，由
`hostConfig.resetAfterCommit` 在 reconciler 提交后触发。**没有任何同步 `dartCallNative('UI.*')`。**

> `utils/perf-timing.ts:6` 的注释仍写着「`dartCallNative('UI.renderUI')` 同步 FFI 往返」，
> 与实现不符，是历史遗留，应一并订正。

#### 6.2.2 Dart → JS 的调用：只有一个需要同步返回 ✅

`FuickJsProxy` 是 Dart 侧调 JS 的唯一入口，7 个方法里 6 个是 void：

| 方法 | 返回值 | Worker 化影响 |
|------|--------|--------------|
| `render` | void | 无。且 `page_render.render()` 内部本就是 `void doRenderAsync(...)`，立即返回 |
| `destroy` | void | 无 |
| `notifyLifecycle` | void | 无 |
| `disposeItem` | void | 无 |
| `dispatchEvent` | void | 无 |
| `handleTimer` | void | Web 上根本不会被调用（见 §6.2.4） |
| **`getItemDSL`** | **有返回值** | **变成 Future——但已被支持，见下** |

`getItemDSL` 看似是阻塞点，实际不是：**native 端它早就是异步的**。
`JsContextDelegate.invoke` 返回的是 `_worker.sendRequest(...)`，即一个 `Future`。
消费侧 `FuickItemDSLBuilder` 因此从一开始就同时接受「值」和「Future」：

```381:396:fuickjs_framework/fuickjs_flutter/lib/core/widgets/fuick_state_widgets.dart
  void _resolveDSL() {
    if (widget.dslOrFuture is Future) {
      final future = widget.dslOrFuture as Future;
      // If we already have a DSL, don't set loading to true to avoid flickering
      if (_dsl == null) {
        _loading = true;
      }
      future.then((value) {
        if (mounted) {
          setState(() {
            _dsl = value;
            _loading = false;
          });
        }
      });
    } else {
```

四个列表 parser（`list_view` / `grid_view` / `sliver_list` / `sliver_grid`）统一用
`dynamic dslOrFuture` 承接。**Dart 侧零改动即可接受异步 `getItemDSL`。**

代价是真实的（见 §6.5.1 的滚动白屏），但不是架构阻塞。

#### 6.2.3 DSL 载荷可结构化克隆 ✅

`toDsl()` 产出纯数据。函数不进载荷——回调在 `processProps` 里被换成 ID 描述符，
函数实体留在 Worker 内的 `PageContainer.eventCallbacks`：

```650:665:fuickjs_framework/fuickjs/src/core/PageContainer.ts
      if (typeof value === 'function') {
        const fullKey = this.buildPath(path, key);
        this.registerCallback(nodeId, fullKey, value as (...args: unknown[]) => unknown);
        processedProps[key] = {
          id: Number(nodeId),
          nodeId: Number(nodeId),
          eventKey: String(fullKey),
          pageId: Number(this.pageId),
          isFuickEvent: true,
        };
```

`itemBuilder` 也被显式排除。事件回传走 `dispatchEvent(eventObj, payload)`，`eventObj` 即上述描述符，
天然可克隆。

**失败模式反而变好**：业务若在 props 里塞了函数/Symbol，今天 `dartify()` 可能静默产出怪值，
structured clone 会直接抛 `DataCloneError`，问题当场暴露。

#### 6.2.4 核心 DSL 链路无 DOM 依赖 ✅

`src/core/`（reconciler、hostConfig、PageContainer、node、strategies）不使用
`document` / `window` / DOM / `localStorage`。只用 `Date.now` / `Promise` / `queueMicrotask` /
`setTimeout`——全部是 Worker 内可用的 JS 内建。

#### 6.2.5 唯一的硬约束：同步桥 `dartCallNative` ⛔

Web Worker 与主线程只能通过 `postMessage` 异步通信。真正的同步 RPC 需要
`SharedArrayBuffer` + `Atomics.wait`，而那要求页面开启跨源隔离（COOP/COEP），
是很重的部署约束（会破坏第三方 iframe/CDN 嵌入）。**本方案不采用 SAB。**

好在 `dartCallNative` 在 JS 侧的使用面很小且完全可控——全量 13 处直接调用：

| 服务 | 方法 | 是否在渲染热路径 |
|------|------|----------------|
| `TimerService.ts:3,7` | `Timer.createTimer` / `deleteTimer` | **是**（`hostConfig.scheduleTimeout`） |
| `ConsoleService.ts:15` | `Console.console` | **是**（渲染中的 `console.warn/error`） |
| `FileSystemService.ts` ×11 | `FileSystem.*Sync` | 否（仅业务显式调用） |

Timer / Console 只在 **非浏览器宿主** 时才被注入，而改造前的宿主判定只有一个判据：

```ts
// 改造前的 utils/env.ts
export function isBrowserHost(): boolean {
  return typeof globalThis.document !== 'undefined';
}
```

**这是本方案最关键的一处代码改动。** Web Worker 里没有 `document`，旧判据会返回
`false`，于是 polyfill 被注入，`setTimeout` 和 `console` 被路由到同步桥——而同步桥在 Worker 里
根本不可能工作。**不改这里，Worker 方案第一帧就废。**

修法见 §6.3.3。改完之后，Worker 内**没有任何同步桥调用**（Worker 自带原生 `setTimeout` 与 `console`）。

### 6.3 架构设计

#### 6.3.1 总览

```
┌─ 主线程 ────────────────────────────────────────────┐
│  Dart (dart2js) + Flutter canvaskit                 │
│    FuickAppController / AppServiceBinder / Services │
│    WidgetFactory → Widget 树                        │
│    WorkerJsBridge  implements JsBridge              │
└──────────────────┬──────────────────────────────────┘
                   │ postMessage（结构化克隆，FIFO 有序）
┌──────────────────┴─ Web Worker ─────────────────────┐
│  fuick-worker.js（框架提供的 worker 入口）           │
│    1. 装 __FUICK_HOST__ = 'browser-worker'          │
│    2. 装 dartCallNative / dartCallNativeAsync 实现   │
│    3. importScripts('bundle.[hash].js')             │
│         → bindGlobals() 挂 globalThis.fuickjs       │
│    4. React reconciler + PageContainer + toDsl      │
└─────────────────────────────────────────────────────┘
```

关键点：`JsBridge` 这个窄接口不变。新增的 `WorkerJsBridge` 与现有 `HostJsContext` 平级，
**`FuickAppController` / `AppServiceBinder` / 所有 Service / 所有 Parser 零改动**。

#### 6.3.2 消息协议

单一 `MessagePort`，五类消息。ID 用单调递增整数。

**主线程 → Worker**

```jsonc
// 启动握手：让 Worker importScripts 业务 bundle
{ "t": "init", "bundleUrl": "bundle.[hash].js" }

// 调用 globalThis[obj][method](...args)，对应 JsBridge.invoke/invokeAsync
{ "t": "call", "id": 12, "obj": "fuickjs", "method": "render", "args": [1, "/home", {}] }

// 主线程对 Worker 发起的 native 调用的应答
{ "t": "nativeReply", "id": 7, "ok": true,  "value": null }
{ "t": "nativeReply", "id": 7, "ok": false, "error": "...", "stack": "..." }
```

**Worker → 主线程**

```jsonc
// 握手结果。bundle 顶层同步执行完毕即 ready（bindGlobals 已挂好 globalThis.fuickjs）
{ "t": "ready" }
{ "t": "initError", "error": "...", "stack": "..." }

// call 的结果
{ "t": "callReply", "id": 12, "ok": true,  "value": { /* DSL */ } }
{ "t": "callReply", "id": 12, "ok": false, "error": "...", "stack": "..." }

// dartCallNativeAsync → 主线程 AppServiceBinder
{ "t": "native", "id": 7, "method": "UI.renderUI", "args": { "pageId": 1, "renderData": {} } }

// dartCallNative（同步桥）在 Worker 内不可用，直接本地抛错，不产生消息。
```

设计约束：

- **每条 `native` 都必须有 `nativeReply`**，成功失败都要回。这与 native 端的
  `NativeCallReply` envelope 是同一个教训：异常路径不回包 = Promise 永久 pending。
- **每条 `call` 也一律回包**，包括 6 个 void 方法。方案初稿曾打算只给
  `getItemDSL` 回包以省一次往返，实现时改了：不回包意味着 Worker 内 `render` /
  `dispatchEvent` 抛出的异常在主线程**完全不可见**，静默丢帧比一次 postMessage 贵得多。
  `WorkerJsBridge.invoke` 因此恒返回 `Future`，与 native 的 `JsContextDelegate.invoke` 一致。
- **没有 `t:'error'` 通道**。Worker 内的未捕获异常由主线程的 `worker.onerror` 兜底，
  业务级错误仍走 bundle 自己的 `ErrorHandler` → `dartCallNativeAsync`，不重复造一条链路。
- **FIFO 有序性由 `postMessage` 保证**，`destroy` → `render` 的先后不会乱序。

#### 6.3.3 宿主判定改造（最关键的一处）

`isBrowserHost()` 语义上其实是在问两个不同的问题，Phase 1 把它们合并了：

1. 「要不要注入 `window`/`self` 别名？」（`runtime.ts:36`）
2. 「要不要把 `setTimeout`/`console`/`fetch` 路由到 Dart？」（`globals.ts:26`）

Worker 场景下两者答案不同：Worker 有 `self`（无 `window`），但**有全套原生 JS 内建**。
用 `document` 一个判据同时回答两个问题，在 Worker 里必然答错第二个。

**方案：显式宿主标记 + 能力兜底。** Worker 入口在 `importScripts(bundle)` **之前**写：

```js
globalThis.__FUICK_HOST__ = 'browser-worker';
```

`utils/env.ts` 实现为 `getHost()` 加三个语义化判据：

```ts
export type FuickHost = 'browser' | 'browser-worker' | 'engine';

export function getHost(): FuickHost;      // 显式标记优先，回落到 document 探测
export function isBrowserHost(): boolean;  // === 'browser'，即「有 DOM」
export function hasNativeWebApis(): boolean;  // !== 'engine'
export function hasNativeStorage(): boolean;  // === 'browser'
```

三处调用点：

| 位置 | 判据 | 说明 |
|------|------|------|
| `globals.ts` console/timer/fetch/... | `!hasNativeWebApis()` | 仅 QuickJS 注入 |
| `globals.ts` localStorage/sessionStorage | `!hasNativeStorage()` | QuickJS **与 Worker** 都注入 |
| `runtime.ts` window/self 别名 | `!isBrowserHost()` | 判据不变 |

两处与方案初稿不同，都是实现时发现的：

- **`needsWindowAlias()` 没有引入。** 初稿打算让别名只在 `engine` 注入，但 Worker 里同样
  没有 `window`，业务代码的 `window.xxx` 会直接炸。而「有没有 `window`」恰好就是
  `isBrowserHost()`（判据 `document`）在回答的问题——原判据本就是对的，不需要新函数。
  Worker 自带 `self`，`runtime.ts` 的 `typeof` 判空会自动跳过它，只补 `window`。
- **多出一个 `hasNativeStorage()`。** 初稿漏了：Web Storage 规范只把 `localStorage` /
  `sessionStorage` 暴露给 `Window`，**Worker 里没有**。所以 Worker 虽然有原生
  fetch/console/timer，仍必须注入 `ex/storage.ts` 的内存实现（写入异步回写 Dart，
  不走同步桥）。若跟着 `hasNativeWebApis()` 一起跳过，业务一读 `localStorage` 就 ReferenceError。

选显式标记而非鸭子判定（`typeof importScripts === 'function'`）的理由：QuickJS 未来若补上某个
Worker 特征 API，鸭子判定会静默失效；显式标记由框架自己的 Worker 入口写入，确定性强。
`document` 探测作为兜底保留，是为了让「宿主页面手动 new Worker」的非常规接法也能工作
（这种接法下宿主需自行写标记，否则会被判成 `engine`）。

#### 6.3.4 Worker 内的同步桥：显式失败，不静默

Worker 入口装一个**只会抛错**的 `dartCallNative`：

```js
globalThis.dartCallNative = function (method) {
  throw new Error(
    `dartCallNative("${method}") is unavailable in the fuickjs Web Worker: ` +
    `a worker cannot call the main thread synchronously. Use dartCallNativeAsync("${method}").`
  );
};
```

这样 `FileSystem.*Sync` 或业务的同步调用会**当场炸出可读错误**，而不是挂死或静默返回
`undefined`。语义上等价于主 isolate 的 `allowSyncToAsyncFallback: false` 严格策略。

`dartCallNativeAsync` 则是标准的 postMessage RPC：发 `t:'native'`，用 `id` 关联，
返回一个 Promise，在 `nativeReply` 到达时 settle。

> 注意 `polyfill/native-async-timeout.ts` 会在 `setupGlobals()` 之后包装
> `globalThis.dartCallNativeAsync`。Worker 入口必须**在 bundle 加载前**装好原始实现，
> 让包装逻辑正常生效。

#### 6.3.5 主线程侧 `WorkerJsBridge`

新增 `fjs_engine/lib/core/web/worker_js_bridge.dart`。两个 Web 桥现在共用
`core/web/web_js_host.dart` 里的 `WebJsHost`（= `JsBridge` + `loadBundle`），
让 `FuickAppContext` 不必按具体类型分支：

| `WebJsHost` 成员 | Worker 实现 |
|----------------|-----------|
| `loadBundle(url)` | no-op —— bundle 已在 `spawn()` 的握手阶段由 Worker `importScripts` |
| `invoke(obj, m, args)` | 发 `t:'call'`，**恒返回 `Future`**（见 §6.3.2 的回包约束） |
| `invokeAsync(...)` | 同上，额外套 `timeout` |
| `onCallNative` | 不会被触发（Worker 侧同步桥直接抛错）。仍保存，作为 async 回调缺席时的兜底 |
| `onCallNativeAsync` | 收到 `t:'native'` 时调用，结果用 `nativeReply` 回包 |
| `dispose()` | `worker.terminate()`，并把所有 pending 请求 `completeError` |

`invoke` 的返回类型是 `dynamic`，Worker 分支恒返回 `Future` ——
这与 native 的 `JsContextDelegate.invoke` 行为完全一致，下游已适配。
6 个 void 调用方会丢弃这个 Future，所以实现里对每个都预挂了 `future.ignore()`，
避免 JS 抛错时变成未处理异步异常；真正 `await` 的 `getItemDSL` 仍能正常收到异常。

**dispose 必须清 pending**：这是 native 端 `QuickJsContext.dispose` 曾经的缺陷
（`awaitCompleters` 未清导致 Future 永久挂起），不要在 Web 上重犯。

**入站 Native 调用有缓冲**：`spawn()` 在 `FuickAppController` 构造**之前**就完成了 bundle 加载，
而 `onCallNativeAsync` 要等 controller 构造时的 `AppServiceBinder.init` 才挂上。
bundle 顶层若发起 Native 调用会落进 `_bufferedNativeCalls`，回调就绪后按原序补发——
JS 侧只是 Promise 晚一点 resolve。这样握手可以整体前置，失败时无需拆掉已建好的 controller。

#### 6.3.6 模式选择与自动降级

**不提供 mode 枚举**，`workerUrl` 本身就是开关：

```dart
FuickAppView(
  appName: 'demo',
  bundleUrl: 'bundle.[hash].js',
  workerUrl: 'fuick-worker.js',  // 传了就试 Worker，不传就主线程
)
```

「有没有 Worker 脚本可用」是唯一有意义的判据，再叠一个 enum 只会制造
`renderMode: worker` 却没传 `workerUrl` 这种自相矛盾的状态。

降级是**自动且静默**的（只记 `logger.w`），覆盖四种失败：

| 失败 | 触发点 |
|------|--------|
| 浏览器没有 `Worker` 构造函数 | `WorkerJsBridge.isSupported` |
| CSP `worker-src` 拦截 / `file://` 源 | `new Worker()` 同步抛错 |
| 入口脚本 404、bundle `importScripts` 失败 | `t:'initError'` / `worker.onerror` |
| 握手无响应 | 15s 超时 |

任何一种都回退到 `HostJsContext` 主线程渲染，**功能完全不受影响**，只是失去线程隔离。
宿主想埋点区分实际生效的模式，读 `FuickAppContext.isWorkerActive`（native 恒 `false`），
不要读 `workerUrl` 是否为空。调试时读 `workerFallbackReason` 拿具体降级原因
（release 构建里 `logger.w` 静默，这个字段是排查「为什么没走 Worker」的最直接手段）。

### 6.4 改动清单（Phase 1 实际落地）

#### fuickjs（JS 侧）

| 文件 | 改动 |
|------|------|
| `src/utils/env.ts` | **核心**：`getHost()` / `isBrowserHost()` / `hasNativeWebApis()` / `hasNativeStorage()`，见 §6.3.3 |
| `src/polyfill/globals.ts` | native-API 块改判 `!hasNativeWebApis()`；storage 拆成独立的 `!hasNativeStorage()` 块 |
| `src/runtime/runtime.ts` | 仅订正注释，判据不变 |
| `src/worker/entry.ts`（新增） | Worker 入口：装标记 + 双桥 + `importScripts(bundle)` + 消息分发 |

**`src/core/` 全部零改动**——reconciler、PageContainer、hostConfig、node、strategies 不动。

#### 构建

`src/worker/entry.ts` **不 import 任何模块**，tsc 因此把它当 script 而非 module，
`npm run build` 直接产出可被 `importScripts` 加载的 `dist/worker/entry.js`，
不需要额外的 esbuild 步骤，也不会带 CommonJS 包装。

> 维护注意：往 `entry.ts` 里加一行 `import`/`export` 就会让 tsc 改用 CommonJS 输出，
> Worker 加载时报 `exports is not defined`。需要共享代码时请复制，不要 import。

业务 bundle 仍是现有产物（esbuild IIFE），由 `importScripts` 加载，格式不变。
若业务 bundle 改为 ESM，则需 `new Worker(url, { type: 'module' })` + `import()`。

#### fjs_engine

| 文件 | 改动 |
|------|------|
| `core/web/web_js_host.dart`（新增） | `WebJsHost` = `JsBridge` + `loadBundle`，两个 Web 桥的公共面 |
| `core/web/worker_js_bridge.dart`（新增） | Worker 实现 + 消息协议 + 自动降级所需的 `isSupported` / `spawn` |
| `core/web/host_js_context.dart` | 改 `implements WebJsHost`，加 `loadBundle`（委托既有 `loadScript`） |
| `core/js_bridge.dart` | 不动 |

#### fuickjs_flutter

| 文件 | 改动 |
|------|------|
| `core/engine/fuick_app_context_web.dart` | 加 `workerUrl` / `isWorkerActive` / `workerFallbackReason`，`_createHost()` 选桥并降级 |
| `core/engine/fuick_app_context_native.dart` | 镜像 `workerUrl` 字段与 `isWorkerActive`（均忽略/恒 false），保持两分支同一公开 API |
| `core/container/fuick_app_view.dart` | 透传 `workerUrl` |
| 其余 | **零改动**（controller / binder / services / parsers 全部依赖窄接口） |

#### 宿主接入

1. `npm run build`，把 `dist/worker/entry.js` 与业务 bundle 一起部署为同源静态文件。
2. `FuickAppView(bundleUrl: ..., workerUrl: ...)`。
3. CSP 需允许 `worker-src 'self'`（同源，通常无需额外放宽）。

Worker 用的是 classic worker + `importScripts`，**bundle 必须与页面同源或允许 CORS**。

### 6.5 风险与取舍

#### 6.5.1 列表滚动白屏（最主要的体验回退）

`getItemDSL` 从同步变异步后，快速滚动时新进入视口的 item 会有至少一次消息往返的空窗，
`FuickItemDSLBuilder` 期间显示 `CircularProgressIndicator`。

- native 端今天就是这个行为，不是新问题；但对**当前 Web 用户是回退**。
- 缓解一：各 `FuickXxxState.getCachedDsl(index)` 的按 index 缓存已存在，滚回不重复请求。
- 缓解二（建议纳入 Phase 2）：**窗口预取**。Worker 侧在 `render` 后主动算出 item DSL 的
  一个区间并推给主线程缓存，把往返从「滚动时」提前到「渲染时」。这需要新增协议消息与
  主线程缓存写入 API。
- 缓解三：调大 Flutter 的 `cacheExtent`。

**这条决定了 Worker 模式是否该对长列表页面默认开启。** 建议先做预取再放开。

#### 6.5.2 双份数据拷贝

DSL 过界从「`dartify()` 一次深转」变成「structured clone + `dartify()`」。
clone 的序列化在 Worker 线程（不占主线程），反序列化在主线程（占）。
净效果通常仍是赚的，但小补丁场景可能持平或略亏。

**优化路径（不在本期）**：复用 [binary-protocol-v2](./binary-protocol-v2.md) 的编码，
Worker 侧直接产出 `ArrayBuffer` 并用 transferable **零拷贝**移交，主线程直接解码成 Dart 对象，
跳过 structured clone 与 dartify 两层。这条路能把 §6.5.2 变成净收益，但工作量显著，
应在 §6.1.1 的度量证明数据搬运确实是瓶颈之后再做。

#### 6.5.3 时序语义变化

`invoke` 从同步变异步。已核对 `FuickJsProxy` 的 7 个调用点，没有调用方在 `invoke` 之后
依赖「JS 已执行完」的假设。且 native 端本就是异步，语义上是**向 native 对齐**而非引入新模型。

需要复核的是宿主业务代码：若接入方在 Dart 侧 `dispatchEvent` 之后立刻读某个由 JS 更新的状态，
会失效。属接入注意事项，框架内无此模式。

#### 6.5.4 调试成本

Worker 内的断点、console、source map 在 Chrome DevTools 里都支持，但多一层
（Sources 面板需切到 worker 上下文）。

错误可见性走三条既有通道，没有新增专用的 `t:'error'` 消息：

- **业务级异常**：`globals.ts` 注册的 `error` / `unhandledrejection` 监听在 Worker 里同样有效，
  `ErrorHandler` 的出口本就是 `dartCallNativeAsync`，自动经消息桥到主线程。
- **`fuickjs.*` 调用抛错**：由 `callReply` 的 `ok:false` 带回（§6.3.2）。
- **Worker 管道级故障**（脚本加载失败、入口自身崩溃）：主线程 `worker.onerror`。

不传 `workerUrl` 即回到主线程模式（§6.3.6），是最直接的调试降级手段。

#### 6.5.5 Worker 里没有 localStorage

Web Storage 规范只把 `localStorage` / `sessionStorage` 暴露给 `Window`。Worker 模式下框架会
注入 `ex/storage.ts` 的内存实现（异步回写 Dart `LocalStorage` 服务），与主线程模式下用的
**浏览器原生 localStorage 不是同一份数据**。

也就是说，同一个应用在 Worker 模式和降级后的主线程模式下看到的 `localStorage` 内容可能不同。
这是 §5 已记录的「两套存储」问题在 Worker 场景下的延伸。业务若依赖持久化，应统一走
`Taro.setStorage` / fuickjs 的 storage 服务，不要直接读写 `localStorage`。

#### 6.5.6 明确不做

- ❌ **SharedArrayBuffer + `Atomics.wait` 实现同步桥**。要求 COOP/COEP 跨源隔离，
  部署约束太重；且 §6.2.5 已证明同步桥在 Web 上可以被完全消除，没有必要。
- ❌ **把 Dart/Flutter 渲染搬进 Worker**。Flutter Web 的渲染必须在主线程，不在本方案范围。
- ❌ **多 Worker 并行渲染多页面**。单 Worker 已够（React 本身单线程），多 Worker 只增加
  状态同步复杂度。一个 app 一个 Worker。

### 6.6 备选方案（评估过，不选）

**主线程时间切片**：不引入 Worker，改用 React 并发特性 / `scheduler` 把 reconcile 切成小片，
让出主线程。

不选的理由：`toDsl()` + `dartify()` 是一次性的同步深遍历，切不开；而且 fuickjs 的 reconciler
是自定义 host config，接入 React 并发调度的改造风险远高于加一层消息桥——
`hostConfig.ts` 是文档明确标注「修改需极其谨慎」的核心渲染路径。

Worker 方案的好处正在于**它不碰 `src/core/` 一行代码**。

### 6.7 分期计划

#### Phase 1：链路打通 —— ✅ 已完成

1. ✅ `utils/env.ts` 宿主判定改造 + `globals.ts` 跟随（§6.3.3）。
2. ✅ `src/worker/entry.ts`，随 `npm run build` 产出 `dist/worker/entry.js`。
3. ✅ `web_js_host.dart` + `worker_js_bridge.dart` + `fuick_app_context_web.dart` 的
   `workerUrl` 开关与四路自动降级（§6.3.6）。

已验证：

- 宿主判定的 7 个场景（含 `engine` / `browser` 两条既有链路的行为不变回归）；
- Worker 入口消息协议的 20 项：握手、`initError`、有返回值/void/抛错/方法不存在/对象不存在的
  `call`、thenable 返回值、`native` 往返的 resolve 与 reject、脏消息容错；
- 整个框架 dart2js 编译通过（含 Wasm dry run），worker 桥代码确实进了产物；
- `fuickjs_flutter` 159 个 core 测试全通过；
- 真实浏览器端到端：Chrome + Safari 均 Worker 激活（`fuick-worker.js` 被请求）、渲染正常，
  回退场景由 `workerFallbackReason` 可见。

#### Phase 2：体验与度量（约 3~4 天）

1. `getItemDSL` 窗口预取（§6.5.1），长列表滚动无白屏。
2. Worker 错误转发接入 `ErrorReportService`（§6.5.4）。
3. 用 `perf-timing` 在真实业务页面上量主线程长任务的改善，产出数据决定是否推荐默认开启。

#### Phase 3（按需）：二进制传输

§6.5.2 的 transferable `ArrayBuffer` 零拷贝路径。**仅在 Phase 2 的数据证明数据搬运是瓶颈时才做。**

### 6.8 结论

| 判定项 | 结论 |
|--------|------|
| 架构可行性 | ✅ 可行 |
| JS→Dart DSL 投递 | ✅ 已经全异步，零改动 |
| Dart→JS 调用 | ✅ 6/7 是 void；`getItemDSL` 的异步形态 native 已在用，Dart 侧零改动 |
| DSL 可克隆性 | ✅ 纯数据，回调按 ID 引用 |
| 核心渲染代码改动 | ✅ `src/core/` 零改动 |
| 唯一硬约束 | ⛔ 同步桥 `dartCallNative` —— 已通过宿主判定改造完全消除 |
| 兼容性 | ✅ 不支持 Worker / CSP 拦截 / 脚本取不到 / 握手超时，四种情况全部自动回退主线程 |
| 主要代价 | ⚠️ 列表滚动白屏（需预取缓解）；小页面收益可能为负；Worker 内 storage 与主线程不共享 |

**建议**：Worker 模式已可用，但**不要无脑开**。先按 §6.1.1 用 `perf-timing` 度量
`t_js_to_dsl` 占比，低于 ~20% 的页面引入 Worker 只是徒增复杂度。
长列表场景在 Phase 2 的窗口预取（§6.5.1）完成前不建议开启。

## 7. 备选路径：DSL → DOM 渲染器（不选，记录备查）

顺着「只复用渲染」的逻辑，存在更轻的终点：业务代码和组件 API 完全不动，JS 侧写一个
WidgetFactory 等价物把 DSL 直接建成 DOM。没有 canvaskit 税，无障碍/SEO/DevTools 全回来。
且方向上有利：fuickjs props 是 Flutter 语义（`mainAxisAlignment` 等），映射到 flexbox
是 1:1 的易事——CSS→Flutter 难，Flutter 语义子集→CSS 不难。

不选的理由：那就不是「复用 WidgetFactory」，渲染一致性从「免费」变成「重新实现并维护
两套渲染器」，背离本方案目标。哪天 Web 体验权重超过像素一致性，再回到这个分叉。

## 8. 分期计划

### 主线程方案

#### Phase 1：渲染闭环（已完成）

1. `fjs_engine` 新增 `JsBridge` 窄接口 + `HostJsContext`（invoke + 双桥 + script 加载 + dartify 出口），
   conditional import 在 fuickjs_flutter 层做（见实现记录第 2 点）。
2. `FuickAppContext` Web 分支（无 isolate、无 Offline）。
3. demo：`xiangqi/web_demo`，`flutter build web` 通过，Chrome 里加载 xiangqi bundle 渲染出首页，
   同步桥 + 反向 DSL 桥全链路打通（见实现记录第 7 点）。

#### Phase 2：服务与打磨（约 1 周）

1. §3.5 的 service/parser Web 化。
2. 资源 URL 方案（`__FUICK_BUNDLE__.root` 前缀）。
3. 与 native 端 DSL 输出做一致性对比测试。

### Worker 方案

见 §6.7（Phase 1 已完成，Phase 2/3 待做）。

总计约 2 周（原含分发层的方案为 6 周，缩减全部来自「不做分发」）。

## 9. 影响文件清单

**fjs_engine**：新增 `core/js_bridge.dart`（窄接口）、`core/web/host_js_context.dart`（Web 桥）、
`core/web/web_js_host.dart` + `core/web/worker_js_bridge.dart`（Worker 桥，见 §6.3.5）。

**fuickjs_flutter**：

- `core/engine/fuick_app_context.dart`：平台拆分（Web 分支不碰 Offline/IsolateWorker）
- `core/engine/fuick_app_context_web.dart`：`workerUrl` / `isWorkerActive` / `workerFallbackReason` 与四路降级
- `core/engine/fuick_app_context_native.dart`：镜像公开面
- `core/container/fuick_app_view.dart`：透传 `workerUrl`
- `core/engine/worker.dart`、`isolate_manager.dart`、`jscontext_delegate.dart`、
  `bundle_compiler.dart`、`engine.dart`：Web 不编译（conditional import 挡掉），代码不动
- `offline/`：Web 不编译，代码不动
- `core/service/{websocket,device_info,file_system}_service.dart`、
  `core/widgets/parsers/image_parser.dart`：Web 实现/降级
- `lib/fuickjs_flutter.dart`：导出条件化

**fuickjs（JS 侧）**：DSL 序列化、组件定义零改动；但修了 3 处浏览器/版本兼容 bug
（`runtime.ts` 的 `bindGlobals`、`polyfill/globals.ts` 的 `setupGlobals`、
`core/hostConfig.ts` 的 `commitUpdate`），新增 `utils/env.ts` 的 `isBrowserHost()`。
Worker 路径新增 `src/worker/entry.ts`（见 §6.4）。

**业务侧**：esbuild 构建（已有）+ `flutter build web` 一同部署。
