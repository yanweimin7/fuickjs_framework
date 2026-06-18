# dart_qjs 集成二进制序列化协议

## 原则

以 dart_qjs（`/Users/wine.yan/work/github/dart_qjs-master`）为基底，**只移植 fuickjs 的 v2 二进制序列化协议**（varint + zigzag + 流式字符串表）。dart_qjs 现有的 JSRef 生命周期、单 channel dispatch、Future→Promise 直连、IsolateQjs 等设计全部不动。

协议格式细节与正确性证明见同目录 `binary-protocol-v2.md`，本文只讲**如何把它接进 dart_qjs 的真实数据通路**。

---

## 背景：先认清 dart_qjs 的数据通路

dart_qjs 里 **所有** JS↔Dart 的值转换都收敛到两个函数（`lib/src/wrapper.dart`）：

| 方向 | 函数 | 现状 |
|------|------|------|
| JS → Dart | `_jsToDart(ctx, val)` | 递归遍历：Array 逐元素 `jsGetProperty`、Object `jsGetOwnPropertyNames` + 逐属性 `jsGetProperty`，**O(N) 次 FFI** |
| Dart → JS | `_dartToJs(ctx, val)` | 递归构建：List/Map 逐项 `jsDefinePropertyValue`，**O(N) 次 FFI** |

这两个函数被以下所有路径复用（`lib/src/engine.dart`、`lib/src/object.dart`）：

```
evaluate() 返回值              → _jsToDart                       (engine.dart:171)
channel METHODCALL 入参         → _jsToDart (逐 arg)              (engine.dart:50)
channel METHODCALL 返回值       → _dartToJs                       (engine.dart:61)
_JSFunction.invoke 入参/返回    → _dartToJs / _jsToDart           (object.dart)
Promise resolve/reject 的值     → _jsToDart                       (wrapper.dart:191)
```

**关键结论**：fuickjs 的 DSL 渲染热路径是 JS 侧 `dartCallNative('UI.renderUI', dsl)`，在 dart_qjs 里它走的是 **channel METHODCALL 的入参转换**，即 `_jsToDart`（`engine.dart:50`）。

所以：

> 只要给 `_jsToDart` / `_dartToJs` 加一条二进制快速路径，**renderUI、回调入参、eval 返回值全部一次性提速**，无需新增任何公开 API，也无需改 `engine.dart` 的 channel 逻辑。

这正是上一版方案（新增 `evaluateBinary`）的根本错误：DSL 从不走 `eval` 返回值，那个旁路 API 接不到热路径。

---

## 核心设计：hook 双向枢纽 + 纯数据快速路径 + 自动回退

### 决策

1. **不新增 `evaluateBinary` / `toBinary` / `fromBinary` 公开 API。**
2. 在 `_jsToDart` / `_dartToJs` 内部加「先试二进制，不行就回退现有递归」的分流。
3. 二进制路径**只处理纯数据子树**（null / bool / int / double / string / Array / 普通 Object）。一旦遇到 dart_qjs 需要特殊语义的节点，**整棵树放弃二进制、回退到现有递归实现**，保证语义零变化。

### 哪些必须回退（不能走二进制）

`_jsToDart` / `_dartToJs` 现有逻辑里，下列节点带有二进制协议无法表达的语义，**必须触发回退**：

| 节点 | 现有语义 | 处理 |
|------|----------|------|
| function | → `_JSFunction`（持 JSRef，可回调） | C 检测到 `JS_IsFunction` → 报「不可序列化」→ 回退 |
| Promise | → Future | C 检测 `JS_IsPromise` → 回退 |
| ArrayBuffer | → `Uint8List` | C 检测 ArrayBuffer → 回退 |
| JS `Map`（非普通对象） | key 可为任意类型 | C 检测 `JS_IsMap` → 回退 |
| `_DartObject` 透传 | 还原原始 Dart 对象 | C 检测 DartObject classId → 回退 |
| Error | → `JSError` | C 检测 `JS_IsError` → 回退 |
| 循环引用 | `_jsToDart` 用 cache 处理 | C 深度上限/visited 检测到 → 回退 |
| Dart 侧 `Future`/`_JSObject`/`Function`/`Uint8List`（`_dartToJs` 方向） | 各有特殊构造 | Dart 侧预扫描命中 → 回退 |

DSL 树是纯数据、无环、无函数（回调在 fuickjs 侧是注册成 ID 由 `PageContainer` 持有，不跨边界传 JS function），因此 **renderUI 永远走快速路径**；含函数/Promise 的返回值自动走回退，能力不退化。

---

## 移植内容（只加这 3 样）

```
1. C 侧序列化（src/ffi.cpp，约 300~400 行，编码+解码+两套字符串表都要）
   jsToBinary    — JSValue 纯数据树 → 单次 buffer；遇不可序列化节点返回状态码让 Dart 回退
   jsFromBinary  — buffer → JSValue
   jsFreeBinary  — 释放 jsToBinary 的 buffer

2. Dart 侧 binary.dart（约 350 行，纯 Dart）
   BinaryReader / BinaryWriter（v2：varint + zigzag + 流式字符串表）
   从 fuickjs 的 quickjs_ffi.dart 的 _BinaryReader/_BinaryWriter 直接移植

3. wrapper.dart 两处 hook（每处约 15 行）
   _jsToDart 开头：试 jsToBinary，OK 则 BinaryReader 解码返回；状态码=回退则走原逻辑
   _dartToJs 开头：纯数据预判通过则 BinaryWriter 编码 + jsFromBinary；否则走原逻辑
```

### 数据流对比

```
现状 _jsToDart（保留为回退）:
  JSValue → 逐属性 jsGetProperty → O(N) 次 FFI → Dart 对象
  （含 function/promise/error/map/arraybuffer 时仍走这条）

新增快速路径:
  JSValue → C jsToBinary 递归遍历 → 单次 buffer（1 次 FFI）
  → Dart BinaryReader.read() 纯 Dart 解码 → Dart 对象
  （仅纯数据树；C 检测到杂质即返回状态码触发回退）
```

---

## 文件变更

| 文件 | 操作 | 内容 |
|------|------|------|
| `src/ffi.h` | 修改 | 加 `BinaryResult` struct + `jsToBinary`/`jsFromBinary`/`jsFreeBinary` 三个 `DLLEXPORT` |
| `src/ffi.cpp` | 修改 | 递归序列化/反序列化 + varint/zigzag + 编/解码字符串表 + 杂质检测 |
| `lib/src/binary.dart` | **新增** | `BinaryReader` / `BinaryWriter`（v2）+ `BinaryResult` FFI struct |
| `lib/src/ffi.dart` | 修改 | 3 个 `@Native` 绑定（沿用 `assetId: _qjsAssetId`） |
| `lib/src/wrapper.dart` | 修改 | `_jsToDart` / `_dartToJs` 各加一段快速路径分流 |
| `lib/dart_qjs.dart` | 修改 | `part 'src/binary.dart';` |
| `hook/build.dart` | 检查 | 确认 `ffi.cpp` 已纳入 native assets 编译（新增代码在同一文件，通常无需改） |

**不动：** `lib/src/engine.dart`、`lib/src/object.dart`、`lib/src/isolate.dart`。
（hook 只落在 `_jsToDart`/`_dartToJs`，channel、函数调用、Promise 全部自动复用。）

---

## C 侧接口（src/ffi.h / ffi.cpp）

dart_qjs 的 `JSValue *` 是堆上拷贝（`new JSValue(...)`，由 `jsFreeValue(ctx, ptr, free)` 释放），C 函数收 `JSValue *`。新接口对齐这一约定：

```c
typedef struct {
  uint8_t *data;     // jsToBinary 成功时的 buffer（malloc）
  int32_t  length;
  int32_t  status;   // 0=OK, 1=含不可序列化节点(回退), 2=OOM/错误
} BinaryResult;

// JSValue 纯数据树 → buffer。
// 遇 function/promise/arraybuffer/Map/DartObject/Error/超深 → 不写 buffer，status=1。
DLLEXPORT void jsToBinary(JSContext *ctx, JSValue *val, BinaryResult *out);

// buffer → JSValue（堆拷贝，调用方用 jsFreeValue 释放）。
DLLEXPORT JSValue *jsFromBinary(JSContext *ctx, const uint8_t *data, int32_t len);

// 释放 jsToBinary 写出的 data。
DLLEXPORT void jsFreeBinary(BinaryResult *out);
```

> `jsToBinary` 取 `JSValue *`（指针）以对齐 dart_qjs 既有 ABI；内部解引用为 `JSValue`，序列化期间不改变引用计数（只读遍历），无需 dup/free。
> 杂质检测靠 `JS_IsFunction` / `JS_IsPromise` / `JS_IsError` / `JS_GetArrayBuffer` / `JS_IsMap`（QuickJS 有对应 C API）/ `JS_GetOpaque(val, dartObjectClassId)` 判断 DartObject；任一命中即 `status=1` 提前返回。

### 编码格式（与 fuickjs v2 一致）

| Tag | 值 | 编码 |
|-----|----|------|
| NULL | 0 | 1 byte（`null` / `undefined`） |
| BOOL | 1 | 2 bytes |
| INT | 2 | tag + svarint(zigzag) |
| FLOAT64 | 3 | tag + 8 bytes（host endian） |
| STRING | 4 | tag + uvarint(len) + UTF-8，**入字符串表分配序号** |
| LIST | 5 | tag + uvarint(count) + N 个递归值 |
| MAP | 6 | tag + uvarint(count) + N 对 (string key + 递归 value) |
| STRING_REF | 7 | tag + uvarint(字符串表序号) |

字符串表为「流式」——不随流传表头，编解码两端按相同前序 DFS 顺序边遍历边建表，序号天然对齐（推导见 `binary-protocol-v2.md` §5.2）。

---

## Dart 侧接口（lib/src/binary.dart）

```dart
part of '../dart_qjs.dart';

const int kTagNull = 0, kTagBool = 1, kTagInt = 2, kTagFloat64 = 3,
          kTagString = 4, kTagList = 5, kTagMap = 6, kTagStringRef = 7;

final class BinaryResult extends Struct {
  external Pointer<Uint8> data;
  @Int32() external int length;
  @Int32() external int status; // 0=OK 1=fallback 2=error
}

class BinaryReader {
  BinaryReader(Uint8List bytes);
  dynamic read(); // → null/bool/int/double/String/List/Map
}

class BinaryWriter {
  void write(dynamic v);
  Uint8List takeBytes();
}
```

`BinaryReader` / `BinaryWriter` 直接从 `fuickjs_core/lib/core/quickjs_ffi.dart` 的 `_BinaryReader._readV2` / `_BinaryWriter._writeV2`（含 `_readUvarint/_readSvarint/_writeUvarint/_writeSvarint` 与字符串表）移植，仅去掉 v1 分支。

### wrapper.dart 的 hook（示意）

```dart
// _jsToDart 开头（cache 为空、即顶层入口时才试快速路径）
dynamic _jsToDart(Pointer<JSContext> ctx, Pointer<JSValue> val, {Map<int,dynamic>? cache}) {
  if (cache == null && _binaryCodec) {
    final out = _binaryResultPtr; // 复用一个常驻 Pointer<BinaryResult>
    jsToBinary(ctx, val, out);
    if (out.ref.status == 0) {
      final bytes = out.ref.data.asTypedList(out.ref.length);
      final copy = Uint8List.fromList(bytes); // 拷出后即可释放 C buffer
      jsFreeBinary(out);
      return BinaryReader(copy).read();
    }
    // status != 0：含杂质/出错，落到下面的原递归逻辑
  }
  // ...原有递归实现完全不变...
}
```

```dart
// _dartToJs 开头
Pointer<JSValue> _dartToJs(Pointer<JSContext> ctx, dynamic val, {Map<dynamic,Pointer<JSValue>>? cache}) {
  if (cache == null && _binaryCodec && _isPureData(val)) { // 预扫描：无 Future/_JSObject/Function/Uint8List/Error/环
    final bytes = (BinaryWriter()..write(val)).takeBytes();
    final p = malloc<Uint8>(bytes.length);
    p.asTypedList(bytes.length).setAll(0, bytes);
    final jsVal = jsFromBinary(ctx, p, bytes.length);
    malloc.free(p);
    return jsVal;
  }
  // ...原有递归实现完全不变...
}
```

开关 `_binaryCodec` 默认 `true`，提供 `FlutterQjs` 上的 setter 以便排障回退。

---

## 语义一致性（必须逐条对齐，否则静默 bug）

dart_qjs 的现有转换有几处细节，快速路径**必须复刻**，否则同一份数据走两条路结果不同：

1. **int / double 判定**：`_jsToDart`（`wrapper.dart:140-144`）对 float64 做了「`res.ceil()==res` 则转 int」。二进制 INT 来自 `JS_TAG_INT`，FLOAT64 来自其余 number。`BinaryReader` 读到 FLOAT64 后**必须套用同样的「整值 float → int」规则**，与回退路径保持一致。
2. **Map → `Map<String, dynamic>`**：普通对象的 key 经 `key.toString()`。`BinaryReader` 的 MAP key 已是 string，天然一致；但 JS `Map`（`jsIsMap`）key 可非 string，故 C 侧对 `JS_IsMap` 一律回退（见上表）。
3. **共享对象 / 环**：`_jsToDart` 用 `cache` 对「同一 JS 指针」返回**同一个** Dart 实例（DAG 去重 + 防环）。二进制路径会把共享子树**展开成多份**，且无法表达环。
   - 环：C 侧深度上限 + 命中即回退，安全。
   - DAG 共享被展开：对 DSL（树结构）无影响；作为**已知行为差异**记录，若上层依赖对象同一性需关闭开关。
4. **Uint8List**：`_dartToJs` 把 Dart `Uint8List` 建成 ArrayBuffer。二进制 7 个 tag 不含 bytes，故 `_isPureData` 预扫描遇 `Uint8List` 即判为非纯数据 → 回退。
5. **数字精度**：`jsNewInt64` 用 int64；svarint 基于 int64，全程无损。

---

## 内存与并发

- `jsToBinary` 的 `data` 由 C `malloc`，Dart 拷成 `Uint8List` 后立即 `jsFreeBinary`，无跨边界悬挂。
- `BinaryResult` 用**一个常驻 `Pointer<BinaryResult>`**（每个 isolate/runtime 一个）即可，不需要对象池——实测（`binary-protocol-v2.md` §9.4）单 struct 分配相对 decode 可忽略，池化是过度优化。
- `jsFromBinary` 返回 `JSValue *` 堆拷贝，沿用 `jsFreeValue` 释放，与其它 `@Native` 返回值一致。
- **IsolateQjs**：快速路径全程在持有 `ctx` 的 isolate 内完成，二进制字节不跨 isolate，与 dart_qjs 现有隔离模型兼容。

---

## 不移植的

| fuickjs 概念 | 理由 |
|-------------|------|
| `QjsResult` 通用桥接 struct（type/i64/f64/b/s） | dart_qjs 非二进制路径走 `Pointer<JSValue>` 直传；二进制路径只需 `BinaryResult`（data+length+status） |
| `QjsResultPool` / `QjsResultArrayPool` | 单 `BinaryResult` 常驻指针即可，无需分桶/数组池 |
| `_encodeForTransfer` / `_decodeFromTransfer`（BigInt/DateTime/Set 等扩展类型） | dart_qjs 无此层；这些类型在快速路径里直接判为非纯数据 → 回退递归，行为与现状一致。若未来要支持，再单独评估 |
| v1 定长编码 | 仅移植 v2 |
| 多引擎（JSC）后端 | dart_qjs 专注 QuickJS |
| `dartCallNative` 同步桥、`pendingResolvers` 队列 | dart_qjs channel + `jsNewPromiseCapability` 已覆盖 |

---

## 性能预期与必须自测

> ⚠️ 上一版直接挪用了 fuickjs 在 `QjsResult` 路径上的实测数字。dart_qjs 的 channel/`_jsToDart` 架构不同，**必须在 dart_qjs 上重新测**，不得照搬。

预期方向（待实测验证）：

- 纯数据 DSL 树的 JS→Dart：从 O(N) 次 `jsGetProperty` FFI 降为 1 次 `jsToBinary` + 纯 Dart 解码。N 越大收益越大。
- 体积：v2 ≈ JSON 的 40%、定长的 28%（结构性，见 `binary-protocol-v2.md` §9）。

基准脚本应覆盖：500 / 2000 节点 DSL 树，对比「现状递归 `_jsToDart`」与「二进制快速路径」的端到端往返耗时（含 channel METHODCALL 模拟）。

---

## 验证清单

1. `dart test`：dart_qjs 现有用例全绿（证明回退路径未被破坏）。
2. `BinaryReader/Writer` 往返：null / bool / int / double / 空串 / 长串 / 负数 / 空 List / 空 Map / 深层嵌套 / 重复键值（STRING_REF 去重）。
3. **双路一致性**：同一 JS 值分别走「快速路径」与「强制回退」，结果 `deepEquals`——重点验证 int/float 判定、key 顺序、嵌套。
4. **回退触发正确**：返回值含 function / Promise / ArrayBuffer / JS Map / Error / DartObject / 循环引用时，`status=1`，走递归且行为与改造前完全一致。
5. **热路径覆盖**：JS 侧 `dartCallNative('UI.renderUI', dsl)` 实测走的是快速路径（断言 `jsToBinary` 被调用且 `status=0`）。
6. **内存**：循环 N 次 renderUI 后无泄漏（dart_qjs 的 `jsFreeRuntime` 引用泄漏检测保持为空）。
7. 性能基准：500/2000 节点，快速路径 vs 回退路径耗时对比。

---

## 风险与缓解

| 风险 | 缓解 |
|------|------|
| 快速路径与回退路径语义漂移（尤其 int/float） | 验证清单 #3 强制双路 `deepEquals`，CI 常驻 |
| 杂质检测漏判导致 JSObject/函数被错误序列化 | C 侧采用「白名单」：只有 null/bool/number/string/array/普通 object 才编码，其余一律 `status=1` |
| DAG 共享对象被展开、环 | 环：C 深度上限回退；DAG：文档化差异，提供 `_binaryCodec` 开关 |
| native 库需重新构建（新增 3 个导出符号） | 同 fuickjs：各平台重编 `ffi.cpp`；缺符号时 `@Native` 首次调用即报错，易发现 |
