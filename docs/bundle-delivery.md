# Bundle 动态下发技术方案

> 状态：**已实现**（`fuickjs_flutter/lib/offline/` 全量落地：Ed25519 验签 + SHA-256 + staged/active/history 状态机 + 内置包懒解压 + 回滚）
> 适用范围：FuickJS 的 QuickJS 业务 bundle（`assets/js`）的可信下发、回滚与端上加载。
> 公开 API：`Offline.init(OfflineConfig(...))`，详见 [fuickjs_flutter/README.md](../fuickjs_flutter/README.md)。

## 1. 背景与目标

FuickJS 的业务逻辑以 QuickJS 代码（`.qjc` 字节码 / `.js` 源码）+ 相关资源（图片等）形式存在于 App 的 `assets/js`。当前没有"运行时更新业务代码"的能力，发版只能跟随 App 发版。本方案提供一套**可信的动态 bundle 下发**机制。

### 1.1 目标

1. **可信下发**：bundle 以 zip 分发，支持 **SHA-256 完整性校验** 与 **Ed25519 签名验签**，代码防篡改。
2. **代码加密（可选）**：预留加密 hook，当前阶段不启用；仅针对**代码**，图片永不加密。
3. **内置 vs 线上对比**：App 内置一份 bundle；启动后与线上最新版本比对，有更新则下载；**下载完成前继续使用内置/当前 bundle**。
4. **图片加载**：bundle 内含图片，端上能从解压目录加载，且**对业务完全透明**（开发者照写相对路径）。
5. **回滚**：远程配置指向目标版本；客户端先查本地 history 复用，没有再下载。
6. **下次打开生效**：新 bundle 不影响当前已打开的页面/容器，于**下次打开**时切换。

### 1.2 非目标（本期不做）

- 代码加密的具体算法落地（仅预留 hook）。
- 差量（patch）更新（先做整包替换，结构上为差量留出空间）。
- 图片的逐文件签名 / 加密。

## 2. 现状评估（offline 模块）

现有 `fuickjs_flutter/lib/offline/` 是一套 DDD 分层清晰的**H5 离线包**加载器，作为底座可复用，但不足以支撑本需求。增量演进需补齐：

| 现状                                                             | 问题                                        | 本方案对策                                      |
| ---------------------------------------------------------------- | ------------------------------------------- | ----------------------------------------------- |
| `_getFileMd5` 用 **MD5**                                         | 哈希算法已不安全                            | 全量切 **SHA-256**                              |
| 无签名                                                           | 信任锚仅是服务端下发 `shasum`，无密码学防线 | 引入 **Ed25519 签名 manifest**                  |
| 只对整 zip 算一次 hash                                           | 无 manifest、无逐文件校验                   | 新增 **manifest（仅代码）+ 逐代码文件 SHA-256** |
| `activePackages` 扁平覆盖                                        | 无 active/staged/history，**无法回滚**      | 引入**包状态机 + 版本保留**                     |
| 清理只留 active                                                  | 旧版本被删，回滚无包可回                    | 清理保留 **active + staged + history**          |
| 无 staged 缓冲                                                   | 解压即激活，不满足"下次打开生效"            | 引入 **staged → 下次打开提升为 active**         |
| 路径写死 `assets/h5`                                             | 面向 H5，不是 QuickJS                       | 切到 **`assets/js`** 并接通引擎                 |
| 下载写最终路径 + `exists` 短路                                   | 半包可能被当完整包                          | 下载到 `.tmp` 再 rename                         |
| `CleanService` 用空 `Package` 反推路径 + 读全局 `Offline.config` | 脆弱、难测                                  | 目录布局收敛到 `FileStorage`，依赖注入          |
| `Offline` `late` 静态单例无守卫                                  | init 前调用 / 中途失败抛错                  | 改为 `await whenInitialized`（init 未完成前调用方阻塞等待，而非早退返回 null）；移除易被误用的公开 `initialized` 布尔标志 |
| `DownloadRepository` 接口未实现                                  | 死抽象                                      | 移除或落地                                      |

## 3. 总体架构

```
┌──────────────┐     发布          ┌──────────────────┐
│  构建/签名工具 │ ───────────────▶ │  CDN/对象存储      │  bundle zip + manifest.sig
│ (Node 脚本)   │                   │  版本元数据接口     │  {version, sha256, url, minAppVersion}
└──────────────┘                   └────────┬─────────┘
   私钥(后端持有)                              │ HTTPS
                                             ▼
┌────────────────────────────────────────────────────────────────────┐
│ App (Flutter)                                                        │
│  ┌────────────┐   sync    ┌──────────────┐  verify   ┌────────────┐ │
│  │ 版本元数据   │ ────────▶ │ offline 模块  │ ────────▶ │ BundleVerifier │
│  │ getter      │           │ (状态机/回滚) │  (Ed25519 │ (内置公钥)   │ │
│  └────────────┘           └──────┬───────┘  +SHA256) └────────────┘ │
│                                  │ promote (下次打开)                 │
│                                  ▼                                   │
│  ┌──────────────┐   packageRoot  ┌─────────────────┐  inject        │
│  │ FuickAppContext │ ───────────▶ │ qjc 字节码直送   │  __FUICK_BUNDLE__ │
│  │ (promote/加载)  │              │ QuickJS C 层 fopen │ ─────────────▶ QuickJS ctx
│  └──────────────┘                └──────────────────┘                │
└──────────────────────────────────────────────────────────────────────┘
```

## 4. Zip 包目录结构

bundle zip 解压后的目录布局（解压根即 `<root>`）：

```
<root>/
├── manifest.json          # 元信息 + 代码文件 SHA-256 清单（被签名）
├── manifest.sig           # 对 manifest.json 的 Ed25519 签名（base64）
├── bundle.qjc             # 入口代码（字节码，首选）
├── bundle.js              # 入口代码（源码，回退；可与 .qjc 同时存在）
└── assets/                # 资源（不入 manifest、不签名、不加密）
    └── images/
        ├── logo.png
        └── banner.webp
```

约定：

- 代码文件放在 `<root>` 顶层；资源统一放在 `<root>/assets/` 下。
- 业务引用资源相对 `assets/` 目录：`<Image src="images/logo.png" />` ↔ `<root>/assets/images/logo.png`。

## 5. manifest.json —— 只声明代码

```jsonc
{
  "name": "wallet_bundle",
  "version": "1.2.0",
  "minAppVersion": "3.0.0", // 兼容性：低于此 App 版本不加载
  "keyId": "key-2026-01", // 签名密钥标识，便于轮换
  "entry": "bundle.qjc", // 入口文件（zip 内固定 bundle.qjc / bundle.js）
  "codeForm": "qjc", // qjc | js
  "files": [
    // 只列 .js（.qjc 不入 manifest：可能是本地编译的，sha256 不固定）
    { "path": "bundle.js", "sha256": "<hex>" },
  ],
  "encryption": null, // 预留：仅对代码可选；图片永不加密
}
```

- `files` **只包含 `.js` 源码文件**；`.qjc` 字节码不入 manifest——它可能是端上 `BundleCompiler` 本地编译生成的（引擎版本升级后重新编译），sha256 不固定。`.qjc` 被篡改不会执行恶意代码：字节码格式不匹配时引擎加载失败 → 回退到已验签的 `.js`。图片等资源也不出现在 manifest，不计 hash、不加密。
- `manifest.sig` 用 Ed25519 对 `manifest.json` 字节整体签名 → 等价于对所有 `.js` 代码文件 hash 清单签名。

## 6. 完整性与验签

两层职责清晰：

| 层级   | 覆盖对象           | 手段                                                                  | 失败处理             |
| ------ | ------------------ | --------------------------------------------------------------------- | -------------------- |
| 整包层 | 整个 zip（含图片） | 下载后校验 zip 的 SHA-256 == 版本接口下发值                           | 丢弃，不解压         |
| 代码层 | 仅 `.js` 源码      | Ed25519 验 `manifest.sig` + 对 `files` 内每个 `.js` 文件 SHA-256 比对 | 丢弃 staging，不激活 |

- **公钥内置 App，私钥后端签名服务持有**，App 永不接触私钥。
- `BundleVerifier` 只遍历 `manifest.files` 做 `.js` hash 校验，**跳过 `.qjc`**（可能是本地编译的，sha256 不固定）、**不枚举/不校验图片**。
- 图片防篡改由**整包 SHA-256**（来自 HTTPS 下发的版本元数据）兜底。
- `keyId` 强匹配：manifest 必须显式声明 keyId，且必须命中 `OfflineConfig.signaturePublicKeysB64` 中某一把公钥；**无回退到首把 key 的兼容路径**。

### 6.1 验签流水线（下载分支）

```
download zip → sha256(zip) == meta.sha256 ?            // 整包层
  → unzip 到 staging
  → 读 manifest.json + manifest.sig
  → Ed25519.verify(pub[keyId], manifest.json, sig) ?   // 代码层-签名
  → for f in manifest.files: sha256(file) == f.sha256 ? // 代码层-逐文件
  → minAppVersion 满足当前 App 版本 ?
  → 原子 rename staging → packages/<name>/<version-hash>  // 提升为 staged
```

### 6.2 三道运行时验签闸

bundle 落地到本地后，端上还有**三道独立闸**持续保护（不只是下载时）：

| 闸                                      | 触发时机                                | 实现                                                                    | 阻塞主 isolate? | 失败行为                                        |
| --------------------------------------- | --------------------------------------- | ----------------------------------------------------------------------- | --------------- | ----------------------------------------------- |
| **闸 1 · 启动后台验签**                 | `Offline.init()` 完成后 fire-and-forget | `PackageService._runBackgroundVerify` 提交到子 isolate 的 4 worker pool | **否**          | 失败 → 删包 + 从 in-memory 状态移除 + log       |
| **闸 2 · on-open 验签**                 | `Offline.promoteAndGetRoot` 返回 dir 前 | `PackageService.verifyOnOpen` 调用子 isolate 单包 verifyDir             | 是（await）     | 失败 → 删包 + 兜底回退 builtin（**JS 不执行**） |
| **闸 3 · latest.json 验签（暂未启用）** | 远端同步拉版本列表时                    | `RemotePackagesVerifier.verifySignedBytes`                              | 否（同步链路）  | 失败 → 回落内置包                               |

> **闸 3 当前未启用**：`Offline._fetchRemotePackages` 直接信任 host 的 `offlinePackagesGetter` 返回值（由 host 自行保证 latest.json 可信：HTTPS / 内置证书 / 后端鉴权等任选）。`RemotePackagesVerifier` class + 单元测试 + `sign-latest.js` Node 工具保留，未来需要时只需取消 `offline.dart` 中相关代码注释即可启用。
>
> **远程元数据兜底链**（`offlinePackagesGetter` 返回 null 时）：优先用**上次成功落盘的 `latest.json` 缓存**（`_loadCachedRemotePackages`），无缓存（文件不存在 / 解析失败 / `packages` 空）再兜底 `internalPackages`。这样网络抖动（host 把网络失败表现为返回 null）不会把上次已 active 的远程包误判为 removed 而删掉——缓存让 sync 仍能匹配到它们。

#### 时序图

```
T0  app 启动
T1  Offline.init() 开始
    ├── BundleVerifyIsolate.create()       // 启动后台 isolate（一次性 ~30-50ms）
    ├── PackageService.init()              // 立即返回（< 10ms）
    │   ├── 读 registry
    │   ├── flag-level 校验（毫秒级）
    │   ├── persist
    │   └── _startBackgroundVerify()       // fire-and-forget
    │       └──→ 后台 isolate 跑 verifyDir × N
    └── [init 完成]                         // 约 30-50ms 后

T2  用户点击 bundle（假设后台验签还在跑）
    Offline.promoteAndGetRoot(name)
      ├── promoteStaged / getActive / _ensureBuiltinActive
      ├── await verifyOnOpen(pkg, dir)     // 闸 2：终态闸
      │     └─→ 后台 isolate 跑 verifyDir
      │           ↓
      │     ok  → 返回 dir → 引擎加载 JS
      │     fail → deletePackage + 兜底 builtin
      └── 返回

T3  后台验签完成（晚于 T2 也无所谓）
      → 清理 in-memory 状态中已被 on-open 拦截的坏包（幂等 delete）
```

### 6.3 安全语义

- **JS 在 on-open verify 通过前不执行**：`await verifyOnOpen` 是同步语义，引擎拿到 dir 后才读取 JS；与"加载后异步检测"（race condition）有本质区别。
- **删除幂等**：闸 1 和闸 2 可同时对同一包触发 `deletePackage`；`LocalPackageRepository.deletePackage` 对不存在的目录是 no-op。
- **后台验签与 on-open 不冗余**：后台验签清理 in-memory 状态（避免下次 `getActivePackage` 返回坏包）；on-open 是最终防御（用户真要打开时再确认）。两条路径都失败也能兜底 builtin。
- **on-open 验签的 mtime 指纹短路**：`PackageService._doVerifyOnOpen` 在真正验签前，先算一个「参与验签文件」（`manifest.json` + `manifest.sig` + 所有非 `.qjc` 的 `manifest.files`）的 `path:mtime:size` 指纹；若与上次**通过**的验签记录的指纹一致，则跳过 isolate 重验直接放行。这样稳态下每次打开省掉 ~100-300ms 的重复验签。指纹只存内存（`_verifiedFingerprint`，key 为唯一目录 `name-version-sha256`），进程重启后首开仍走完整验签；任一文件被改动 → mtime/size 变化 → 指纹失效 → 强制重验 → 检出。`.qjc` 被排除在指纹外（其 sha 不固定、本就不参与验签，`BundleCompiler` 后台重编不应触发重验）。
- **所有 `_registry` 修改操作通过 `_withRegistryLock` 互斥锁串行化**（`init`/`_runBackgroundVerify`/`applyReady`/`promoteStaged`/`reuseLocalAsStaged`/`deactivatePackages`/`verifyOnOpen`）。这解决了"后台验签 snapshot 写回覆盖 sync 修改"等竞态。读操作不参与锁（Dart 单线程，list 引用赋值原子）。
- **`preparePackage` 同包 in-flight 去重 + `promoteStaging` 锁内化**：首启时页面加载（`_ensureBuiltinActive`）与后台 sync（`_syncAndClean`）会对同一内置包并发调用 `preparePackage`。若各自跑完整流程，会在同一 staging 目录上交错 `_resetDir`/`_unzip`，导致 staging 半写。实现：`DownloadService._prepareInflight`（key: `versionShasumName`），并发调用共享同一个 in-flight Future 直接 join 结果。staging 写入（`_resetDir`/`_unzip`）在锁外，此去重是 staging 目录并发安全的唯一防线。`promoteStaging`（rename staging→packages + flag）已从 `preparePackage` 移到 `PackageService._doApplyReady` 的 `_withRegistryLock` 锁内执行，与 registry 入册原子化——消除"已落地未入册"窗口。
- **`cleanUnreferenced` 串行化到 init 阶段**：`CleanService.cleanUnreferenced` 扫描 packages/ 删不在 `registry.retained` 的孤儿目录。`readdir` 是流式扫描——扫描期间 `applyReady` 的 `promoteStaging` 刚 rename 的新目录会被后续读到，若此时 `retainedDirs` 用的是旧快照（不含新目录），会误删——引擎读到正在被删除的 `bundle.js`（SyntaxError），第二次打开自愈。**根治方案**：`cleanUnreferenced` 挪到 `Offline.init` 完成（`_initialized = true`）之前同步执行。此时 `promoteAndGetRoot` 会 `await whenInitialized`（init 未完成前阻塞等待，而非早退返回 null），架构上不可能并发，不需要锁保护。之后 `_syncAndClean` 只做远程同步 + 下载缓存清理（不涉及 packages/）。

### 6.4 启动性能

- `Offline.init()` 自身：约 30-50ms（isolate 启动） + 10ms（registry 解析） = 约 50ms 内返回
- 后台验签：与 UI 渲染、引擎 init 并行，用户感知不到
- `promoteAndGetRoot` 首次：on-open 验签 ~100-200ms（与 loading skeleton 并行展示）；后续打开命中 mtime 指纹缓存，on-open 验签降到 sub-ms

## 7. 包状态机与目录布局

### 7.1 状态

| 状态      | 含义                                                |
| --------- | --------------------------------------------------- |
| `staged`  | 已下载校验通过，等待"下次打开"提升为 active         |
| `active`  | 当前生效，引擎加载它                                |
| `history` | 曾经 active 的旧版本，保留用于本地复用（默认 N 个） |

`PackageRegistry`（持久化为 `registry.json`）维护三组列表：`active / staged / history`。

### 7.2 目录布局（`FileStorage`，env 隔离）

```
<AppDocuments>/offline/<env>/
├── registry.json                       # 包状态机
├── latest.json                         # 最近一次远程元数据快照
├── staging/<name>/<version-hash>/      # 解压中转区（校验通过后原子 rename）
├── packages/<name>/<version-hash>/     # 正式包目录（含 manifest/code/assets）
└── download/<name>-<version-hash>.zip  # 下载缓存
```

`version-hash = <version>-<sha256前N位>`，作为版本目录名与身份标识。

### 7.3 保留与清理策略

按**每个 bundle name** 独立计算（通常仅一个 bundle）。

**保留上限**

| 槽位      | 数量                               | 是否留文件 | 说明                             |
| --------- | ---------------------------------- | ---------- | -------------------------------- |
| `active`  | 恰好 1                             | ✅         | 当前生效，**绝不删除**           |
| `staged`  | **至多 1（单槽位）**               | ✅         | 下次打开要切换的「最新候选」     |
| `history` | 至多 N（`retainVersions`，默认 3） | ✅         | 曾经服役过的旧版，供回滚本地复用 |

每个 bundle 磁盘占用上限 = `active(1) + staged(1) + history(N)` = **N+2** 份解压目录（N=3 → 最多 5）。下载用的 `.zip` 在**成功提升为 staged 后立即删除**。

**staged 是单槽位（替换语义，非队列）**

`staged` 只保留最新的一个。若已有一个**从未被打开（从未 promote）**的 staged，又下载了新版本：

```
staged = v1.2（从未打开）
   │  下载 v1.3 验签通过
   ▼
staged = v1.3      ← v1.2 直接删除（从未 active 过 → 不进 history）
```

即：从未生效过的中间版本不会堆积，只留最新待生效包。若新版本恰在 `history` 中，则直接从 history 提升，不重复建目录。

**history 仅在「提升」时产生**

```
promote（下次打开）:
   旧 active → 进 history（它真正服役过）
   staged   → 变 active；staged 槽清空
   若 history 数 > N → 删最旧的（LRU）
```

history 增长只与「实际切换版本次数」相关，与「下载次数」无关。

**启动兜底 GC（sync 后 `cleanExpired`）**

- 扫 `packages/` 所有目录，凡**不在 registry 的 `active ∪ staged ∪ history` 引用集**内一律删（含被替换的 staged、超出 N 的 history 残留、崩溃产生的孤儿）。
- 保证：无论中途如何崩溃，磁盘最终收敛到 registry 明确引用的 ≤ N+2 份。

**低磁盘驱逐（下载/解压前预检）**

预估所需空间（`zip 大小 + 解压膨胀冗余`），不足时按优先级逐级释放，每级后重新检查：

```
1. 临时垃圾：无引用 download/*.zip、staging/ 残留
2. history：按进入时间最旧优先（LRU），可一直删到 0
      ↑ 够空间则继续下载
3. 仍不够 → 放弃本次下载，保留 active 正常运行（记日志/可上报）
```

原则：**永远不删 active**；空间挤不出时**整体放弃更新**而非删到一半。极端情况下回滚链可降级到「仅 active(1) + 内置兜底」，内置包是最终兜底。

## 8. 版本切换（含回滚）

**可用性判定**：bundle 经整包 SHA-256 校验、Ed25519 验签、逐代码文件 hash 校验并解压成功后，即视为**可用**。

远程 `packages` 直接指向目标版本即可（版本号可以下降）：

```jsonc
{ "name": "wallet_bundle", "version": "1.1.0", "sha256": "...", "url": "..." }
```

客户端 sync 判定为 `updated` 后：

1. **先查本地 retained**（history / staged / active）：若已有同 `name + version + sha256` 且磁盘文件完整 → 直接 `staged`，**跳过下载**。
2. 本地没有 → `DownloadService.preparePackage` 下载验签解压。

下次打开 `promoteStaged` 生效。远程只下发可信版本，客户端不维护 bad 黑名单。

### 8.1 staged 生效前的安全校验（误发熔断）

`staged` 是单槽位的「待生效候选」，但它**就绪 ≠ 必然生效**。`promoteStaged` 在提升前会校验 staged 是否仍是「当前已知线上最新版本」，命中以下规则之一才放行，否则**丢弃 staged（删文件 + 移出 registry），沿用当前 active**：

| 条件                                                 | 判定       | 理由                                                           |
| ---------------------------------------------------- | ---------- | -------------------------------------------------------------- |
| staged 是内置包                                      | **恒放行** | 内置是最终兜底；线上有更新版时内置 staged 必须能顶上，否则白屏 |
| 远程列表未就绪（`_remotePackages` 空 / 不含该 name） | **放行**   | 离线 / 首启后台 sync 未回来时不阻断，保证可用性                |
| 远程包 staged 版本 == 线上最新版本                   | **放行**   | 正常升级路径                                                   |
| 远程包 staged 版本 ≠ 线上最新版本                    | **丢弃**   | 误发熔断：见下                                                 |

**解决的问题**：误发包 v2 已下载并 `staged`，但**尚未** promote（用户还没打开）。运营发现后撤回、下发配置改回 v1。由于 sync 只以 active 为基准比对，**不会主动清理残留的 staged v2**——若无此校验，下次打开就会把 v2 提升为 active。加上本校验后：

```
staged = v2（误发，未 promote）
   │  后台 sync 拉到线上最新 = v1，刷新 _remotePackages
   ▼
下次打开 promoteStaged:
   staged v2 ≠ 线上最新 v1（且非内置） → 丢弃 v2，沿用 active v1   ✅ 误发包不生效
```

**时序边界**：撤回依赖客户端能联网拿到新配置刷新 `_remotePackages`。若 v2 已 staged，且用户恰在「后台首次 sync 刷新 `_remotePackages` 之前」打开，则该次仍可能放行 v2（此刻列表未就绪），下次打开（列表已就绪）才丢弃纠正。彻底堵住这百毫秒窗口需让 promote 阻塞等远程列表，与「首启不阻塞」相悖，故取最终收敛的折中。

## 9. 生效时机（下次打开）

- sync 只产出 **staged**，绝不动当前 active，正在运行的页面/容器不受影响。
- 下次创建 `FuickAppContext`（打开页面/App 容器）时调用 `Offline.promoteAndGetRoot(appName)`：
  - 若存在 staged 且通过 §8.1 安全校验 → 原子提升：旧 active 进 history，staged 变 active，返回新 active 的目录。
  - staged 未通过校验（误发熔断）→ 丢弃 staged，沿用当前 active。
  - 否则返回当前 active 目录；无任何包则按 §9.1 懒解压内置目录。

### 9.1 内置包解压时机（懒解压 + 版本幂等）

**关键事实**：内置包的**代码不需要解压**——`FuickAppContext` 直接用 `rootBundle.load('assets/js/<name>.qjc')` 从 App 资源读字节码执行。解压内置包到磁盘目录的**唯一目的是图片**（`__FUICK_BUNDLE__.root` 需指向磁盘目录，图片才能解析为 `file://<root>/assets/...`）。

**策略：只有当内置包真正成为加载目标时才解压，每个 App 版本至多一次。**

内置包成为加载目标的场景：

1. **首次启动**：registry 为空，无任何 remote active/staged。
2. **App 升级后内置版本 > 当前 active**：内置胜出。
3. **兜底**：无 active 时懒解压内置包。

> 只要 active 是有效的 remote 包，内置包完全不解压（代码也不从它走），省启动 IO。

**幂等机制**：

```
内置成为目标时:
  packages/<name>/<builtin-version-hash>/ 已存在且有 flag?
     → 是: 跳过，直接用该目录            (后续启动命中此处，零解压)
     → 否: rootBundle 读 assets/js/<name>.zip
          → 解压到 staging → (可选)验签 → 原子 rename 到 packages
          → registry 记为 active
```

内置版本号来自打包进 assets 的 `bundles.json`/manifest；App 升级换了内置 zip → `version-hash` 变化 → 自动触发一次重新解压。

### 9.2 首屏策略（方案 A：正确优先 + Loading）

图片首帧必须正确，故采用 **await 解压后再渲染**：

- 若内置（或目标包）尚未解压完成，**先展示 loading 状态**，待 `root` 就绪再注入 `__FUICK_BUNDLE__.root` 并渲染。
- 复用 `FuickAppContext.isReady` / `appController.isBundleLoaded` 等通知量驱动容器 UI：解压+加载未完成 → loading；完成 → 正常首屏。
- 一次性成本：仅首次启动（或 App 升级后首次）付费解压；后续启动命中已解压目录，无 loading、直接渲染。
- 代码与解压并行（assets rootBundle 已被框架内部缓存，IO 极轻），但渲染发生在 `root` 就绪之后，保证图片首帧正确。

### 9.3 无内置包场景（thin-app 模式）

**内置包是可选的**，方案同时支持「有内置」（离线即可首启）与「无内置」（瘦 App，首启强依赖网络）。是否存在内置包**自动推断**（`assets/js` 是否打包了 zip / `bundles.json`），不必显式配置。

无内置时与有内置的关键差异：

1. **代码无 fallback**：§10.1「root 为空回退 `assets/js`」不成立——既无内置 zip，也无 `assets/js/<name>.qjc/.js`。第一个 remote 包就绪前，引擎没有任何代码可执行。
2. **首启 = 强制先下载**：
   ```
   首启 + 无内置 + registry 空:
     → 容器展示 loading
     → 下载最新 remote → 验签 → 解压 → 直接 active（首启无旧 active 需保护，不走"下次打开"）
     → root 就绪 → 注入 __FUICK_BUNDLE__ → 渲染首屏 → 退出 loading
   ```
3. **首启无网络**：无离线兜底，展示 **loading → 超时转错误/重试态**（非白屏），网络恢复后重试。这是 thin-app 模式的固有代价。
4. **回滚地板下移**：兜底链从 `active → history → 内置` 变为 `active → history →（无内置则清空 active，强制重新拉取 remote）`。

**建议**：强烈建议**至少内置一份最小可用包**，保证首启离线可用并给回滚一个永久地板；无内置仅适合「强在线、可接受首启转圈」的业务。

## 10. 引擎集成

### 10.1 加载链路

```
FuickAppContext._doInit()
  → isReady=false → 容器展示 loading（见 §9.2）
  → root = await Offline.promoteAndGetRoot(appName)   // 下次打开生效 + 回滚后真实目录
       内部确保目标包已解压（内置首启/升级时按 §9.1 懒解压，await 完成）
  → _loadSingleBundle(appName, root)
       优先 root/bundle.qjc：peek 首字节比对 BC_VERSION，不匹配隔离为 .stale 后回退 .js
       匹配则 ctx.evalBinaryFileFromPath(qjcPath) —— C 层 fopen 直送，零 Dart 内存拷贝
       root 为空回退 assets/js/<name>.qjc|.js（rootBundle）
  → 注入 globalThis.__FUICK_BUNDLE__ = { name, version, sha256, root, frameworkVersion }  // eval 业务代码之前
  → ctx.evalBinaryFileFromPath / ctx.evalBinary / ctx.eval
  → isReady=true → 退出 loading，渲染首屏（root 已就绪，图片首帧正确）
```

### 10.2 `__FUICK_BUNDLE__` 与图片透明解析（核心机制）

**结论：不需要 `BundleScope`，统一用 `globalThis.__FUICK_BUNDLE__`。**

依据：每个 `FuickAppContext` 用唯一 `contextId` 创建独立 `JsContextDelegate`（独立 QuickJS context、独立 `globalThis`），因此 `__FUICK_BUNDLE__` **天然按 bundle 隔离**，无需 InheritedWidget 解决作用域。

图片加载**对开发者透明**，无 `resolveAsset` API：

```
引擎 eval 前注入 globalThis.__FUICK_BUNDLE__ = { name, version, sha256, root, frameworkVersion }
        │
框架在 node.ts toDsl() 序列化时，检测 Image 的 src/errorSrc：
   若为相对路径（非 http(s):// / file:// / data: / '/' 开头）
        → file://<root>/assets/<src>
        │
DSL 里 src 已是 file:// 绝对路径
        │
Flutter ImageParser 现有 file:// 分支直接处理 ✅（零改动）
```

要点：

- 业务照写 `<Image src="images/logo.png" />`，改写在框架内部 `toDsl()` 单点完成。
- `ImageParser` 已有完整 file:// 文件分支（存在性判断、SVG/栅格、降级 errorSrc），改写后的 src 直接命中，**Flutter 侧零改动**。
- 内置包也 zip 化解压到包目录，图片始终在 `<root>/assets/...`，内置/线上路径一致；`root` 为空时退化为 `Image.asset`。
- 后续若 Taro CSS 背景图需要，可在 css-to-props 层补同样的改写规则（同一 choke point 思路）。

`__FUICK_BUNDLE__` 各字段语义（数据源 `Offline.getActivePackage` 的 registry 元数据，非验签信息）：

| 字段               | 类型       | 来源                          | 内置 assets / debug payload 时 |
| ------------------ | ---------- | ----------------------------- | ------------------------------ |
| `name`             | `string`   | `appName`                     | 恒有                           |
| `version`          | `string?`  | `Package.version`             | `null`                         |
| `sha256`           | `string?`  | `Package.sha256`（整包哈希）  | `null`                         |
| `root`             | `string?`  | 动态包解压根目录绝对路径      | `null`（图片退化 `Image.asset`）|
| `frameworkVersion` | `string`   | `fuickjsFrameworkVersion` 常量 | 恒有                           |

> 业务可直接从 `globalThis.__FUICK_BUNDLE__` 读 `version`/`sha256`/`frameworkVersion` 做埋点/自检上报，无需额外 API。`version` 是**业务 bundle** 版本，`frameworkVersion` 是**框架层**版本，二者语义不同，勿混淆。

## 11. 构建与签名流水线（Node 工具）

位于 `fuickjs_demo/js/tools/bundle/`（私钥不入库，`.gitignore` 排除）：

| 脚本             | 职责                                                                                                                           |
| ---------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| `gen-keys.js`    | 生成 Ed25519 密钥对：`bundle_signing_key.pem`（私钥）/ `bundle_signing_pub.pem` / `bundle_signing_pub.b64`（内置 App）         |
| `pack-bundle.js` | 收集代码(+assets) → 算代码文件 SHA-256 → 写 `manifest.json` → 私钥签名 `manifest.sig` → 打 zip → 输出整包 SHA-256 供版本元数据 |

`pack-bundle.js` 关键参数：`--name --version --key --keyId --minAppVersion --js --qjc --assets --out`。
图片仅 copy 进 zip 的 `assets/`，**不计 hash、不入 manifest**。

`package.json` 增加脚本：`bundle:keys`、`bundle:pack`。

## 12. 数据模型与配置变更

### 12.1 `Package`（扩展）

新增字段：`sha256`（**非空必填**）、`minAppVersion`、`state`。`sha256` 为 `String`（非可空），缺失/空 sha256 的包在 `Package.fromJson` 即抛 `ArgumentError`，无法进入内存；旧的可空字段 + 运行时抛 `StateError` 的 `integrity` getter 已删除。`fromJson/toJson/copyWith` 同步。批量解析入口（`PackageRegistry.fromJson` / internal / remote 列表）用 `Package.tryFromJson` 容错——单个坏包（缺 sha256 等）跳过而非拖垮整批。

### 12.2 `OfflineConfig`（扩展）

新增：`appVersionGetter`（minAppVersion 比对）、`signaturePublicKeyB64`（可多把/按 keyId）、`retainVersions`（history 保留数，默认 3）、`enableSignatureVerify`（包校验开关，默认 `true`）。

- `signaturePublicKeysB64`：从 `required` 改为**可选**（默认 `const {}`），向后兼容——现有调用方均显式传入，不受影响。仅当 `enableSignatureVerify=true` 时启动期才强制要求非空。
- `enableSignatureVerify`：**代码层验签开关**。默认 `true`；关闭后跳过 BundleVerifier 层（Ed25519 签名 + 逐代码文件 SHA-256），但仍保留整包 zip SHA-256 传输完整性校验（见 §12.4）。
- `forcedUpdateRemoteWait`：强制更新判定前等待远程包列表就绪的上限，默认 3s，`Duration.zero` 表示不等（见 §12.4）。
- `forcedUpdateTimeout`：强制更新下载的最长等待时间，默认 30s，超时回退旧 active（见 §12.4）。

### 12.3 `SyncResult`

`added` / `updated` / `removed` 三组列表。

### 12.4 包校验开关（`enableSignatureVerify`）与强制更新（`mustBeUpdated`）

#### 包校验开关

两层校验是独立的：

| 层 | 校验内容 | 依赖签名密钥 | 开关控制 |
|----|----------|--------------|----------|
| **BundleVerifier**（代码层） | Ed25519 验 `manifest.sig` + 逐代码文件 SHA-256 | 是 | `enableSignatureVerify` |
| **DownloadService**（传输层） | 整包 zip SHA-256（基于版本元数据） | 否 | 恒开启，不可关 |

`enableSignatureVerify = false` 时（内部测试、无签名基础设施、仅需传输完整性的宿主）：

- `BundleVerifier` 构造不再要求非空公钥（`allowEmptyKeys: true`）。
- `Offline._initBody` 启动期校验条件化，空公钥不抛 `StateError`。
- `verifyIsolate` 不创建（`null`）；`PackageService` 天然跳过后台重验签与 on-open 验签（`verifyIsolate == null` 直接返回/信任上层）。
- `DownloadService` 跳过 `verifyDir`，但仍保留整包 zip SHA-256：**SHA-256 不匹配仍会拒绝**（传输完整性不依赖签名密钥）。

`enableSignatureVerify = true`（默认）时：

- `Offline._initBody` 与 `DownloadService` 构造均 **fail-fast**：未配置 `signaturePublicKeysB64`（空）即抛错（`StateError` / `ArgumentError`），避免验签因无 key 匹配而把正常包误判为"被篡改"删除。
- `DownloadService` 的 `enableSignatureVerify` 参数缺省时回落到 `config.enableSignatureVerify`，保证开关与公钥配置来自同一处、不会漂移。

默认 `true`，行为不变（向后兼容）。

#### 强制更新（`mustBeUpdated`）

`Package.mustBeUpdated` 字段（此前仅作 OR 合并保留标记）现接入加载决策：

- **触发时机**：`Offline.promoteAndGetRoot(name)` 打开 bundle 时。
- **配置来源**：`mustBeUpdated` 是**远程接口（latest.json / bundles.json 的 `packages[]`）下发的字段**，不是 bundle 包内 `manifest.json` 的内容——`manifest.json` 只含 `name/version/minAppVersion/keyId/entry/codeForm/files`。因此强制更新在**下载前**即可判定，无需等 bundle 下载完。
- **内置包豁免**：内置包（internal，即 `assets/js/bundles.json` 内置资产）恒不触发强制更新——即使其记录被标了 `mustBeUpdated=true` 也忽略。`mustBeUpdated` 是远程下发的强制更新语义，内置包是兜底资产，不应弹强制更新；且远程列表缺失时会兜底降级为 internalPackages（见下「远程元数据兜底链」），若不做豁免会误触发。
- **判定**：`PackageService.findForcedUpdateTarget(name)` 返回 remote 中 `name` 匹配、`mustBeUpdated=true`、**非内置**、且版本 ≠ 当前 active 的目标包；无则返回 `null`（不触发）。
- **用户确认（可选）**：`OfflineConfig.onForcedUpdateConfirm: (String name, String version) → Future<bool>`。配置后，在**下载之前**征询接入方；返回 `true`（同意）才进入下载流程，返回 `false`（拒绝）则**跳过本次强制更新，直接用本地已生效（active）包**。未配置该回调时视为同意（默认行为，与既有强制更新语义一致，不阻塞、不弹框）。
- **等远程列表就绪**：远程同步（`_syncAndClean`）是启动后 fire-and-forget 跑的，而判定只看内存态 `_remotePackages`，冷启动首次打开往往早于列表落地 → 不等就必然判成"无强制更新"，强制更新退化为下次启动生效。因此 `_ensureForcedUpdate` 先 await 一个「列表就绪」信号（`_remoteListReady`，在 `setRemotePackages` 后立即 complete，**不含**随后的下载），上限 `OfflineConfig.forcedUpdateRemoteWait`（默认 3s）。超时 / 拉取失败都按"无强制更新"继续。代价是列表未就绪时打开被拖慢最多这么久（在线通常几百毫秒内就绪），对打开延迟敏感的宿主可设 `Duration.zero` 关掉这段等待。
- **执行**：确认通过后 `_ensureForcedUpdate(name)` 同步 `await downloadService.preparePackage(forced)`（in-flight 去重，若后台 sync 已在下载则 join），成功则 `applyReady` + `promoteStaged` 强制用新版本；下载失败（或 `preparePackage` 返回 null，如 minAppVersion 不满足）则**回退旧 active**，不阻断加载。
- **下载超时**：该 await 阻塞 bundle 打开，Dio 默认无 connect/receive timeout，弱网或服务端挂起会让页面一直 pending。故整体加了 `OfflineConfig.forcedUpdateTimeout`（默认 30s）上限，超时回退旧 active；**下载不取消**，后台跑完照样 staged，下次打开生效。
- **并发去重**：`_ensureForcedUpdate` 按 name 合并 in-flight Future（`_forcedUpdateInflight`）。`preparePackage` 自身的去重发生在确认回调**之后**，若不在外层合并，两个页面同时打开同一 bundle 会弹两次确认框。
- **不反向阻断**：`_doEnsureForcedUpdate` 整体 try/catch，确认回调抛错、提升失败等一律退化为"用旧 active"——强制更新失败不能反过来让 bundle 打不开。
- **边界**：mustBeUpdated 通常即 remote 最新，`_isStagedPromotable` 的「staged==remote 最新」校验自然通过；若 mustBeUpdated 非最新（罕见），`promoteStaged` 丢弃并回退，语义合理，不做特殊处理。

#### 下载进度透出（`onDownloadProgress` / `getDownloadProgress`）

远程包下载进度对接入方可见，两种方式：

- **push**：`OfflineConfig.onDownloadProgress: (String name, double progress)` 回调，`name` 为 bundle 名，`progress` 0.0~1.0。框架内按进度增量（≥1%）节流，但仍可能较频繁，驱动 UI 建议自行再节流。终止态恒透出：`1.0` 表示下载完成，`-1.0` 表示失败/取消。
- **pull**：`Offline.getDownloadProgress(String name)` 同步查询最近一次进度（含终态），未下载过返回 0。适合进度条首帧读取；实时更新请用 push 回调。

注意：**仅远程下载触发进度**；内置包（`assets/js` 解压）无下载进度，`preparePackage` 完成后直接可用。

## 13. 影响文件清单

**新增（Flutter）**

- `offline/domain/entities/bundle_manifest.dart` — manifest 数据模型（仅代码文件）。
- `offline/domain/services/bundle_verifier.dart` — Ed25519 验签 + 逐代码文件 SHA-256。
- `offline/domain/value_objects/package_registry.dart` — active/staged/history。
- `offline/util/version_utils.dart` — semver 比较 / minAppVersion 判定。

**修改（Flutter）**

- `pubspec.yaml` — 增加 `cryptography`（Ed25519）。
- `offline/domain/entities/package.dart` — 见 §12.1。
- `offline/config/offline_config.dart` — 见 §12.2。
- `offline/data/datasources/file_storage.dart` — staging 目录、`assets/js` 路径、registry 文件。
- `offline/domain/repositories/package_repository.dart` + `data/repositories/local_package_repository.dart` — registry 读写、staging、内置 zip。
- `offline/domain/services/download_service.dart` — SHA-256、下载到 `.tmp` 再 rename、staging 解压、`BundleVerifier`、minAppVersion、原子提升。
- `offline/domain/services/package_service.dart` — 状态机、`applyReady/promoteStaged/reuseLocalAsStaged`。
- `offline/domain/services/sync_service.dart` — minAppVersion → added/updated/removed。
- `offline/domain/services/clean_service.dart` — 保留 active+staged+history；目录布局收敛、去全局耦合。
- `offline/offline.dart` — 编排 + `whenInitialized`（await 守卫，init 未完成前调用方阻塞等待而非早退）；公开 `getActivePackageRoot/promoteAndGetRoot`。
- `core/engine/bundle_preloader.dart` — `prewarm/consume` 支持 `packageRoot`，回退 `assets/js`；`invalidate`。
- `core/engine/fuick_app_context.dart` — promote 取 root、注入 `__FUICK_BUNDLE__`。

**修改（JS/TS）**

- `fuickjs/src/node.ts` — `toDsl()` 对 Image `src/errorSrc` 相对路径自动改写为 `file://<root>/assets/...`。
- （不新增 JS 公开 `resolveAsset`，不引入 `BundleScope`。）

**新增（构建工具）**

- `fuickjs_demo/js/tools/bundle/{gen-keys.js,pack-bundle.js,.gitignore}`，`package.json` 增加 `bundle:keys/bundle:pack`。

## 14. 测试计划

- `bundle_verifier_test`：有效包通过；篡改**代码**文件 → 验签失败；篡改**图片** → 代码层验签不受影响、整包 SHA-256 拦截；无公钥时的降级行为；跨语言一致性（Node 打包 → Dart 验签）。
- `package_service_test`：staged→active 提升、history 保留 N、reuseLocalAsStaged、staged 生效前校验（线上最新放行 / 误发版本丢弃 / 远程未就绪放行 / 内置豁免）。
- `download_service_test`：SHA-256 不匹配丢弃、半包 rename、minAppVersion 不满足不激活、内置源缺失。
- `sync_service_test`：minAppVersion 推导。
- 图片：相对 src 在有/无包时分别解析为 `file://<root>/assets/...` 与 `Image.asset` 兜底。

## 15. 分期实施

1. **P0 完整性底座**：MD5→SHA-256、`Package` 扩展、`FileStorage` 切 `assets/js` + staging、下载 `.tmp` rename。
2. **P1 验签**：`BundleManifest` + `BundleVerifier` + Ed25519，构建工具 `gen-keys/pack-bundle`，公钥内置。
3. **P2 状态机与生效**：`PackageRegistry` + 状态机 + staged→下次打开提升 + 引擎接通 `packageRoot`。
4. **P3 版本切换**：远程改配置 + `reuseLocalAsStaged` 本地复用。
5. **P4 图片透明解析**：`__FUICK_BUNDLE__` 注入 + `toDsl()` 改写。
6. **P5（可选）代码加密**：落地 `encryption` hook。

## 16. 已确认默认值（已落地）

1. 资源引用约定以 `assets/` 为根：`src="images/logo.png"` → `file://<root>/assets/images/logo.png`（`node.ts toDsl()` 单点改写）。
2. 内置包 zip 化：与远程包统一校验/解析路径，懒解压到包目录。
3. `retainVersions = 3`（`OfflineConfig` 可覆写）。

## 17. 实施状态（P0–P4 已完成）

### 17.1 验签层（详细）

- **`BundleVerifier`**（[bundle_verifier.dart](../fuickjs_flutter/lib/offline/domain/services/bundle_verifier.dart)）
  - Ed25519 验 `manifest.sig`（`pointycastle` Ed25519 实现）
  - 严格 keyId 匹配（无回退到首把 key 的兼容路径）
  - 逐代码文件 SHA-256 比对（仅 manifest.files 中列出的代码，不含图片）
  - 错误返回明确 reason（`manifest.json missing` / `signature mismatch` / `hash mismatch` 等）

- **`BundleVerifyIsolate`**（[bundle_verify_isolate.dart](../fuickjs_flutter/lib/offline/domain/services/bundle_verify_isolate.dart)）
  - 后台 isolate + 4 worker pool（idle completer + queue 公平分摊请求）
  - 异步工厂 `create(publicKeysB64)`，一次性握手（SendPort 交换）
  - `verify(dir, {Duration? timeout}) → Future<VerifyResult>` API，默认超时 **15s**（可入参覆盖）
  - **健壮性（纵深防御三层，已加固）**：旧实现任一 worker 抛未捕获异常就 `Isolate.exit()` 杀掉整个 isolate，导致所有 in-flight `verify()` 的 Future 永不完成、调用方永久 hang（软 brick），且无任何超时。现改为：
    1. **worker 自愈**：单包验签异常（`verifyDir` 抛错/坏包/缺文件）只判该包 `failure`，**不杀 isolate**，其他请求继续正常验签（`worker()` 内 try/catch 包裹，循环不退出）。
    2. **每条请求自带超时**：`verify()` 为每次请求挂一个 `Timer`，无响应即在超时后以 `VerifyResult.failure('verify timeout ...')` 完成，调用方据此拒绝该 bundle 并回退内置，绝不 hang。
    3. **崩溃看门狗**：主侧 `Isolate.addOnExitListener` 监听 isolate 意外退出（OOM / 不可捕获崩溃）；触发时把所有仍 pending 的 verify 以 `failure('verify isolate crashed unexpectedly')` 完成，并置 `_crashed`，后续 `verify` 立即以 failure 完成（不再发往死 isolate）。
  - **dispose 语义**：`dispose()` 走**抛错**语义（`completeError(StateError)`）而非 failure —— 调用方把 dispose 期间的中断视为"验签设施不可用、跳过"，**不会误判包被篡改而删除一个正常包**。dispose 体内对 `_pending` 的 reject 用 microtask 延迟一拍，避开与 response handler 的同步竞态（同 Completer 重复操作会 `Bad state`）；dispose 后到达的 response 由 `_disposed` 守卫直接丢弃。

- **`PackageService._reverifyOrDrop`**
  - 启动期调用，对 active + staged 全量跑 verifyDir
  - **fire-and-forget**：不阻塞 `init()`，后台 isolate 跑完后更新 in-memory 状态
  - 失败 → `deletePackage` + 从 in-memory 状态移除
  - 通过 `backgroundVerifyDone` getter 暴露给测试 await

- **`PackageService.verifyOnOpen`**
  - 打开 bundle 前的终态闸
  - 失败 → `deletePackage` + 返回 null（调用方兜底 builtin）
  - 关键：**JS 在 await 返回前不执行**（与"加载后异步检测"区分）
  - 指纹短路：先算「验签文件清单」的 `mtime:size` 指纹，命中上次验签通过的记录则跳过 isolate 重验

- **验签文件清单的单一数据源**：`manifest.json` / `manifest.sig` 文件名与 `.qjc` 排除判定统一定义在 `BundleVerifier` 的静态常量（`manifestFileName` / `manifestSigFileName` / `isVerificationExcluded`）。`BundleVerifier._verifyDirImpl`（验签）与 `PackageService._computeVerifyFingerprint`（指纹）都从这里取，禁止在别处散落硬编码文件名 —— 新增/调整协议文件名只改这一处。

- **`Offline.promoteAndGetRoot`**
  - 在返回 dir 给引擎前调 `verifyOnOpen`
  - 失败 → 兜底 `_ensureBuiltinActive` + 重新 verify
  - 引擎拿到的 dir 一定经过完整验签

- **`RemotePackagesVerifier`**（[remote_packages_verifier.dart](../fuickjs_flutter/lib/offline/domain/services/remote_packages_verifier.dart)）
  - 验 `latest.json` 的 Ed25519 签名（canonical-JSON）
  - 失败 → 回落内置包（不破坏冷启动）
  - **当前未启用**：`Offline._fetchRemotePackages` 不调用此 class；class 保留供未来启用

- **`Offline._fetchRemotePackages` / `_loadCachedRemotePackages`**
  - `offlinePackagesGetter` 返回非 null → 解析 + 落盘 `latest.json` + `setRemotePackages`
  - 返回 null → `_loadCachedRemotePackages`：读上次落盘的 `latest.json` 缓存（非空则用），否则兜底 `internalPackages`；随后照常走 sync
  - 意义：网络抖动（返回 null）不误删上次已 active 的远程包，且保留强制更新判定与内置包后台预解压能力

### 17.2 其他模块

- **P0–P3（Flutter offline 模块）**：`Package`/`PackageRegistry`/`BundleManifest`、`BundleVerifier`（Ed25519 + 逐代码文件 SHA-256）、`FileStorage`（staging/registry/`assets/js`/内置 zip）、`PackageRepository`、`DownloadService`（整包 SHA-256 + `.tmp` rename + staging 解压 + 验签 + minAppVersion + 原子提升）、`PackageService`（状态机 + `reuseLocalAsStaged` + staged 生效前校验线上最新/内置豁免）、`SyncService`（minAppVersion）、`CleanService`（引用集 GC + 低磁盘驱逐）、`Offline` 编排（sync 时先查 retained 再下载；`promoteAndGetRoot`/懒解压内置/三重验签闸）。
- **引擎集成**：`FuickAppContext._loadSingleBundle`（fs 走 `evalBinaryFileFromPath` 零拷贝 + assets 回退 `rootBundle`）、`__FUICK_BUNDLE__` 注入。
- **P4（JS/TS）**：`node.ts toDsl()` 透明改写 Image 相对路径。
- **构建工具**：`fuickjs_demo/js/tools/bundle/{gen-keys.js,pack-bundle.js,sign-latest.js}` + npm `bundle:keys`/`bundle:pack`。
- **测试**：`test/offline/` 全绿（含 Node 打包 → Dart 验签的跨语言一致性 fixture，含 isolate 生命周期、并发验签、on-open 失败兜底）。
- **待接入**：在 App 启动处调用 `Offline.init(OfflineConfig(...))` 并配置 `signaturePublicKeysB64`/`appVersionGetter`，在 `assets/js` 放置 `bundles.json` 与内置 `<name>.zip`。
- **Demo 已接入**：见 §18。
- **P5（可选）代码加密**：已删除（仅签名+启动期+on-open 验签已足够，详见 commit log）。

## 18. Demo App 接入示例

`fuickjs_demo/app` 已完成接线，可作为生产接入参考。

### 18.1 启动初始化

`lib/offline_bootstrap.dart` 在 `main()` 中、`EngineInit.preload()` 之后调用：

```dart
await DemoOfflineBootstrap.init();
```

配置要点：

- `signaturePublicKeysB64`：从 demo app 的 `offline_bootstrap.dart` 内 `signingPubB64` 常量读取，map key 为 `demo-key`（与 zip 内 `manifest.keyId` 一致；多公钥时在代码里配完整公钥表）。**不再从 `assets/js/bundle_signing_pub.b64` 读取**（v2 改造，避免 assets 里多一个无意义文件）。
- `appVersionGetter`：与 `pubspec.yaml` version 对齐（当前 `1.0.0`）。
- `offlinePackagesGetter`：Demo 返回 `null`（仅内置包）；联调时改为请求 CDN 元数据接口。

### 18.2 内置资源布局

```
app/assets/js/
├── bundles.json                       # { packages: [...] } — UI + offline 共用
├── bundle.zip / taro-demo.zip / ...   # 各 bundle 内置 zip（验签 + 懒解压）
├── bundle.js / bundle.qjc             # 开发兜底（zip 缺失时回退 .js / 字节码版本不匹配时 .stale 隔离后回退）
└── ...
```

公钥位置：写在 `app/lib/offline_bootstrap.dart` 的 `signingPubB64` 常量（base64 32 字节）。
源文件在 `fuickjs_demo/js/tools/bundle/bundle_signing_pub.b64`（JS 端工具使用，不再拷贝到 app/assets）。

`bundles.json` 每个 package 含 offline 字段（`name`/`version`/`sha256`/`minAppVersion`）与 UI 字段（`label`/`initialRoute`）。

### 18.3 打包命令

```bash
cd fuickjs_demo/js
npm run build              # 编译 JS → app/assets/js/*.js
npm run bundle:keys        # 首次生成 Ed25519 密钥（私钥不入库）
npm run bundle:pack:all    # 批量打 zip + 刷新 bundles.json sha256
```

`pack-all.js` 会对 5 个 demo bundle 打 zip（优先 `.qjc`；若 `.qjc` 落后于 `.js` 则仅打 `.js`），`bundle` 包会附带 `js/assets/images/` 资源。

**本地图片测试页**：打开「示例」→ Demos → **BundleImg**（路由 `/demo/bundle_local_image`），验证 zip 解压后 `images/*.svg` 能否通过 `__FUICK_BUNDLE__.root` 加载。

### 18.4 引擎加载

`FuickAppPage` 已设 `useAotCode: true`，与 zip 内 `.qjc` 入口一致。打开任意 demo 时：

1. `Offline.promoteAndGetRoot(appName)` 懒解压内置 zip → 验签 → active
2. 注入 `globalThis.__FUICK_BUNDLE__`
3. `_loadSingleBundle` 从包目录加载 `.qjc`（peek 字节码版本后 C 层 fopen）

---

## 附录：页面级分包加载（评估方案，不建议实施）

> 状态：**方案（技术可行，但当前不建议实施 —— 见 §19.2）**。已归档，实施需先过 §19.3 的决策门槛。
> 适用范围：FuickJS 业务 bundle 的启动开销优化 —— 把「一个大包一次性 eval」改为「主包 + 页面 chunk 按需 eval」。
> 与主文档的关系：本附录是主文档的扩展评估。页面 chunk 作为普通文件放进既有 offline bundle zip，
> 跟主包同版本、同签名、同 zip 一起下发，签名/校验/回滚全部复用主文档的既有机制。
> 章节续接主文档编号（§19–§32）。路由侧的关联见 [router.md](./router.md)。

## 19. 结论先行

### 19.1 技术上可行，改动面很小

引擎与框架的全部前置能力都已就位，不需要动 C/native、不需要动 `hostConfig.ts`、不需要 React `Suspense`、不需要 JS 侧模块加载器。核心判断两条：

1. **把「拆分」和「分发」解耦。** 页面 chunk 作为**普通文件放进现有 offline bundle zip**，跟主包同版本、同签名、同 zip 一起下发。按需的只是 **eval**，不是 download。这样版本 skew 不可能发生、签名/校验/回滚全部免费复用 [bundle-delivery](./bundle-delivery.md) 的既有机制，整个问题从「分布式代码分发」退化为「本地懒执行」。
2. **把加载点放在 Dart→JS 的渲染边界上。** 进入页面 JS 代码的入口只有 `fuickjs.render` / `prewarmPage` 两个，且都由 Dart 发起。让 Dart 在 `invoke('fuickjs','render',...)` **之前**把 chunk eval 进去，JS 渲染链路（`page_render.ts` / `renderer.ts` / `PageContainer.ts`，即"修改需极其谨慎"的那几个文件）**零改动**。

预计改动量：JS ~60 行、Flutter ~120 行、构建工具 ~150 行。

### 19.2 但当前规模下收益偏小，不建议先做

**根因：AOT 字节码已经把大头吃掉了。**

启动的主要成本本来是「解析 1.6 MB JS 源码」（几百毫秒级）。但构建期 `qjsc -b` 已经把它换成了「反序列化 4.1 MB 字节码」——`JS_ReadObject` 是反序列化不是解析，量级低得多。**分包想省的那部分，AOT 已经省过一轮**，分包拿到的只是 `JS_ReadObject` 的增量。

还有一层：它优化的可能不是主项。按 [bundle-delivery §6.4](./bundle-delivery.md) 自己的记录，`promoteAndGetRoot` 首次的 on-open Ed25519 验签就是 **~100-200ms**。若 bundle eval 只有几十毫秒，分包省下的量在一个还含着 100-200ms 验签的 TTI 里基本看不出来——缓存验签结果的 ROI 更高。且 eval 跑在 worker isolate，代价是「转圈时间变长」而非「UI 卡顿」，紧迫性再降一档。

### 19.3 实施前的决策门槛

**动手前先测一个数字**，成本几乎为零（埋点都已存在）：

| 埋点 | 位置 | 看什么 |
| --- | --- | --- |
| `[Performance] load bundle cost` | `fuick_app_context.dart:160` | 主包 eval 绝对耗时 |
| `[Perf] page=... total=` | `page_render.ts:216` | 首屏 TTI，用于算 eval 占比 |

冷启动各跑一次，得到 **bundle eval 在 TTI 中的占比**：

- **eval < 50ms 或占比 < 15%** → 本方案归档，不要实施。
- **eval > 200ms 或占比 > 30%** → 从 §31 P0 开始。

### 19.4 什么条件下值得重新启动

满足任一条即重新评估：

1. **页面数量涨一个量级。** 1.6 MB 是 demo 规模；两百个页面的真实应用可能是 5-10 MB 源码 / 15-25 MB 字节码，`JS_ReadObject` 与 QuickJS 堆占用会从「几十毫秒」变成「几百毫秒 + 几十 MB」，届时收益是线性放大的。
2. **必须走 JSC 路径**（iOS 默认 `useJscOnIos = true`；demo 是手动设 `false` 才走 QuickJS 的）。JSC 无字节码格式，`evalBinaryFileFromPath` 直接抛 `UnsupportedError`，只能 eval 源码——那里 parse 是真成本，分包收益明显得多。
3. **包体积成为瓶颈。** 但注意本方案**不解决包体积**（§20），那是 Stage 2 的事，而 Stage 2 恰好是旧方案复杂度的来源。

## 20. 与旧方案的差异（为什么这版更简单）

旧方案（独立文件时代的分包设计）复杂度的来源，基本都出自「chunk 是独立可下发、可独立版本的产物」这个前提。一旦接受这个前提，就必须处理：chunk 独立版本协商、主包与 chunk 版本 skew、chunk 独立签名与校验、下载失败/超时/重试、加载中的错误 UI、JS 侧异步模块 runtime（进而牵出 Promise 化渲染 / Suspense）。

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

代价是**包体积不减**（整包还是一次下完）。这是有意的取舍：从现状看瓶颈在启动 eval 而不是下载（见 §29），而按需下载可以在完全相同的接缝上后置追加（§31 Stage 2），不需要现在为它付复杂度。

## 21. 现状盘点

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
| 一个 app 一个 QuickJS context，所有页面共享 | ⚠️ 决定了 React/框架实例必须唯一（见 §24.2） | `fuick_app_context.dart:122-133` |
| 代码分割 | ❌ 单 outfile，无 splitting；`Suspense` 在 hostConfig 里被显式 no-op | `esbuild.js:55-84`、`hostConfig.ts:235-240` |

**唯一真正缺失的是构建期分割 + 一个加载接缝。** 引擎侧一行 native 代码都不用改。

## 22. 总体架构

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

## 23. 构建产物与约定

### 23.1 目录布局

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

> **没有 `chunks.json`。** path → chunkId 的映射只存在于主包的路由桩里，是唯一事实来源，Dart 侧不持有副本（§25.1）。

### 23.2 chunk entry 生成

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
  metafile: true,        // 用于 §24.2 的重复输入检查
  plugins: [sharedExternals(SHARED)],
  // 不带主包的 banner（console/process 兜底已由主包装好）
}
```

一个 chunk 可以装多个页面（`N:1`），因为 chunk 粒度太细会把一次 eval 换成多次文件 IO。默认「一页一 chunk」，允许在配置里声明分组；Taro 的 `subPackages` 天然就是分组边界（§28.2）。

### 23.3 shared externals 插件

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

## 24. 正确性护栏

分包最容易出的两类事故，都必须在构建期机械拦住，不能靠约定。

### 24.1 路由桩必须自带 meta / guard

`NavigatorService.push` 在 JS 侧会**先**做 `Router.resolve(path)` + `runGuards`，**再**才让 Dart push 页面（`NavigatorService.ts:233`）。这一步发生时 chunk 还没加载，所以：

- `path` / `name` / `meta` / `beforeEnter` / `redirect` **必须留在主包的桩上**；
- 只有 `component` 允许在 chunk 里。

构建期校验：若某路由的 `beforeEnter` 定义在被拆出的页面文件里，直接构建失败并报出文件位置。否则表现是「跳转前守卫静默不执行」——一个鉴权漏洞级别的坑。

### 24.2 同一模块不得落进两个产物

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

## 25. JS 侧改造

三处，都在路由层，不碰渲染链路。

### 25.1 `RouteConfig` 加 `chunk`

```ts
// router/router.ts
export interface RouteConfig {
  path: string;
  component?: ComponentFactory;   // 桩上为空，chunk 加载后填入
  chunk?: string;                 // 新增：所属 chunk id；无则代码在主包
  // name / meta / beforeEnter / redirect 不变（§24.1 要求留在主包）
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

### 25.2 挂到全局

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

### 25.3 `doRenderAsync` 的防御分支

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

## 26. Flutter 侧改造

### 26.1 抽出可复用的「eval 一个代码单元」

`FuickAppContext` 现在的 `_loadFromPackageDir` / `_loadFromAssets` / `_evalJsAt` 已经包含了全部需要的逻辑（qjc 优先、BC_VERSION peek、`.stale` 隔离、`.js` 回退、包目录 vs assets 双来源）。把它按「相对路径」参数化即可复用，主包传 `bundle`，chunk 传 `chunks/<id>`：

```dart
/// 加载一个代码单元（主包或 chunk）。
/// relPath: 不含扩展名的相对路径，如 'bundle' / 'chunks/detail'
Future<void> evalCodeUnit(String relPath, {String? root}) { /* 由现有实现提炼 */ }
```

主包调用变成 `evalCodeUnit('bundle', root: _activeBundleRoot)`，行为与现在完全一致。

### 26.1.1 字节码 chunk 如何 eval

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

### 26.2 `ChunkLoader`

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

### 26.3 渲染入口改 async

```dart
// fuick_page_delegate.dart
Future<void> renderPage(int pageId, String path, Map<String, dynamic> params) async {
  await controller.chunkLoader.ensureForPath(path);
  controller.jsProxy.render(pageId, path, params);
}
```

`prewarmPage` 同样处理（`_prewarmCache` 的写入保持同步，只把 `jsProxy.render` 那一行推后到 chunk 就绪）。

调用方 `FuickPageView._checkAndRender` 是 `void`，改成 `unawaited(...)` 即可 —— **DSL 迟到本来就是既有支持的路径**：`rootNode == null` 时 `build()` 已经渲染 `CupertinoActivityIndicator`（`fuick_page_view.dart:204-214`），DSL 到达时 `_handleRenderDsl` → `setState`。所以 chunk 加载延迟不需要任何新 UI。

## 27. 时序

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

## 28. 兼容与降级

### 28.1 未分包时零影响

`resolveChunk` 只在路由桩带 `chunk` 字段时返回非 null。因此：

| 场景 | 行为 |
| --- | --- |
| 构建未开分包（dev / 旧包 / 回滚到分包前的版本） | 所有路由无 `chunk` → `resolveChunk` 恒返回 null → 与现状完全一致 |
| debug 模式（`debugBusinessCode` 走 WebSocket 整包注入） | 同上，不开分包 |
| 主包是新版但 chunk 文件缺失 | `evalCodeUnit` 抛错 → 日志 + `_inflight` 清理 → `doRenderAsync` 走 §25.3 的 loading 兜底，不崩 |
| 无 offline 包（`root == null`，走 `assets/js`） | chunk 从 `assets/js/chunks/<id>.js|.qjc` 读，与主包同一套双分支逻辑 |
| 回滚到旧版本 bundle | zip 是原子的，主包和 chunk 一起回滚，无需额外处理 |

「不开分包 = 走老路」这条让整个特性可以按 bundle 灰度，出问题构建侧一个开关即可回退。

### 28.2 Taro 侧

`plugin-platform-fuickjs` 现在已经在做「读 `app.config.ts` 的 `pages` → 生成 static import + `Router.register`」（`entry-template.ts:43-68`）。改成「生成桩 + 每个 chunk 一个 entry」是**同一个生成器加一个分支**，主包/chunk 两次 esbuild 复用同一份 `bundle()`。

顺带能补上一个现有缺口：插件目前**完全不识别** `subPackages`（`normalizeAppConfig` 只读 `pages`/`tabBar`/`window`），只在 `subPackages` 里声明的页面既不会被打进包也不会被注册。而 `subPackages` 语义上就是分包边界，正好一对一映射成 chunk 分组，等于顺手对齐了小程序的心智模型。

## 29. 收益与验收

现状实测（demo 主包）：`bundle.js` **1.6 MB** → `bundle.qjc` **4.1 MB**（字节码是源码 2.5×）。启动时这 4.1 MB 全量 eval，全部页面的闭包与常量进 QuickJS 堆。

收益方向：主包 eval 时间 ↓、启动期 QuickJS 堆 ↓、首屏 TTI ↓；代价是首次进入非常驻页多一次文件 IO + eval。**包体积不变。**

**收益上限受 §19.2 约束**：由于 AOT 已消除了 parse 成本，本方案能省的只是 `JS_ReadObject` 的增量，因此上限就是「主包 eval 耗时 × 被拆出去的代码占比」。§19.3 的门槛必须先过，否则不要进入实施。

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

## 30. 影响文件清单

**修改（JS/TS，`fuickjs_framework/fuickjs/`）**

- `src/router/router.ts` — `RouteConfig.chunk`、`loadedChunks`、`attachChunk`、`resolveChunk`，并挂进导出的 `Router` 对象。
- `src/runtime/runtime.ts` — `bindGlobals()` 增加 `fuickjs.resolveChunk` 与 `globalThis.__fuickDefineChunk`。
- `src/core/page_render.ts` — `doRenderAsync` 增加 §25.3 防御分支。
- `src/index.ts` — 若需对外暴露 chunk 相关类型。

**修改（Flutter，`fuickjs_framework/fuickjs_flutter/`）**

- `lib/core/engine/fuick_app_context.dart` — 提炼 `evalCodeUnit(relPath, root:)`；创建并持有 `ChunkLoader`。
- `lib/core/engine/chunk_loader.dart` — **新增**，§26.2。
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

- 本附录；`docs/README.md` 索引；`docs/router.md` 补 `chunk` 字段与 §24.1 约束。

## 31. 分期实施

| 阶段 | 内容 | 可验证结论 |
| --- | --- | --- |
| **P-1 决策门槛（必做）** | 按 §19.3 冷启动测 bundle eval 在 TTI 中的占比 | **不过门槛就归档**，不进 P0 |
| **P0 手工验证接缝** | 手写一个 chunk 文件 + 手写桩，跑通「Dart eval chunk → 填回 component → 渲染」 | 加载机制成立，风险出清 |
| **P1 运行时** | §25 JS 三处 + §26 Flutter `ChunkLoader`；未分包时零影响 | 主干可合，行为不变 |
| **P2 构建期** | `sharedExternals` 插件 + chunk entry 生成 + §24 两个校验 | demo 产出主包 + chunks，测 §29 指标 |
| **P3 offline 接通** | `pack-bundle.js` 把 chunks 计入 manifest；验签/回滚回归 | 分包包可下发 |
| **P4 Taro** | `entry-template.ts` 桩化 + `subPackages` → chunk 分组 | Taro 侧对齐，顺带补 subPackages |

**Stage 2（可选，不建议现在做）：按需下载。** 只有当包体积成为实测瓶颈时才做。接缝完全不变 —— `ChunkLoader` 里 `evalCodeUnit` 之前多一步「本地没有则下载 + 验签」。此时才需要付网络失败/超时/重试/错误 UI 的复杂度，也才需要处理 chunk 与主包的版本一致性（建议做法：chunk 作为 offline 的第二个 package，用主包版本号做强绑定，不匹配就整体不用）。

## 32. 明确不做

- **组件级 lazy / `Suspense`**：本方案粒度就是页面。`hostConfig.ts` 的 Suspense no-op 保持原样。
- **chunk 独立版本 / 独立签名链路**：chunk 与主包同 zip 原子发布（§20）。
- **JS 侧模块加载器 / `require` / 动态 `import()`**：`attachChunk` 一个回调就够了。
- **Dart 侧的 path 匹配实现**：统一走 JS 的 `Router.resolve`（§25.1），不做逻辑双写。
- **`chunks.json` 之类的映射文件**：映射只存在于主包路由桩。
- **按需下载**：见 Stage 2。

