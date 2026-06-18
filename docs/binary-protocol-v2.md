# 二进制协议 v2（varint + 字符串表）技术方案

> 适用范围：JS（QuickJS）与 Dart 之间通过 FFI 传输 DSL / 任意结构化数据的序列化层。
> 涉及文件：`fuickjs_engine/src/main/jni/quickjs_ffi.c`（C 编解码）、
> `fuickjs_core/lib/core/quickjs_ffi.dart`（Dart 编解码）、
> `fuickjs_engine/src/main/jni/quickjs_ffi_public.h`（导出声明）。

---

## 1. 背景与定位

### 1.1 数据通路

FuickJS 的渲染链路里，DSL 在 JS 与 Dart 之间双向流动，序列化层位于 FFI 边界：

```
JS 对象 ──编码──► 字节缓冲(QjsResult.data) ──FFI──► 字节缓冲 ──解码──► Dart 对象     (JS → Dart，renderUI 热路径)
Dart 对象 ──编码──► 字节缓冲(QjsResult.data) ──FFI──► 字节缓冲 ──解码──► JS 对象     (Dart → JS，回调入参)
```

因此一套完整协议有 **四个端点**，v2 全部覆盖：

| 方向 | 编码端 | 解码端 |
|---|---|---|
| JS → Dart | C `js_value_to_binary_v2` | Dart `_BinaryReader._readV2` |
| Dart → JS | Dart `_BinaryWriter._writeV2` | C `binary_to_js_value_v2` |

序列化层只负责「结构 + 基础类型」。`BigInt / DateTime / Uint8List / Set` 等扩展类型在
进入序列化层前，已由 `_encodeForTransfer` 转成 `{__qjs_type__, __qjs_value__}` 的普通
Map（解码后由 `_decodeFromTransfer` 还原）。对 v2 而言它们就是普通 Map，无需特殊处理。

### 1.2 与既有优化的关系

v2 是序列化层的独立改进，与下述两项优化正交、可叠加：

- **DSL 解码快速路径**：`renderUI / patchUI / patchOps` 跳过 `_decodeFromTransfer` 的整树二次遍历。
- **字符串零拷贝解码**：`_BinaryReader` 用 `Utf8Decoder.convert(buf, start, end)` 直接读片段。

---

## 2. v1 的问题与改进动机

v1 是「tag(1B) + 定长负载」的朴素 TLV：整数固定 8B、字符串/列表/Map 的长度前缀固定 4B、
Map 的键名每次都写完整字符串。对典型 DSL（海量小整数、键名与类型字符串高度重复）极不经济。

以单个节点 `{"id":1,"type":"Text"}` 为例，v1 编码 **39 字节**：

| 片段 | 编码 | 字节 |
|---|---|---|
| MAP 头 | tag(1) + u32 count(4) | 5 |
| 键 `"id"` | tag(1) + u32 len(4) + `id`(2) | 7 |
| 值 `1` | tag(1) + int64(8) | 9 |
| 键 `"type"` | tag(1) + u32 len(4) + `type`(4) | 9 |
| 值 `"Text"` | tag(1) + u32 len(4) + `Text`(4) | 9 |

两个痛点：

1. **定长整数**：DSL 里 `id / width / height / flex` 几乎都 < 256，却各占 8 字节。
2. **重复字符串**：`id / type / props / children` 等键名、`Text / Column` 等类型值，每个节点重复写全。

v2 用 **变长整数** 解决第 1 点，用 **流式字符串表** 解决第 2 点。

---

## 3. 设计目标与非目标

**目标**
- 显著降低典型 DSL 的字节体积，且编解码更快（同进程 FFI 下 CPU 是瓶颈，不是带宽）。
- 与 v1 完全隔离、可一键回退（开关），不破坏既有 v1 行为。
- C / Dart 双向四端点语义严格一致。
- 实现简单、零外部依赖。

**非目标**
- 不追求跨机器 / 跨字节序的可移植格式（同进程传输，沿用 host endian）。
- 不做 schema / 版本协商（格式一致性由全局开关在两侧同步保证，见 §7）。
- 不压缩 float（DSL 中占比低，varint 对随机尾数无收益）。

---

## 4. 基础编码原语

### 4.1 无符号变长整数 uvarint（LEB128）

**一句话**：用「能省则省」的方式存非负整数——小的数只占 1 字节，大的数才用更多字节。
（v1 不管多小都固定 4 字节，这就是浪费的来源。）

**规则**：把整数按二进制 **每 7 位切一组**，每组放进 1 个字节的低 7 位；字节的最高位（第 8 位）当
「还有没有下一字节」的旗子——`1` 表示后面还有，`0` 表示到此结束。低位组放在前面（小端）。

所以：

- `0 ~ 127`（7 位以内）→ **1 字节**
- `128 ~ 16383`（14 位以内）→ **2 字节**
- 以此类推，每多 7 位多 1 字节。

DSL 里的长度、计数、字符串表序号绝大多数 < 128，所以基本都是 1 字节。

**示例一：值 5（最常见情况）**

```
5 = 0000101，只有 7 位，一个字节装得下，最高位旗子=0（结束）
→ 0x05   （1 字节）
```

**示例二：值 300（需要 2 字节）**

```
第 1 步：写成二进制         300 = 1 0010 1100   （9 位，1 个字节装不下）
第 2 步：从低位每 7 位切组   低7位 = 0101100      高位 = 10
第 3 步：低位组在前，逐字节拼装
        字节1 = [旗子1][0101100] = 1010_1100 = 0xAC   （旗子=1：后面还有）
        字节2 = [旗子0][0000010] = 0000_0010 = 0x02   （旗子=0：结束）
→ 0xAC 0x02   （2 字节）

解码时反过来：去掉每字节最高位旗子，把剩下的 7 位按「先到的在低位」拼回去：
        0000010 << 7 | 0101100 = 1_0010_1100 = 300 ✓
```

> 对照：v1 存这个 300 要固定 4 字节，v2 只要 2 字节；存常见的小整数 v2 只要 1 字节。

### 4.2 有符号变长整数 svarint（zigzag + LEB128）

**问题**：uvarint 只能存非负数。如果直接拿它存负数会怎样？负数在二进制里是「全 1 开头」的大数
（如 `-1` = `1111...1111`），uvarint 会把它当成超大正数，足足占满 10 字节——比定长还糟。

**zigzag 的妙处**：先做一次映射，把「绝对值小的数」（不管正负）都变成「小的非负数」，再交给 uvarint。
映射方式是正负交错：

```
原值:  0   -1    1   -2    2   -3    3  ...
映射:  0    1    2    3    4    5    6  ...
```

这样 `-1` 不再是巨大的数，而是 `1`（1 字节）；`2` 是 `4`（1 字节）。位运算实现：

```
编码: zz = (v << 1) ^ (v >> 63)     // 末位放符号；v>>63 是算术右移：正数得 0、负数得全 1
解码: v  = (zz >>> 1) ^ -(zz & 1)    // 逻辑右移还原；zz&1 取出符号
```

得到的 `zz` 一定是非负数，再用 §4.1 的 uvarint 写出去即可。

**示例**：值 `-2`

```
编码: zz = (-2 << 1) ^ (-2 >> 63) = (-4) ^ (-1) = 3   → uvarint(3) = 0x03   （1 字节）
解码: (3 >>> 1) ^ -(3 & 1) = 1 ^ -1 = -2 ✓
```

用于：所有整数（INT tag）。`|v| < 64` → 1 字节，`|v| < 8192` → 2 字节——覆盖了 DSL 里绝大多数
`id / width / height / flex` 等小整数（v1 一律 8 字节）。

> 整数位宽：JS 侧 `JS_TAG_INT` 为 32 位，更大的数在 QuickJS 中已是 float64（走 FLOAT64）；
> Dart 侧 `writeOut` 将任意 Dart int 以 64 位写入。zigzag 基于 int64，全 64 位安全。

---

## 5. 格式定义

### 5.1 Tag 一览

每个值以 1 字节 tag 起始（v2 复用 0–6 的常量号，新增 7）：

| tag | 名称 | 负载布局 |
|---|---|---|
| 0 | NULL | 无（`null` / `undefined`） |
| 1 | BOOL | 1 字节：`0x00` / `0x01` |
| 2 | INT | svarint（zigzag + LEB128） |
| 3 | FLOAT64 | 8 字节 IEEE-754，host endian |
| 4 | STRING（定义） | uvarint 长度 + UTF-8 字节；**写入字符串表，分配下一个序号** |
| 5 | LIST | uvarint 元素个数 + 各元素（递归） |
| 6 | MAP | uvarint 键值对数 +（键, 值）...，键按字符串编码（STRING / STRING_REF） |
| 7 | STRING_REF | uvarint 序号，复用此前 STRING 定义过的字符串 |

v2 与 v1 的差异仅在「长度/计数前缀 4B→uvarint」「INT 8B→svarint」「字符串去重(STRING_REF)」。
NULL / BOOL / FLOAT64 的布局与 v1 相同。

### 5.2 流式字符串表

核心机制：编解码两端各维护一个「按出现顺序增长」的字符串表，无需任何显式表头。

- **编码端**（`Map<String,int>` / C 开放寻址哈希）：写字符串时查表——
  - 未见过 → 写 `STRING`（tag 4）+ 长度 + 字节，并把它登记为「下一个序号」（0,1,2,...）。
  - 已见过 → 写 `STRING_REF`（tag 7）+ 该序号。
- **解码端**（`List<String>` / C 的 `JSValue[]`）：
  - 读到 `STRING` → 解出字符串并 **追加** 到表尾（自然得到与编码端一致的序号）。
  - 读到 `STRING_REF idx` → 直接返回 `table[idx]`。

键名与字符串值 **统一** 参与同一张表（键重复率最高，收益最大）。

> **一致性的关键**：编码端「分配序号的顺序」与解码端「读到 STRING 的顺序」都等于同一棵树的
> **前序深度优先遍历**顺序（Map 内按 键→值、属性枚举序；List 内按下标序）。两端遍历同构，
> 故序号天然对齐，无需在流中携带字符串表。

**建表过程示例**

以一个含两个同构节点的列表为例（DSL 的典型形态）：

```json
[
  { "type": "Text", "color": "#FF8800" },
  { "type": "Text", "color": "#FF8800" }
]
```

编码端按前序遍历逐个处理字符串，**首次出现就入表并写 STRING，再次出现写 STRING_REF**：

| 遍历到的字符串 | 查表结果 | 动作 | 表的状态（序号→串） |
|---|---|---|---|
| `"type"`（节点1 键） | 未见过 | 写 `STRING "type"` | `{0:"type"}` |
| `"Text"`（节点1 值） | 未见过 | 写 `STRING "Text"` | `{0:"type", 1:"Text"}` |
| `"color"`（节点1 键） | 未见过 | 写 `STRING "color"` | `{0:"type", 1:"Text", 2:"color"}` |
| `"#FF8800"`（节点1 值） | 未见过 | 写 `STRING "#FF8800"` | `{..., 3:"#FF8800"}` |
| `"type"`（节点2 键） | 命中序号 0 | 写 `STRING_REF 0` | 不变 |
| `"Text"`（节点2 值） | 命中序号 1 | 写 `STRING_REF 1` | 不变 |
| `"color"`（节点2 键） | 命中序号 2 | 写 `STRING_REF 2` | 不变 |
| `"#FF8800"`（节点2 值） | 命中序号 3 | 写 `STRING_REF 3` | 不变 |

可见 **节点2 的四个字符串全部退化成 2 字节的回引**（tag + 1 字节序号），无论 `"#FF8800"`
原本多长。节点越多、结构越同构，省得越多。

解码端镜像这一过程：读到 `STRING` 就把解出的串 **追加到表尾**（于是也得到 0,1,2,3），
读到 `STRING_REF idx` 就直接取 `表[idx]`——两端永远在同一行同步，所以流里不需要任何表头。

**字符串表不随流传递，而是解码时动态重建**

这是「流式」字符串表与普通字符串表的本质区别，容易误解，单独强调：

- **流里没有独立的「表区块/表头」**。传过去的字节只有两类与字符串相关：首次出现的
  `STRING`（内联长度 + UTF-8 内容）、重复出现的 `STRING_REF`（一个序号）。
  即字符串的**内容随流传递且只传一次**，而字符串表这个**数据结构本身从不传输**。
- **解码端的表是边读边长出来的**：起手是一张空表，每读到一个 `STRING` 就把解出的串追加进去，
  从而即时获得 0,1,2,… 的序号；读到 `STRING_REF idx` 时直接取已存在的 `表[idx]`。
- **永远不会引用到不存在的序号**：编码端遵循「先定义后引用」——一个串必然先以 `STRING` 出现过，
  之后才可能被 `STRING_REF` 引用。解码端按相同顺序读，遇到 REF 时它需要的那一项早已入表。

打个比方：编解码两端各拿一张白纸，按**完全相同的顺序**往下抄词；谁先抄到一个新词就编下一个号，
重复的词只写「第几号」。两张纸从不交换，但因为抄写顺序一样，号码永远对得上。
（编码端表见 `EncStrTable` / `_BinaryWriter._strIndex`，解码端表见 `DecStrTable` /
`_BinaryReader._strTable`，均为单条消息生命周期的临时结构。）

### 5.3 字节级示例

对象 `{"id":1,"type":"Text"}`，v2 编码 **20 字节**（对比 v1 的 39 字节）：

```
06                 MAP
02                 uvarint 2（键值对数）
04 02 69 64        STRING len=2 "id"            → 表[0]="id"
02 02              INT svarint(1)=2
04 04 74 79 70 65  STRING len=4 "type"          → 表[1]="type"
04 04 54 65 78 74  STRING len=4 "Text"          → 表[2]="Text"
```

合计 2 + 4 + 2 + 6 + 6 = 20 字节。

更能体现字符串表威力的是 **同一条消息内的第二个同构节点** `{"id":2,"type":"Text"}`，
由于 `id / type / Text` 均已入表，整节点仅 **10 字节**：

```
06           MAP
02           uvarint 2
07 00        STRING_REF 0   ("id")
02 04        INT svarint(2)=4
07 01        STRING_REF 1   ("type")
07 02        STRING_REF 2   ("Text")
```

体积随重复结构线性摊薄——这正是 DSL（成百上千个同构节点）的典型形态。

---

## 6. 编解码算法

### 6.1 编码（伪代码，两端同构）

```
encode(value, buf, strtab):
  switch type(value):
    null:    write_u8(NULL)
    bool:    write_u8(BOOL); write_u8(value ? 1 : 0)
    int:     write_u8(INT);  write_svarint(value)
    double:  write_u8(FLOAT64); write_f64(value)
    string:  write_string(value, buf, strtab)
    list:    write_u8(LIST); write_uvarint(len); for e in value: encode(e, ...)
    map:     write_u8(MAP);  write_uvarint(len)
             for (k, v) in value: write_string(k, ...); encode(v, ...)

write_string(s, buf, strtab):
  idx, is_new = strtab.intern(s)
  if is_new: write_u8(STRING); write_uvarint(len(s)); write_bytes(utf8(s))
  else:      write_u8(STRING_REF); write_uvarint(idx)
```

C 编码端字符串表 `EncStrTable` 用 **开放寻址哈希**（FNV-1a，负载因子 3/4 翻倍 rehash，
槽位存 `index+1`，0 表示空）实现 O(1) 摊还查重；顺序数组保存原始字节供 rehash 重算。
Dart 端直接用有序 `Map<String,int>`（`map.length` 即下一个序号）。

### 6.2 解码（伪代码）

```
decode(buf, strtab):
  tag = read_u8()
  switch tag:
    NULL:       return null
    BOOL:       return read_u8() != 0
    INT:        return read_svarint()
    FLOAT64:    return read_f64()
    STRING:     s = utf8(read_bytes(read_uvarint())); strtab.append(s); return s
    STRING_REF: return strtab[read_uvarint()]
    LIST:       n = read_uvarint(); return [decode(...) for _ in n]
    MAP:        n = read_uvarint(); obj = {}; repeat n: k=decode(...); v=decode(...); obj[k]=v; return obj
```

解码端字符串表：Dart 为 `List<String>`；C 为 `DecStrTable`（保存 `JS_DupValue` 持有的 `JSValue`，
消息结束统一 `JS_FreeValue`）。

### 6.3 入口分流

- C 编码入口 `js_value_to_qjs_result`：`g_binary_codec_v2` 为真则建临时 `EncStrTable`，调用 v2，结束释放；否则走 v1。
- C 解码入口 `qjs_result_to_js_value`：同理建 `DecStrTable` 调 v2，否则 v1。
- Dart `convertQjsResultToDart` / `writeOut`：按 `_binaryCodecV2` 选择 `_BinaryReader(v2:)` / `_BinaryWriter(v2:)`。

字符串表 **以单条消息为生命周期**：每次顶层编码/解码新建、用完即弃，不跨消息复用。

---

## 7. 开关与一致性

v2 默认开启。**只能通过 Dart 侧统一切换**，它会同时设置 Dart 与 C 两侧：

```dart
ffi.setBinaryCodecV2(false); // 回退 v1 定长编码
ffi.setBinaryCodecV2(true);  // 恢复 v2（默认）
```

底层映射：

| 层 | 标志 / 接口 |
|---|---|
| Dart | `QuickJsFFI._binaryCodecV2`（默认 `true`）/ `setBinaryCodecV2(bool)` |
| C | `g_binary_codec_v2`（默认 `1`）/ 导出 `qjs_set_binary_codec_v2(int)` |

> **强一致约束**：编码端与解码端必须使用同一开关值。协议本身不带版本/魔数，
> 依赖「同进程内全局开关在两侧一致」来判别格式。单条消息的编码→传输→解码是同步完成的，
> 中途不会被切换，故安全。**切勿只改一侧**。

---

## 8. 兼容性与部署

v2 改动了 C 层（新增导出符号与 v2 编解码）。由于 Dart 侧默认 `_binaryCodecV2 = true`，
**各平台预编译原生库必须重新构建**，否则会出现两类问题：

1. **格式错配**：旧库仍按 v1 产出字节，Dart 按 v2 解析 → 数据损坏。
2. **缺符号**：旧库无 `qjs_set_binary_codec_v2`，首次调用 `setBinaryCodecV2` 时
   `lookupFunction` 抛 `ArgumentError`。

重新构建对应平台：

```bash
cd fuickjs_engine/src/main/jni
bash build_macos.sh    # macOS（含 flutter test 所需 dylib）
bash build_android.sh  # Android（需 NDK）
bash build_ios.sh      # iOS（需 Xcode）
bash build_ohos.sh     # OpenHarmony
```

> 若短期无法重建全部平台，可临时在初始化时 `ffi.setBinaryCodecV2(false)` 全局回退到 v1，
> 但前提是该平台原生库 **已包含** `qjs_set_binary_codec_v2` 符号（即仍需重建一次）。

JSC（iOS JavaScriptCore）通路独立使用 JSON，不受 v2 影响。

---

## 9. 性能

### 9.1 测量方法

基准脚本：`fuickjs_core/test/protocol_benchmark_test.dart`。在 JS 侧构造分支因子 4、
含小整数与短字符串的典型 DSL 树，通过 `eval('globalThis.dsl')` 触发 **完整往返**
（C 编码 + FFI + Dart 解码），各模式预热 10 次后计时。体积按各格式的确定性规则解析计算
（v2 体积模拟了相同遍历顺序的字符串表）。环境：macOS host，QuickJS 路径。

### 9.2 结果

#### 体积（确定性，各轮一致）

| 节点数 | 体积 v2 | 体积 v1 | 体积 json | v2/json | v2/v1 |
|---|---|---|---|---|---|
| ~50 | 2324 B (2.3 KB) | 8667 B (8.7 KB) | 5776 B (5.8 KB) | 0.40 | 0.27 |
| ~500 | 24094 B (24 KB) | 87143 B (87 KB) | 59363 B (59 KB) | 0.41 | 0.28 |
| ~2000 | 97890 B (98 KB) | 349894 B (350 KB) | 240528 B (241 KB) | 0.41 | 0.28 |

#### 耗时（5 轮实测，单位 µs/次）

每个数字为 **一次完整往返**（C 编码 + FFI + Dart 解码）的平均耗时。同一 macOS host 连续跑 5 轮，
轮间波动 < 5%。

**~50 节点（迭代 500 次/轮）**

| 模式 | R1 | R2 | R3 | R4 | R5 | **5 轮均值** |
|---|---|---|---|---|---|---|
| v2 | 78.9 | 76.6 | 77.1 | 75.6 | 77.7 | **77.2** |
| v1 | 90.7 | 86.4 | 87.3 | 87.9 | 88.3 | **88.1** |
| json | 195.5 | 189.3 | 190.2 | 189.5 | 192.2 | **191.3** |

**~500 节点（迭代 200 次/轮）**

| 模式 | R1 | R2 | R3 | R4 | R5 | **5 轮均值** |
|---|---|---|---|---|---|---|
| v2 | 560.2 | 546.0 | 547.4 | 569.2 | 553.9 | **555.3** |
| v1 | 725.5 | 693.0 | 732.6 | 703.7 | 750.4 | **721.0** |
| json | 1722.4 | 1719.0 | 1758.3 | 1694.7 | 1729.6 | **1724.8** |

**~2000 节点（迭代 100 次/轮）**

| 模式 | R1 | R2 | R3 | R4 | R5 | **5 轮均值** |
|---|---|---|---|---|---|---|
| v2 | 2327.3 | 2245.2 | 2198.3 | 2200.5 | 2213.4 | **2236.9** |
| v1 | 3296.1 | 3334.4 | 3213.5 | 3234.7 | 3378.1 | **3291.4** |
| json | 7072.3 | 7330.9 | 7463.5 | 7365.8 | 7445.6 | **7335.6** |

#### 汇总（5 轮均值）

| 节点数 | v2 均值 | v1 均值 | json 均值 | v2 比 json 快 | v2 比 v1 快 | v2 波动范围 |
|---|---|---|---|---|---|---|
| ~50 | 77.2 µs | 88.1 µs | 191.3 µs | **2.48×** | 1.14× | 75.6–78.9 |
| ~500 | 555.3 µs | 721.0 µs | 1724.8 µs | **3.11×** | 1.30× | 546.0–569.2 |
| ~2000 | 2236.9 µs | 3291.4 µs | 7335.6 µs | **3.28×** | 1.47× | 2198.3–2327.3 |

### 9.3 分析

- **体积**：v2 ≈ JSON 的 40%、v1 的 28%。整数 9B→1~2B、键名/重复字符串从「每次写全」降为 2 字节回引贡献最大。
- **耗时**：v2 比 JSON 快 **2.5~3.3×**（省去 `JS_JSONStringify` + `json.decode` 的文本解析与数字 reparse）；
  比 v1 快 **1.14~1.47×**，且 **节点越多优势越大**（字符串表去重减少了内存写入与 UTF-8 编解码量）。
- **稳定性**：5 轮实测 v2 各规模波动均在 ±2~5% 以内，结论可靠；体积比例随规模基本稳定，说明优化是结构性的而非常数项。

### 9.4 renderUI 端到端拆分（FFI 解码 + createNode + Widget 构建）

§9.2 只测了 `eval` 往返（纯 FFI 编解码）。真实 `renderUI` 还要走 Dart 侧 `createNode` 和
`WidgetFactory.buildFromNode`。基准脚本：
`fuickjs_flutter/test/render_ui_e2e_benchmark_test.dart`（3 轮均值，macOS host）。

链路：`dartCallNative('UI.renderUI')` → **FFI 解码** → **FuickNodeManager.createNode** → **buildFromNode**

| 节点 | 模式 | 总耗时 | decode | createNode | buildWidget | decode 占比 |
|---|---|---|---|---|---|---|
| ~50 | v2 | 94 µs | 27 µs | 33 µs | 34 µs | 29% |
| ~50 | v1 | 96 µs | 45 µs | 23 µs | 28 µs | 47% |
| ~2000 | v2 | **909 µs (0.91 ms)** | 612 µs | 257 µs | 41 µs | 67% |
| ~2000 | v1 | **1776 µs (1.78 ms)** | 1327 µs | 403 µs | 47 µs | 75% |
| ~2000 | json | 1510 µs (1.51 ms) | 1195 µs | 269 µs | 45 µs | 79% |

**2000 节点关键结论**：

- v2 整条 renderUI 链路比 v1 快 **1.95×**，绝对值省 **~0.87 ms**——和 §9.2 纯解码省 ~1 ms 同量级。
- **decode 是大头但非全部**：2000 节点时 decode 占 v2 总耗时 ~67%，createNode ~28%，buildWidget ~4%
  （测试 host 下 Widget 构建极轻；真机首屏还有 layout/paint，用户感知耗时远大于此）。
- **相对 v1 的 1 ms 优化主要落在 decode 段**（1327→612 µs），createNode/build 与协议无关，v2 帮不上忙。
- 因此：**协议 v2 值得做（体积 -72%、decode 快 2×），但若目标是缩短用户可见的首屏时间，更应优先
  增量 patch、减少整树 render、优化 Flutter 建树/布局**——协议层省下的 1 ms 在 16 ms 一帧里占比有限。

> 小负载（~50 节点）总耗时亚毫秒级，轮间波动大，不宜据此判断协议优劣；以 500+ 节点为准。

### 9.5 怎么读这些数据

| 对比 | 该关注什么 | 典型收益 |
|---|---|---|
| v2 vs JSON | 是否还在用 JSON 通路 | 耗时 2.5~3.3×，体积 ~60% |
| v2 vs v1 | 协议升级是否值得 | 耗时 1.5~2×（decode 段），体积 ~72% |
| 协议 vs 整链路 | 优化投入产出比 | decode 占 renderUI ~67%，整链路省 ~1 ms/2000 节点 |

---

## 10. 边界与已知限制

- **空字符串**：参与字符串表（首次 `STRING len=0`，后续 `STRING_REF`），语义一致。
- **键即字符串**：Map 的键复用同一张字符串表；C 端键 atom→cstring 失败时退化为写空字符串。
- **STRING_REF 越界**：解码端做边界校验，越界返回 `null`（C 返回 `JS_NULL`），不崩溃。
- **float 不压缩**：FLOAT64 固定 8 字节，host endian；跨字节序不可移植（同进程无影响）。
- **深递归无迭代回退**：v1 在 `depth>1024` 有迭代实现兜底；v2 仅递归。DSL 树通常很浅
  （2000 节点、分支 4 仅约 6 层），实际无忧；若未来出现极深嵌套需补迭代版本。
- **OOM 容错**：编码端分配失败返回 -1 上抛；解码端字符串表追加失败会放弃去重，
  极端 OOM 下可能影响后续 REF 对齐——这属于灾难路径，与既有实现的健壮性级别一致。

---

## 11. 实现索引

| 关注点 | 位置 |
|---|---|
| Tag 常量 / 开关 | C：`quickjs_ffi.c` `BINARY_TAG_*`、`BINARY_TAG_STRING_REF`、`g_binary_codec_v2` |
| varint 写 | C：`buffer_write_uvarint` / `buffer_write_svarint` |
| 编码字符串表 | C：`EncStrTable`、`enc_strtab_intern`、`write_string_v2` |
| v2 编码（JS→字节） | C：`js_value_to_binary_v2` |
| varint 读 | C：`read_uvarint` / `read_svarint` |
| 解码字符串表 | C：`DecStrTable`、`dec_strtab_add` |
| v2 解码（字节→JS） | C：`binary_to_js_value_v2` |
| 入口分流 | C：`js_value_to_qjs_result`、`qjs_result_to_js_value` |
| 导出声明 | `quickjs_ffi_public.h`：`qjs_set_binary_codec_v2` |
| Dart 开关 | `quickjs_ffi.dart`：`_binaryCodecV2`、`setBinaryCodecV2`、`_setBinaryCodecV2` |
| Dart 编码 | `_BinaryWriter._writeV2` / `_writeStringV2` / `_writeUvarint` / `_writeSvarint` |
| Dart 解码 | `_BinaryReader._readV2` / `_readUvarint` / `_readSvarint` |
| 解码耗时钩子（基准） | `jsobject.dart`：`JSObject.captureNativeDecodeTiming` / `lastNativeDecodeMicros` |

---

## 12. 测试

- 正确性：`fuickjs_core/test/quickjs_core_test.dart`
  - `binary codec v2 roundtrip (JS -> Dart)`：嵌套对象、负数、float、bool、null、重复键/值回引。
  - `binary codec v2 roundtrip (Dart -> JS -> Dart)`：覆盖 Dart 编码 + C 解码方向。
  - `binary codec v2 can be toggled off (v1 fallback)`：验证开关关闭后 v1 仍正确。
- 协议基准：`fuickjs_core/test/protocol_benchmark_test.dart`（v1 / v2 / json 纯 FFI 往返）。
- 端到端基准：`fuickjs_flutter/test/render_ui_e2e_benchmark_test.dart`（renderUI 链路拆分计时）。

---

## 13. 后续可演进方向

- **极深嵌套的迭代版 v2**（对齐 v1 的 `depth>1024` 兜底）。
- **小整数内联 tag**（把最常见的 0/1/小整数并入 tag 字节，进一步省 1 字节）。
- **跨消息共享字符串表**（高频 patch 场景对稳定键名可继续去重，但需引入会话状态与失效策略，复杂度上升）。
- **MOVE 增量操作码**（与本协议正交，属 IncrementalStrategy 层优化）。
