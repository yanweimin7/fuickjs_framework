import 'package:source_maps/source_maps.dart';

/// Sourcemap 堆栈还原工具类。
///
/// 从 [ConsoleService] 提取，改为实例类以支持多 context / 多 isolate 场景。
/// 职责单一：给定一段 JS Error.stack 字符串，逐帧映射回原始源码位置。
class SourceMapResolver {
  final Mapping? _mapping;

  SourceMapResolver(Map<String, dynamic>? sourceMap)
      : _mapping = sourceMap != null ? parseJson(sourceMap) : null;

  bool get hasMapping => _mapping != null;

  /// 解析整个 Error.stack 字符串，逐帧映射回原始源码位置。
  /// 非 stack-frame 行（错误消息等）原样保留。
  String? resolveStack(String? stack) {
    if (stack == null || stack.isEmpty || _mapping == null) return stack;
    try {
      final buf = StringBuffer();
      for (final line in stack.split('\n')) {
        final resolved = _resolveFrame(line.trim());
        buf.writeln(resolved ?? line);
      }
      final result = buf.toString().trimRight();
      return result.isEmpty ? stack : result;
    } catch (_) {
      return stack;
    }
  }

  /// 解析单个堆栈帧。不匹配 `at ...` 模式时返回 null（原样保留该行）。
  String? _resolveFrame(String frame) {
    final match = _stackFrameRe.firstMatch(frame);
    if (match == null) return null;

    final line = int.tryParse(match.namedGroup('line') ?? '');
    final col = int.tryParse(match.namedGroup('col') ?? '1') ?? 1;
    if (line == null) return null;

    // sourcemap 用 0-based，stack frame 用 1-based
    final span = _mapping!.spanFor(line - 1, col - 1);
    if (span == null) return null;

    final funcPart = match.namedGroup('func');
    final funcName =
        (funcPart != null && funcPart.isNotEmpty) ? funcPart : null;

    final sourceUrl = span.start.sourceUrl;
    final source = sourceUrl != null
        ? (sourceUrl.path.isNotEmpty ? sourceUrl.path : sourceUrl.toString())
        : '<unknown>';

    // sourcemap 返回的是 0-based，+1 转回 1-based
    final origLine = span.start.line + 1;
    final origCol = span.start.column + 1;

    final prefix = funcName != null ? '    at $funcName (' : '    at ';
    final suffix = funcName != null ? ')' : '';
    return '$prefix$source:$origLine:$origCol$suffix';
  }

  /// 匹配 `at func (file:123:456)` 或 `at file:123:456`。
  static final _stackFrameRe = RegExp(
    r'at\s+(?:(?<func>.+?)\s+\()?'
    r'(?<file>[^\s:)]+):(?<line>\d+)(?::(?<col>\d+))?'
    r'\)?',
  );
}
