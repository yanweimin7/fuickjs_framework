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
| `Offline` `late` 静态单例无守卫                                  | init 前调用 / 中途失败抛错                  | 增加 `initialized` 守卫与安全访问               |
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
- **所有 `_registry` 修改操作通过 `_withRegistryLock` 互斥锁串行化**（`init`/`_runBackgroundVerify`/`applyReady`/`promoteStaged`/`reuseLocalAsStaged`/`deactivatePackages`/`verifyOnOpen`）。这解决了"后台验签 snapshot 写回覆盖 sync 修改"等竞态。读操作不参与锁（Dart 单线程，list 引用赋值原子）。
- **`preparePackage` 同包 in-flight 去重 + `promoteStaging` 锁内化**：首启时页面加载（`_ensureBuiltinActive`）与后台 sync（`_syncAndClean`）会对同一内置包并发调用 `preparePackage`。若各自跑完整流程，会在同一 staging 目录上交错 `_resetDir`/`_unzip`，导致 staging 半写。实现：`DownloadService._prepareInflight`（key: `versionShasumName`），并发调用共享同一个 in-flight Future 直接 join 结果。staging 写入（`_resetDir`/`_unzip`）在锁外，此去重是 staging 目录并发安全的唯一防线。`promoteStaging`（rename staging→packages + flag）已从 `preparePackage` 移到 `PackageService._doApplyReady` 的 `_withRegistryLock` 锁内执行，与 registry 入册原子化——消除"已落地未入册"窗口。
- **`cleanUnreferenced` 串行化到 init 阶段**：`CleanService.cleanUnreferenced` 扫描 packages/ 删不在 `registry.retained` 的孤儿目录。`readdir` 是流式扫描——扫描期间 `applyReady` 的 `promoteStaging` 刚 rename 的新目录会被后续读到，若此时 `retainedDirs` 用的是旧快照（不含新目录），会误删——引擎读到正在被删除的 `bundle.js`（SyntaxError），第二次打开自愈。**根治方案**：`cleanUnreferenced` 挪到 `Offline.init` 的 `_initialized = true` 之前同步执行。此时 `promoteAndGetRoot` 会等 `_initialized`，架构上不可能并发，不需要锁保护。之后 `_syncAndClean` 只做远程同步 + 下载缓存清理（不涉及 packages/）。

### 6.4 启动性能

- `Offline.init()` 自身：约 30-50ms（isolate 启动） + 10ms（registry 解析） = 约 50ms 内返回
- 后台验签：与 UI 渲染、引擎 init 并行，用户感知不到
- `promoteAndGetRoot` 首次：on-open 验签 ~100-200ms（与 loading skeleton 并行展示）

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
  → 注入 globalThis.__FUICK_BUNDLE__ = { name, root }  // eval 业务代码之前
  → ctx.evalBinaryFileFromPath / ctx.evalBinary / ctx.eval
  → isReady=true → 退出 loading，渲染首屏（root 已就绪，图片首帧正确）
```

### 10.2 `__FUICK_BUNDLE__` 与图片透明解析（核心机制）

**结论：不需要 `BundleScope`，统一用 `globalThis.__FUICK_BUNDLE__`。**

依据：每个 `FuickAppContext` 用唯一 `contextId` 创建独立 `JsContextDelegate`（独立 QuickJS context、独立 `globalThis`），因此 `__FUICK_BUNDLE__` **天然按 bundle 隔离**，无需 InheritedWidget 解决作用域。

图片加载**对开发者透明**，无 `resolveAsset` API：

```
引擎 eval 前注入 globalThis.__FUICK_BUNDLE__ = { name, root }
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

新增字段：`sha256`、`minAppVersion`、`state`；`integrity` getter 优先用 `sha256`。`fromJson/toJson/copyWith` 同步。

### 12.2 `OfflineConfig`（扩展）

新增：`appVersionGetter`（minAppVersion 比对）、`signaturePublicKeyB64`（可多把/按 keyId）、`retainVersions`（history 保留数，默认 3）。

### 12.3 `SyncResult`

`added` / `updated` / `removed` 三组列表。

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
- `offline/offline.dart` — 编排 + `initialized` 守卫；公开 `getActivePackageRoot/promoteAndGetRoot`。
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
  - 后台 isolate + 4 worker pool
  - 异步工厂 `create(publicKeysB64)`，一次性握手（SendPort 交换）
  - `verify(dir) → Future<VerifyResult>` API
  - dispose 用 microtask 延迟 reject pending（避开与 response handler 的同步竞态）
  - dispose 后到达的 response 直接丢弃（`_disposed` 守卫）

- **`PackageService._reverifyOrDrop`**
  - 启动期调用，对 active + staged 全量跑 verifyDir
  - **fire-and-forget**：不阻塞 `init()`，后台 isolate 跑完后更新 in-memory 状态
  - 失败 → `deletePackage` + 从 in-memory 状态移除
  - 通过 `backgroundVerifyDone` getter 暴露给测试 await

- **`PackageService.verifyOnOpen`**
  - 打开 bundle 前的终态闸
  - 失败 → `deletePackage` + 返回 null（调用方兜底 builtin）
  - 关键：**JS 在 await 返回前不执行**（与"加载后异步检测"区分）

- **`Offline.promoteAndGetRoot`**
  - 在返回 dir 给引擎前调 `verifyOnOpen`
  - 失败 → 兜底 `_ensureBuiltinActive` + 重新 verify
  - 引擎拿到的 dir 一定经过完整验签

- **`RemotePackagesVerifier`**（[remote_packages_verifier.dart](../fuickjs_flutter/lib/offline/domain/services/remote_packages_verifier.dart)）
  - 验 `latest.json` 的 Ed25519 签名（canonical-JSON）
  - 失败 → 回落内置包（不破坏冷启动）
  - **当前未启用**：`Offline._fetchRemotePackages` 不调用此 class；class 保留供未来启用

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
