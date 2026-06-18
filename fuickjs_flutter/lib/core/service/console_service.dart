import 'package:source_maps/source_maps.dart';

import '../logger.dart';
import 'base_fuick_service.dart';

class ConsoleService extends BaseFuickService {
  /// Sourcemap mapping, set via [setSourceMap] before any JS code is evaluated.
  static Mapping? _mapping;

  /// 去重：同一 stack 不重复解析打印。
  static String? _lastResolvedStack;

  static void setSourceMap(Map<String, dynamic>? sourceMap) {
    _mapping = sourceMap != null ? parseJson(sourceMap) : null;
    _lastResolvedStack = null;
    if (_mapping != null) {
      logger.d('[ConsoleService] Sourcemap loaded');
    }
  }

  @override
  String get name => 'Console';

  ConsoleService() {
    registerMethod('console', (args) {
      final m = args is Map ? args : {};
      final level = m['level'] ?? 'log';
      final message = (m['message'] ?? '').toString();

      // 有 sourcemap 且消息包含堆栈帧时，解析并打印原始源码堆栈
      if (_mapping != null && _looksLikeStack(message)) {
        try {
          final resolved = _resolveStackTrace(message);
          // 去重：同一 stack 不重复打印
          _lastResolvedStack = resolved;
          logger.e('=== JS Error (错误堆栈) ===');
          logger.e(resolved);
          if (resolved.isEmpty) {
            logger.e('=== JS Error ===');
            logger.e('[JS] $message');
          }
          return null; // 跳过重复的 raw 日志
        } catch (e) {
          logger.e('[ConsoleService] Sourcemap resolve failed: $e');
        }
      }

      switch (level) {
        case 'error':
          logger.e('[JS] $message');
          break;
        case 'warn':
          logger.w('[JS] $message');
          break;
        case 'info':
          logger.i('[JS] $message');
          break;
        case 'debug':
          logger.d('[JS] $message');
          break;
        default:
          logger.i('[JS $level] $message');
      }
      return null;
    });
  }

  /// 解析整个 Error.stack 字符串，逐帧映射回原始源码位置。
  static String _resolveStackTrace(String stack) {
    final buf = StringBuffer();
    for (final line in stack.split('\n')) {
      final resolved = _resolveFrame(line.trim());
      buf.writeln(resolved ?? line);
    }
    return buf.toString().trimRight();
  }

  /// 解析单个堆栈帧。不包含 `    at ` 模式时返回 null。
  static String? _resolveFrame(String frame) {
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

  /// 匹配 `    at func (file:123:456)` 或 `    at file:123:456`。
  static final _stackFrameRe = RegExp(
    r'at\s+(?:(?<func>.+?)\s+\()?'
    r'(?<file>[^\s:)]+):(?<line>\d+)(?::(?<col>\d+))?'
    r'\)?',
  );

  static bool _looksLikeStack(String message) {
    return message.contains('\n    at ');
  }
}
