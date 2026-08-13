# 页面级分包加载技术方案

> 状态：**方案（技术可行，但当前不建议实施 —— 见 §1.2）**
> 适用范围：FuickJS 业务 bundle 的启动开销优化 —— 把「一个大包一次性 eval」改为「主包 + 页面 chunk 按需 eval」。
> 关联文档：[Bundle 动态下发 bundle-delivery.md](./bundle-delivery.md)、[路由系统 router.md](./router.md)

## 1. 结论先行

### 1.1 技术上可行，改动面很小

引擎与框架的全部前置能力都已就位，不需要动 C/native、不需要动 `hostConfig.ts`、不需要 React `Suspense`、不需要 JS 侧模块加载器。核心判断两条：

1. **把「拆分」和「分发」解耦。** 页面 chunk 作为**普通文件放进现有 offline bundle zip**，跟主包同版本、同签名、同 zip 一起下发。按需的只是 **eval**，不是 download。这样版本 skew 不可能发生、签名/校验/回滚全部免费复用 [bundle-delivery](./bundle-delivery.md) 的既有机制，整个问题从「分布式代码分发」退化为「本地懒执行」。
2. **把加载点放在 Dart→JS 的渲染边界上。** 进入页面 JS 代码的入口只有 `fuickjs.render` / `prewarmPage` 两个，且都由 Dart 发起。让 Dart 在 `invoke('fuickjs','render',...)` **之前**把 chunk eval 进去，JS 渲染链路（`page_render.ts` / `renderer.ts` / `PageContainer.ts`，即"修改需极其谨慎"的那几个文件）**零改动**。

预计改动量：JS ~60 行、Flutter ~120 行、构建工具 ~150 行。

### 1.2 但当前规模下收益偏小，不建议先做

**根因：AOT 字节码已经把大头吃掉了。**

启动的主要成本本来是「解析 1.6 MB JS 源码」（几百毫秒级）。但构建期 `qjsc -b` 已经把它换成了「反序列化 4.1 MB 字节码」——`JS_ReadObject` 是反序列化不是解析，量级低得多。**分包想省的那部分，AOT 已经省过一轮**，分包拿到的只是 `JS_ReadObject` 的增量。

还有一层：它优化的可能不是主项。按 [bundle-delivery §6.4](./bundle-delivery.md) 自己的记录，`promoteAndGetRoot` 首次的 on-open Ed25519 验签就是 **~100-200ms**。若 bundle eval 只有几十毫秒，分包省下的量在一个还含着 100-200ms 验签的 TTI 里基本看不出来——缓存验签结果的 ROI 更高。且 eval 跑在 worker isolate，代价是「转圈时间变长」而非「UI 卡顿」，紧迫性再降一档。

### 1.3 实施前的决策门槛

**动手前先测一个数字**，成本几乎为零（埋点都已存在）：

| 埋点 | 位置 | 看什么 |
| --- | --- | --- |
| `[Performance] load bundle cost` | `fuick_app_context.dart:160` | 主包 eval 绝对耗时 |
| `[Perf] page=... total=` | `page_render.ts:216` | 首屏 TTI，用于算 eval 占比 |

冷启动各跑一次，得到 **bundle eval 在 TTI 中的占比**：

- **eval < 50ms 或占比 < 15%** → 本方案归档，不要实施。
- **eval > 200ms 或占比 > 30%** → 从 §13 P0 开始。

### 1.4 什么条件下值得重新启动

满足任一条即重新评估：

1. **页面数量涨一个量级。** 1.6 MB 是 demo 规模；两百个页面的真实应用可能是 5-10 MB 源码 / 15-25 MB 字节码，`JS_ReadObject` 与 QuickJS 堆占用会从「几十毫秒」变成「几百毫秒 + 几十 MB」，届时收益是线性放大的。
2. **必须走 JSC 路径**（iOS 默认 `useJscOnIos = true`；demo 是手动设 `false` 才走 QuickJS 的）。JSC 无字节码格式，`evalBinaryFileFromPath` 直接抛 `UnsupportedError`，只能 eval 源码——那里 parse 是真成本，分包收益明显得多。
3. **包体积成为瓶颈。** 但注意本方案**不解决包体积**（§2），那是 Stage 2 的事，而 Stage 2 恰好是旧方案复杂度的来源。

## 2. 与旧方案的差异（为什么这版更简单）

旧方案 `page-split-loading.md` 复杂度的来源，基本都出自「chunk 是独立可下发、可独立版本的产物」这个前提。一旦接受这个前提，就必须处理：chunk 独立版本协商、主包与 chunk 版本 skew、chunk 独立签名与校验、下载失败/超时/重试、加载中的错误 UI、JS 侧异步模块 runtime（进而牵出 Promise 化渲染 / Suspense）。

本版把这个前提砍掉：

| 维度 | 「独立分发」思路 | 本方案 |
| --- | --- | --- |
| chunk 存放 | 独立 CDN 产物，独立版本号 | 主包 zip 内的普通文件，无独立版本 |
| 版本一致性 | 需要协商 + skew 处理 | 同 zip 原子发布，**结构上不可能 skew** |
| 签名校验 | chunk 需要独立签名链路 | 自动进 `manifest.files`，**复用现有 Ed25519 + 逐文件 SHA-256** |
| 网络失败 | 需要重试 / 降级 / 错误态 UI | **无网络路径** |
| 加载时机 | JS 运行时异步 `import()` | Dart 在 render 前同步保证 |
| JS 侧 runtime | 需要模块加载器 + Promise 化渲染 | **不需要**，只加一个"填回 component"的回调 |
| 收益 | 包体积 + 启动 | **启动 + 内存**（包体积不变） |

代价是**包体积不减**（整包还是一次下完）。这是有意的取舍：从现状看瓶颈在启动 eval 而不是下载（见 §11），而按需下载可以在完全相同的接缝上后置追加（§13 Stage 2），不需要现在为它付复杂度。

## 3. 现状盘点

分包需要的能力，逐项对照现有实现：

| 能力 | 现状 | 位置 |
| --- | --- | --- |
| 同一 context 多次 eval | ✅ 已在生产使用（`__FUICK_BUNDLE__` 注入、WebSocket 片段、debug 热重载） | `fuick_app_context.dart` |
| 从文件路径零拷贝 eval | ✅ `evalFileFromPath` / `evalBinaryFileFromPath`（C 层 `fopen`） | `jscontext_interface.dart:69-89` |
| 字节码加载 + 版本校验 | ✅ peek BC_VERSION → 不匹配隔离为 `.stale` → 回退 `.js` | `fuick_app_context.dart:193-218` |
| 包目录 / assets 双来源 | ✅ `_loadFromPackageDir` / `_loadFromAssets` 两分支 | `fuick_app_context.dart:193-241` |
| 包内任意文件已被签名 | ✅ zip 解压全部文件，`manifest.files` 逐文件 SHA-256 + Ed25519 | `bundle_verifier.dart` |
| Dart 主动调 JS 函数 | ✅ `ctx.invoke(obj, method, args)` | `fuick_js_proxy.dart` |
| 页面加载延迟的 loading UI | ✅ `rootNode == null` 时已渲染 `CupertinoActivityIndicator` | `fuick_page_view.dart:204-214` |
| DSL 迟到的缓冲 | ✅ `_pendingRenders` / `flushPendingUpdates` | `fuick_page_delegate.dart:112-173` |
| 路由表 | ⚠️ 内存数组，`component` 由构建期静态 import 闭包持有 | `router/router.ts:65` |
| 一个 app 一个 QuickJS context，所有页面共享 | ⚠️ 决定了 React/框架实例必须唯一（见 §6.2） | `fuick_app_context.dart:122-133` |
| 代码分割 | ❌ 单 outfile，无 splitting；`Suspense` 在 hostConfig 里被显式 no-op | `esbuild.js:55-84`、`hostConfig.ts:235-240` |

**唯一真正缺失的是构建期分割 + 一个加载接缝。** 引擎侧一行 native 代码都不用改。

## 4. 总体架构

```
┌─ 构建期 ────────────────────────────────────────────────────────┐
│  页面清单（demo: app.tsx / Taro: app.config.ts pages+subPackages）│
│      │                                                          │
│      ├─ 主包 entry：shared 运行时 + 路由桩 + 常驻页              │
│      │      └─ esbuild → bundle.js (+ qjsc → bundle.qjc)         │
│      │                                                          │
│      └─ 每个 chunk 一个生成 entry：import 页面 + 自注册           │
│             └─ esbuild(format:iife, shared 外部化)               │
│                    → chunks/<id>.js (+ chunks/<id>.qjc)          │
│      重复输入检查（metafile）：同一模块不得落在两个产物里         │
└─────────────────────────────────────────────────────────────────┘
                              │ 全部进同一个 bundle zip
                              ▼   （manifest.files 自动覆盖 → 签名免费）
┌─ 运行时 ────────────────────────────────────────────────────────┐
│  启动：只 eval 主包                                              │
│     globalThis.__FUICK_SHARED__ = { react, fuickjs, ... }         │
│     Router 里是「有 path/meta/guard、component 为空」的桩         │
│                                                                  │
│  打开页面：                                                       │
│     FuickPageDelegate.renderPage(pageId, path, params)            │
│       ├─ id = await ctx.invoke('fuickjs','resolveChunk',[path])   │
│       ├─ id != null → ChunkLoader.load(id)                        │
│       │     └─ evalBinaryFileFromPath(chunks/<id>.qjc) 零拷贝     │
│       │           └─ chunk IIFE 自调 __fuickDefineChunk           │
│       │                 └─ Router 桩被填上 component              │
│       └─ ctx.invoke('fuickjs','render',[pageId, path, params])    │
│              → 既有渲染链路，完全无感知                            │
└─────────────────────────────────────────────────────────────────┘
```

## 5. 构建产物与约定

### 5.1 目录布局

在 [bundle-delivery §4](./bundle-delivery.md) 的 zip 结构上只加一个 `chunks/` 目录：

```
<root>/
├── manifest.json          # files 里自动多出 chunks/*.js 条目
├── manifest.sig
├── bundle.qjc             # 主包（首选）
├── bundle.js              # 主包（回退）
├── chunks/
│   ├── detail.js          # 页面 chunk（回退）
│   ├── detail.qjc         # 页面 chunk（首选）
│   └── ...
└── assets/
```

`chunks/` 里的 `.js` 进 `manifest.files` 参与逐文件 SHA-256 校验；`.qjc` 与主包同规则**不入 manifest**（可能是端上 `BundleCompiler` 本地编译产物，hash 不固定；被篡改会因字节码格式不匹配加载失败并回退已验签的 `.js`）。

> **没有 `chunks.json`。** path → chunkId 的映射只存在于主包的路由桩里，是唯一事实来源，Dart 侧不持有副本（§7.1）。

### 5.2 chunk entry 生成

每个 chunk 的 entry 由构建工具生成（临时目录，不入库）：

```ts
// .fuickjs-tmp/chunks/detail.entry.tsx  —— 生成物
import DetailPage from '../../src/pages/DetailPage';
import OrderPage from '../../src/pages/OrderPage';

globalThis.__fuickDefineChunk('detail', {
  '/detail/:id': (p) => React.createElement(DetailPage, p),
  '/order/:id': (p) => React.createElement(OrderPage, p),
});
```

esbuild 配置（与主包的差异）：

```js
{
  entryPoints: ['.fuickjs-tmp/chunks/detail.entry.tsx'],
  outfile: 'dist/chunks/detail.js',
  format: 'iife',        // 主包是 esm；chunk 用 iife，保证无顶层 import/export，
                         // 可直接作为全局脚本 eval，也能被 qjsc -b 编译
  bundle: true,
  platform: 'neutral',
  metafile: true,        // 用于 §6.2 的重复输入检查
  plugins: [sharedExternals(SHARED)],
  // 不带主包的 banner（console/process 兜底已由主包装好）
}
```

一个 chunk 可以装多个页面（`N:1`），因为 chunk 粒度太细会把一次 eval 换成多次文件 IO。默认「一页一 chunk」，允许在配置里声明分组；Taro 的 `subPackages` 天然就是分组边界（§10.2）。

### 5.3 shared externals 插件

主包在 eval 末尾把共享模块挂到全局：

```ts
// 主包 entry 尾部（生成）
globalThis.__FUICK_SHARED__ = {
  react: React,
  fuickjs: Fuickjs,
  // 项目声明的业务共享模块
};
```

chunk 侧用一个 esbuild plugin 把这些 bare specifier 换成读全局的虚拟模块：

```js
function sharedExternals(names) {
  const filter = new RegExp(`^(${names.map(escapeRe).join('|')})$`);
  return {
    name: 'fuick-shared-externals',
    setup(build) {
      build.onResolve({ filter }, (a) => ({ path: a.path, namespace: 'fuick-shared' }));
      build.onLoad({ filter: /.*/, namespace: 'fuick-shared' }, (a) => ({
        contents: `module.exports = globalThis.__FUICK_SHARED__[${JSON.stringify(a.path)}];`,
        loader: 'js',
      }));
    },
  };
}
```

必须列入 `SHARED` 的模块（这些都持有模块级单例状态，重复实例化会静默出错）：

| 模块 | 为什么必须唯一 |
| --- | --- |
| `react` | hooks dispatcher 是模块级变量，两份 React 会让 chunk 里的 hooks 报 "invalid hook call" |
| `react/jsx-runtime` | 若把 esbuild 的 `jsx` 切成 `automatic` 则同上（当前默认 `transform`，走 `React.createElement`） |
| `fuickjs` | `Router` 路由表、`renderer` 的 `containers/roots`、i18n、`PageContext` 全是模块级单例 |
| `react-reconciler` / `scheduler` | 只被 `fuickjs` 内部使用，但防御性列入，避免 chunk 直接引用时复制一份 |
| `@tarojs/taro-fuickjs`、`@tarojs/components-fuickjs`、`taro-css-to-fuickjs/runtime` | Taro 项目同理 |
| 业务侧 store / api / 全局配置 | 项目自行声明：`shared: ['@/store', '@/api']` |

## 6. 正确性护栏

分包最容易出的两类事故，都必须在构建期机械拦住，不能靠约定。

### 6.1 路由桩必须自带 meta / guard

`NavigatorService.push` 在 JS 侧会**先**做 `Router.resolve(path)` + `runGuards`，**再**才让 Dart push 页面（`NavigatorService.ts:233`）。这一步发生时 chunk 还没加载，所以：

- `path` / `name` / `meta` / `beforeEnter` / `redirect` **必须留在主包的桩上**；
- 只有 `component` 允许在 chunk 里。

构建期校验：若某路由的 `beforeEnter` 定义在被拆出的页面文件里，直接构建失败并报出文件位置。否则表现是「跳转前守卫静默不执行」——一个鉴权漏洞级别的坑。

### 6.2 同一模块不得落进两个产物

如果页面 A 和页面 B 都 `import` 了 `utils/cart.ts`，而 A、B 在不同 chunk，那 `cart.ts` 会被复制两份、**产生两个模块实例**。无状态工具函数只是浪费体积；一旦有模块级状态（缓存、单例、计数器），行为会静默分叉——这是最难查的一类 bug。

用 esbuild `metafile` 机械检查（`outputs[*].inputs` 直接给出每个产物的输入模块集合）：

```js
// 伪码
const owner = new Map();               // input → 产物名
for (const [out, meta] of Object.entries(metafile.outputs)) {
  for (const input of Object.keys(meta.inputs)) {
    if (SHARED_RESOLVED.has(input)) continue;
    if (owner.has(input)) fail(`${input} 同时进入 ${owner.get(input)} 和 ${out}；请加入 shared 或移回主包`);
    owner.set(input, out);
  }
}
```

同一条规则也顺带禁掉「chunk 之间互相 import 页面」。报错信息要直接给出修复动作：**加入 `shared` 列表，或移回主包**。

## 7. JS 侧改造

三处，都在路由层，不碰渲染链路。

### 7.1 `RouteConfig` 加 `chunk`

```ts
// router/router.ts
export interface RouteConfig {
  path: string;
  component?: ComponentFactory;   // 桩上为空，chunk 加载后填入
  chunk?: string;                 // 新增：所属 chunk id；无则代码在主包
  // name / meta / beforeEnter / redirect 不变（§6.1 要求留在主包）
}

const loadedChunks = new Set<string>();

/** chunk 自注册入口：把 component 填回对应的路由桩 */
export function attachChunk(chunkId: string, components: Record<string, ComponentFactory>): void {
  for (const [path, factory] of Object.entries(components)) {
    const route = routes.find((r) => r.path === path);
    if (route) route.component = factory;
    else routes.push({ path, component: factory, chunk: chunkId }); // 容错：桩缺失时兜底注册
  }
  loadedChunks.add(chunkId);
}

/** Dart 在 render 前调用：返回还需要加载的 chunk id，已就绪/无需分包则返回 null */
export function resolveChunk(path: string): string | null {
  const to = resolve(path);                        // 复用既有 matchPath，无逻辑双写
  const id = to?.matched.chunk;
  if (!id || loadedChunks.has(id)) return null;
  return id;
}
```

用 `resolve()` 意味着 `:param` 通配、`*` 兜底、优先级规则**全部与实际路由匹配完全一致**——不需要在 Dart 侧再写一份 `matchPath`，也就没有两份实现漂移的风险。

### 7.2 挂到全局

```ts
// runtime/runtime.ts  bindGlobals()
fuickjs: {
  render: PageRender.render,
  destroy: PageRender.destroy,
  resolveChunk: Router.resolveChunk,        // 新增：给 Dart 查
  // ...
},
// chunk IIFE 调用的自注册入口
__fuickDefineChunk: Router.attachChunk,     // 新增
```

### 7.3 `doRenderAsync` 的防御分支

正常路径下 Dart 保证 chunk 已加载，这里只是不让不变量被破坏时变成静默 404：

```ts
// core/page_render.ts，在「1. 路由未匹配」分支之后
if (!to.matched.component && to.matched.chunk) {
  console.error(`[page_render] chunk "${to.matched.chunk}" not loaded for ${path}`);
  r.update(wrapWithProviders(pageId, buildLoadingApp()), pageId);
  return;
}
```

`buildLoadingApp()` 已存在（`page_render.ts:121`）。**没有** `React.lazy`、没有 `Suspense`、没有把渲染 Promise 化 —— `hostConfig.ts` 里那批 Suspense no-op 保持原样。

## 8. Flutter 侧改造

### 8.1 抽出可复用的「eval 一个代码单元」

`FuickAppContext` 现在的 `_loadFromPackageDir` / `_loadFromAssets` / `_evalJsAt` 已经包含了全部需要的逻辑（qjc 优先、BC_VERSION peek、`.stale` 隔离、`.js` 回退、包目录 vs assets 双来源）。把它按「相对路径」参数化即可复用，主包传 `bundle`，chunk 传 `chunks/<id>`：

```dart
/// 加载一个代码单元（主包或 chunk）。
/// relPath: 不含扩展名的相对路径，如 'bundle' / 'chunks/detail'
Future<void> evalCodeUnit(String relPath, {String? root}) { /* 由现有实现提炼 */ }
```

主包调用变成 `evalCodeUnit('bundle', root: _activeBundleRoot)`，行为与现在完全一致。

### 8.1.1 字节码 chunk 如何 eval

**与主包现在加载 `bundle.qjc` 完全同一条路，无新机制。** `.qjc` 是 `JS_WriteObject(JS_WRITE_OBJ_BYTECODE)` 的裸输出——现有 `_peekBcVersionOfFile` 读首字节与 `ctx.bytecodeVersion` 比对即证明这一点（首字节就是 BC_VERSION）。

```
ctx.evalBinaryFileFromPath('chunks/detail.qjc', returnValue: false)
  → qjs_evaluate_file_unified(flags = BYTECODE)
      → C 层 fopen 直读（不经 Dart 堆）
      → JS_ReadObject + JS_EvalFunction
          → chunk 顶层 IIFE 执行 → __fuickDefineChunk → 填回 component
```

字节码只是「已编译好的顶层函数」，执行它就是跑那段顶层脚本，与 eval 源码在语义上无差别，自注册副作用照常发生。两个必须遵守的约束：

- **编译形态与加载形态必须一致。** chunk 用 `format: 'iife'` 产出全局脚本，编译时不得按 module 编，加载时 `isModule: false`（与主包相同）。
- **JSC 路径没有字节码。** `JscContext.evalBinaryFileFromPath` 直接抛 `UnsupportedError`，而 `JscContext.evalBinary` 更危险——它把字节码当 UTF-8 源码 `utf8.decode`。因此 JSC 下 chunk 只能用 `.js`；`evalCodeUnit` 复用主包既有的「qjc 失败 → 回退 .js」分支即可自动覆盖。

### 8.2 `ChunkLoader`

每个 `FuickAppContext`（即每个 JS context）一个实例——「已加载」是 context 级状态。

```dart
class ChunkLoader {
  ChunkLoader(this._ctx, this._evalCodeUnit);

  final IQuickJsContext _ctx;
  final Future<void> Function(String relPath) _evalCodeUnit;
  final Map<String, Future<void>> _inflight = {};

  /// 确保 path 所需的 chunk 已 eval 进 context。无分包时是一次极轻的 invoke。
  Future<void> ensureForPath(String path) async {
    final id = await _ctx.invoke('fuickjs', 'resolveChunk', [path]) as String?;
    if (id == null || id.isEmpty) return;
    // 并发打开同一 chunk 的两个页面时，JS 侧此刻都还没标记 loaded，
    // 会各返回一次 id；用 inflight 去重避免重复 eval。
    return _inflight.putIfAbsent(id, () async {
      try {
        await _evalCodeUnit('chunks/$id');
      } catch (e, s) {
        logger.e('[ChunkLoader] load chunk "$id" failed: $e\n$s');
        _inflight.remove(id);   // 允许下次重试
        rethrow;
      }
    });
  }
}
```

`resolveChunk` 在 JS 侧只是一次数组遍历 + Set 查询；`invoke` 走既有 isolate 请求队列，与后续的 `render` 天然保序。

### 8.3 渲染入口改 async

```dart
// fuick_page_delegate.dart
Future<void> renderPage(int pageId, String path, Map<String, dynamic> params) async {
  await controller.chunkLoader.ensureForPath(path);
  controller.jsProxy.render(pageId, path, params);
}
```

`prewarmPage` 同样处理（`_prewarmCache` 的写入保持同步，只把 `jsProxy.render` 那一行推后到 chunk 就绪）。

调用方 `FuickPageView._checkAndRender` 是 `void`，改成 `unawaited(...)` 即可 —— **DSL 迟到本来就是既有支持的路径**：`rootNode == null` 时 `build()` 已经渲染 `CupertinoActivityIndicator`（`fuick_page_view.dart:204-214`），DSL 到达时 `_handleRenderDsl` → `setState`。所以 chunk 加载延迟不需要任何新 UI。

## 9. 时序

```
用户点击 → Navigator.push
   │
   ├─ [JS] NavigatorService.push
   │     Router.resolve(path)          ← 命中桩（有 path/meta/guard）✅
   │     runGuards(to, from)           ← 守卫在主包，正常执行 ✅
   │     dartCallNativeAsync('Navigator.push', ...)
   │
   ├─ [Dart] pushWithPath → 新建 FuickPageView(pageId)
   │     build(): rootNode == null → CupertinoActivityIndicator
   │
   ├─ [Dart] renderPage(pageId, path, params)
   │     id = await invoke('fuickjs','resolveChunk',[path])   ← 'detail'
   │     await evalCodeUnit('chunks/detail')
   │           qjc 存在 && BC_VERSION 匹配 → evalBinaryFileFromPath（零拷贝）
   │           否则 → .stale 隔离 → evalFileFromPath('.js')
   │              └─ [JS] chunk IIFE → __fuickDefineChunk('detail', {...})
   │                    └─ 路由桩被填上 component，loadedChunks.add('detail')
   │     invoke('fuickjs','render',[pageId, path, params])
   │
   └─ [JS] doRenderAsync → component 已就绪 → 既有链路 → DSL
         └─ [Dart] _handleRenderDsl → setState → 首帧

第二次进同一 chunk 的页面：
   resolveChunk → null（loadedChunks 命中）→ 直接 render，零额外开销
```

## 10. 兼容与降级

### 10.1 未分包时零影响

`resolveChunk` 只在路由桩带 `chunk` 字段时返回非 null。因此：

| 场景 | 行为 |
| --- | --- |
| 构建未开分包（dev / 旧包 / 回滚到分包前的版本） | 所有路由无 `chunk` → `resolveChunk` 恒返回 null → 与现状完全一致 |
| debug 模式（`debugBusinessCode` 走 WebSocket 整包注入） | 同上，不开分包 |
| 主包是新版但 chunk 文件缺失 | `evalCodeUnit` 抛错 → 日志 + `_inflight` 清理 → `doRenderAsync` 走 §7.3 的 loading 兜底，不崩 |
| 无 offline 包（`root == null`，走 `assets/js`） | chunk 从 `assets/js/chunks/<id>.js|.qjc` 读，与主包同一套双分支逻辑 |
| 回滚到旧版本 bundle | zip 是原子的，主包和 chunk 一起回滚，无需额外处理 |

「不开分包 = 走老路」这条让整个特性可以按 bundle 灰度，出问题构建侧一个开关即可回退。

### 10.2 Taro 侧

`plugin-platform-fuickjs` 现在已经在做「读 `app.config.ts` 的 `pages` → 生成 static import + `Router.register`」（`entry-template.ts:43-68`）。改成「生成桩 + 每个 chunk 一个 entry」是**同一个生成器加一个分支**，主包/chunk 两次 esbuild 复用同一份 `bundle()`。

顺带能补上一个现有缺口：插件目前**完全不识别** `subPackages`（`normalizeAppConfig` 只读 `pages`/`tabBar`/`window`），只在 `subPackages` 里声明的页面既不会被打进包也不会被注册。而 `subPackages` 语义上就是分包边界，正好一对一映射成 chunk 分组，等于顺手对齐了小程序的心智模型。

## 11. 收益与验收

现状实测（demo 主包）：`bundle.js` **1.6 MB** → `bundle.qjc` **4.1 MB**（字节码是源码 2.5×）。启动时这 4.1 MB 全量 eval，全部页面的闭包与常量进 QuickJS 堆。

收益方向：主包 eval 时间 ↓、启动期 QuickJS 堆 ↓、首屏 TTI ↓；代价是首次进入非常驻页多一次文件 IO + eval。**包体积不变。**

**收益上限受 §1.2 约束**：由于 AOT 已消除了 parse 成本，本方案能省的只是 `JS_ReadObject` 的增量，因此上限就是「主包 eval 耗时 × 被拆出去的代码占比」。§1.3 的门槛必须先过，否则不要进入实施。

验收要测的指标（不预设数字，按实测决策）：

| 指标 | 怎么测 | 期望 |
| --- | --- | --- |
| 主包 eval 耗时 | `_loadBundle` 已有的 `[Performance] load bundle cost` | 显著下降 |
| `bundle.qjc` 体积 | 构建产物 | 显著下降；`chunks/` 总和可能使 zip 略增（qjc 膨胀 2.5×，压缩后可控） |
| 首屏 TTI | `perf-timing` 的 `[Perf] page=... total=` | 下降或持平 |
| 首次进入非常驻页 | 同上，对比分包前 | **回归上限**：本方案最需要盯的指标 |
| 二次进入同 chunk | 同上 | 与分包前持平（`resolveChunk` 返回 null） |
| QuickJS 堆 | 现有内存测试页 | 启动期下降 |

> 若「首次进入非常驻页」的回归不可接受，先调 chunk 分组粒度（把高频页合进主包或同一 chunk），而不是加预测式预加载——`prewarmPage` 已经会走 `ensureForPath`，天然就是预加载手段。

## 12. 影响文件清单

**修改（JS/TS，`fuickjs_framework/fuickjs/`）**

- `src/router/router.ts` — `RouteConfig.chunk`、`loadedChunks`、`attachChunk`、`resolveChunk`，并挂进导出的 `Router` 对象。
- `src/runtime/runtime.ts` — `bindGlobals()` 增加 `fuickjs.resolveChunk` 与 `globalThis.__fuickDefineChunk`。
- `src/core/page_render.ts` — `doRenderAsync` 增加 §7.3 防御分支。
- `src/index.ts` — 若需对外暴露 chunk 相关类型。

**修改（Flutter，`fuickjs_framework/fuickjs_flutter/`）**

- `lib/core/engine/fuick_app_context.dart` — 提炼 `evalCodeUnit(relPath, root:)`；创建并持有 `ChunkLoader`。
- `lib/core/engine/chunk_loader.dart` — **新增**，§8.2。
- `lib/core/container/fuick_app_controller.dart` — 暴露 `chunkLoader`。
- `lib/core/container/fuick_page_delegate.dart` — `renderPage` / `prewarmPage` 改 async。
- `lib/core/container/fuick_page_view.dart` — `_checkAndRender` 里 `unawaited`。
- `lib/fuickjs_flutter.dart` — 按需导出。

**修改（构建，`fuickjs_demo/js/`）**

- `esbuild.js` — 拆成「主包 build + chunks build」；新增 `sharedExternals` 插件、chunk entry 生成、metafile 重复输入检查、`beforeEnter` 位置校验。
- `tools/bundle/pack-all.js` — zip 时带上 `chunks/`；`pack-bundle.js` 把 `chunks/*.js` 计入 `manifest.files`。
- 新增分包配置（哪些页常驻主包、chunk 分组、`shared` 列表）。

**修改（Taro，`taro-fuickjs/packages/plugin-platform-fuickjs/`）**

- `src/entry-template.ts` — 生成桩 + chunk entry。
- `src/platform.ts` — `normalizeAppConfig` 读 `subPackages`；`bundle()` 支持多次调用。

**文档**

- 本文；`docs/README.md` 索引；`docs/router.md` 补 `chunk` 字段与 §6.1 约束。

## 13. 分期实施

| 阶段 | 内容 | 可验证结论 |
| --- | --- | --- |
| **P-1 决策门槛（必做）** | 按 §1.3 冷启动测 bundle eval 在 TTI 中的占比 | **不过门槛就归档**，不进 P0 |
| **P0 手工验证接缝** | 手写一个 chunk 文件 + 手写桩，跑通「Dart eval chunk → 填回 component → 渲染」 | 加载机制成立，风险出清 |
| **P1 运行时** | §7 JS 三处 + §8 Flutter `ChunkLoader`；未分包时零影响 | 主干可合，行为不变 |
| **P2 构建期** | `sharedExternals` 插件 + chunk entry 生成 + §6 两个校验 | demo 产出主包 + chunks，测 §11 指标 |
| **P3 offline 接通** | `pack-bundle.js` 把 chunks 计入 manifest；验签/回滚回归 | 分包包可下发 |
| **P4 Taro** | `entry-template.ts` 桩化 + `subPackages` → chunk 分组 | Taro 侧对齐，顺带补 subPackages |

**Stage 2（可选，不建议现在做）：按需下载。** 只有当包体积成为实测瓶颈时才做。接缝完全不变 —— `ChunkLoader` 里 `evalCodeUnit` 之前多一步「本地没有则下载 + 验签」。此时才需要付网络失败/超时/重试/错误 UI 的复杂度，也才需要处理 chunk 与主包的版本一致性（建议做法：chunk 作为 offline 的第二个 package，用主包版本号做强绑定，不匹配就整体不用）。

## 14. 明确不做

- **组件级 lazy / `Suspense`**：本方案粒度就是页面。`hostConfig.ts` 的 Suspense no-op 保持原样。
- **chunk 独立版本 / 独立签名链路**：chunk 与主包同 zip 原子发布（§2）。
- **JS 侧模块加载器 / `require` / 动态 `import()`**：`attachChunk` 一个回调就够了。
- **Dart 侧的 path 匹配实现**：统一走 JS 的 `Router.resolve`（§7.1），不做逻辑双写。
- **`chunks.json` 之类的映射文件**：映射只存在于主包路由桩。
- **按需下载**：见 Stage 2。
