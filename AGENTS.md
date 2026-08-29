# AGENTS.md — FuickJS Framework

面向 AI 编码代理的仓库指南。本仓库是 **FuickJS** 框架本体：基于 **React + QuickJS + Flutter** 的跨平台动态化渲染框架——用 React/TypeScript 写 UI，在 Flutter 内嵌的 QuickJS 引擎中执行并产出 JSON DSL，Flutter 端解析 DSL 实时构建原生 Widget 树。

> 核心理念：**用 React 的开发体验，写 Flutter 的原生性能**。

---

## 仓库布局

Monorepo，按语言/平台拆分为三个包 + 工具 + 文档：

| 路径 | 说明 | 技术栈 |
| --- | --- | --- |
| `fuickjs/` | JS 框架层（React Reconciler + 运行时 + 服务 + polyfill + i18n + hooks） | TypeScript / React 19 / react-reconciler |
| `fuickjs_flutter/` | Flutter 框架层（DSL 解析、Widget 工厂、Native 服务、引擎管理、Bundle 下发） | Dart / Flutter |
| `fuickjs_dart/` | 纯 Dart 动态渲染方案（无 JS 引擎路径，dart2js 编译产出 DSL） | Dart |
| `tools/` | 开发工具集（sourcemap 还原脚本） | Node.js (ESM) |
| `docs/` | 框架设计/使用/审计文档（含 `introduction.md` 等 13 篇） | Markdown |

> 引擎层 `fuickjs_core`（QuickJS FFI）是当前仓库**外部**依赖（`fuickjs_flutter/pubspec.yaml` 通过 `path: ../../fuickjs_core` 引用），不要在本仓库内修改它。

---

## 构建 / 测试 / Lint 命令

每个包独立维护依赖，**修改哪个包就在哪个包内运行命令**。

### `fuickjs/` (JS)
```bash
cd fuickjs
npm install            # 首次安装
npm run build          # tsc 编译到 dist/
npm run lint           # eslint src
npm run lint:fix       # eslint src --fix
```

### `fuickjs_flutter/` (Dart/Flutter)
```bash
cd fuickjs_flutter
flutter pub get
flutter analyze        # 等价于 dart analyze
flutter test           # 运行 test/
```

### `fuickjs_dart/` (Dart)
```bash
cd fuickjs_dart
dart pub get
dart analyze
./build.sh             # dart compile js example/main.dart → example/bundle.js (+ 拷贝到 demo 资源)
```

### `tools/` (Node)
```bash
cd tools && npm install
node resolve-sourcemap.mjs <mapFile> <line> <column>   # 还原单个行列号
node resolve-sourcemap.mjs <mapFile> --stack stack.txt  # 还原完整 stack
```

---

## 关键架构（代理需理解后再改代码）

### 渲染链路（JS → Flutter）
1. Flutter 调 `render(pageId, path, params)` → `Router.match(path)` 找页面工厂。
2. 工厂执行 `React.createElement` → React Reconciler 调 `core/hostConfig.ts` 的 `appendChild/insertChild`。
3. `hostConfig` 创建 `core/node.ts` 的 `Node`，建立父子关系并注册事件回调到 `PageContainer` 回调表。
4. `root.commit()` → `Node.toDsl()` 递归序列化为 JSON DSL。
5. `PageContainer` 批量发送 `renderUI` + `patchOps` 到 Flutter（`WidgetParser` 解析为 Widget）。

### 增量更新
- 默认 `strategies/IncrementalStrategy.ts`：只记录本次 commit 的变更，合并同节点多次更新后批量下发。
- OpCode：`1` UPDATE / `2` INSERT / `3` REMOVE / `4` MOVE。
- DSL 缓存：节点 props/子节点变更标记 dirty，失效信号递归向上传播；透明节点（如 `FlutterProps`）自动穿透。

### 双向通信
- **Flutter → JS**：通过 `ctx.invoke('dispatchEvent', {pageId, nodeId, eventKey, payload})` 触发 JS 回调。
- **JS → Native**：`Fuick.expose('Name', obj)` 暴露对象供 `ctx.invoke` 主动调用；`NativeEvent.on/emit` 发布订阅。

### 引擎与平台差异（改动前务必注意）
- QuickJS 支持 `compile()` 运行时字节码编译与 ES Module（`registerModule`/`evalModule`）。
- iOS/macOS 默认 JSC 回退（`JscContext`）：**不支持字节码编译与 ES Module**，相关能力需 `UnsupportedError` 保护或仅 QuickJS 启用。
- 字节码与引擎 `BC_VERSION` 强绑定，升级 QuickJS 需重新编译。

---

## 代码约定

### 通用
- 文档与注释使用**中文**；代码标识符/API 使用**英文**。
- 保持现有目录结构：新增 widget 走 `fuickjs_flutter/lib/core/widgets/parsers/`，新增服务走 `fuickjs_flutter/lib/core/service/`，新增 JS 能力按 `fuickjs/src` 现有子目录（`core/ services/ ex/ polyfill/ hooks/ i18n/ runtime/ strategies/ utils/`）归类。
- 不要在代码里硬编码或日志打印密钥/签名/token；安全相关改动参考 `docs/audit-report.md` 与 `docs/bundle-delivery.md`。

### `fuickjs/` (TypeScript)
- 入口 `src/index.ts`，公开 API 从这里导出；新公共 API 需在此 re-export。
- 组件映射到 Flutter 的逻辑集中在 `src/widgets`（文档见 `docs/widgets.md`）。
- 浏览器标准 API 补丁放在 `src/ex/` 与 `src/polyfill/`，不要污染全局除非必要。
- 遵守 ESLint + Prettier 规则（`eslint.config.js`）。

### `fuickjs_flutter/` (Dart)
- 公开 API 统一从 `lib/fuickjs_flutter.dart` 导出，宿主与扩展包只应从此导入。
- 自定义 Widget 继承 `WidgetParser`，自定义服务继承 `BaseFuickService` 并通过 `NativeServiceManager().registerService` 注册。
- 遵守 `analysis_options.yaml`（flutter_lints）。
- 新增 widget parser 时，在 `widget_factory.dart` 注册并在 `docs/widgets.md` 登记。

### `fuickjs_dart/` (Dart)
- `lib/src/widgets/` 提供与 Flutter 对应的组件 API；`lib/src/core/` 是 reconciler/node/router 核心。
- 通过 `dart compile js` 产出 DSL，无需 Flutter/JS 引擎。

---

## 强制规则：文档同步

> **任何代码修改或新增都【必须】同步更新 `docs/` 下相关文档。**

这是本仓库最强的约定（见 `docs/README.md`「开发规范」）。涉及以下改动时，务必一并更新对应文档：

- 新增/修改/删除 Flutter Widget → `docs/widgets.md`
- 新增/修改服务或浏览器 API → `docs/services.md`
- 路由能力变更 → `docs/router.md`
- 多语言变更 → `docs/i18n.md`
- FlutterProps 映射变更 → `docs/flutter-props.md`
- Bundle 下发/验签变更 → `docs/bundle-delivery.md`
- 二进制协议变更 → `docs/binary-protocol-v2.md`
- 架构/性能/安全变更 → `docs/introduction.md` / `docs/audit-report.md`

如改动影响架构图或快速上手示例，同步更新 `docs/introduction.md` 与 `docs/README.md`。

---

## 提交约定

- 参考 `git log` 风格：使用 Conventional Commits 中文/英文混合，范围标注包名，例如：
  - `feat(framework): ...`、`fix(flutter): ...`、`chore(framework): ...`
- 提交信息说明「+ 文档更新」之类的影响，尤其是文档同步改动。
- **不要**提交密钥、`.qjc` 字节码、`.map` 源映射（`.map` 应仅存构建服务器）。
- 不要主动 `git commit` / `git push`，除非被明确要求。

---

## 常见任务速查

- **加一个新 Flutter Widget**：在 `fuickjs_flutter/lib/core/widgets/parsers/` 加 `*_parser.dart` → 在 `widget_factory.dart` 注册 → 在 `fuickjs/src/widgets` 加对应 React 组件 → 更新 `docs/widgets.md`。
- **加一个 Native 服务**：在 `fuickjs_flutter/lib/core/service/` 加 `*_service.dart`（继承 `BaseFuickService`）→ `NativeServiceManager().registerService` → 如需 JS 侧 API，在 `fuickjs/src/services` 加对应封装 → 更新 `docs/services.md`。
- **还原线上 JS 错误堆栈**：用 `tools/resolve-sourcemap.mjs`，注意 QuickJS 内部 bundle 名为 `input.js`，查询前需替换为 `bundle.js`。
- **本地字节码编译验证**：用 `IQuickJsContext.compile()`（仅 QuickJS 引擎），见 `docs/README.md` §7。
- **了解完整能力清单**：先读 `docs/introduction.md` → `docs/README.md` 按角色选读路线。
