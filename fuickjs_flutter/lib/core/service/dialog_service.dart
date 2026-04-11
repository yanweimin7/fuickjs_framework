import 'package:flutter/cupertino.dart' hide widgetFactory;
import 'package:flutter/material.dart' hide widgetFactory;

import '../container/fuick_app_controller.dart';
import '../container/fuick_page_view.dart';
import '../logger.dart';
import '../utils/extensions.dart';
import '../widgets/fuick_node.dart';
import '../widgets/widget_factory.dart';
import '../widgets/widget_utils.dart';
import 'base_fuick_service.dart';

class DialogService extends BaseFuickService {
  @override
  String get name => 'Dialog';

  /// Stack to manage multiple nested dialog contexts
  final List<BuildContext> _dialogContexts = [];

  DialogService() {
    registerAsyncMethod('show', _show);
    registerMethod('dismiss', _dismiss);
    registerAsyncMethod('showModal', _showModal);
    registerAsyncMethod('showActionSheet', _showActionSheet);
    registerAsyncMethod('showPicker', _showPicker);
    registerAsyncMethod('showDatePicker', _showDatePicker);
    registerAsyncMethod('showTimePicker', _showTimePicker);
  }

  Future<dynamic> _show(dynamic args) async {
    final Map params = args is Map ? args : {};
    final Map<String, dynamic>? dsl =
        params['dsl'] != null ? Map<String, dynamic>.from(params['dsl']) : null;
    final int? pageId = asIntOrNull(params['pageId']);
    final bool barrierDismissible = params['barrierDismissible'] ?? true;
    final String? barrierColorHex = params['barrierColor'] as String?;

    if (dsl == null) {
      logger.w('[DialogService] DSL is null');
      return null;
    }

    if (controller == null) {
      logger.w('[DialogService] controller is null');
      return null;
    }

    final contexts = controller!.navigation.pageContexts;
    if (contexts.isEmpty) {
      logger.w('[DialogService] No page contexts available');
      return null;
    }

    final context = contexts.last;
    if (!context.mounted) return null;

    final nodeManager = FuickNodeManager();
    final rootNode = nodeManager.createNode(dsl, nodeManager);

    return await showDialog(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierColor: WidgetUtils.colorFromHex(barrierColorHex),
      builder: (dialogContext) {
        // Track this dialog context
        _dialogContexts.add(dialogContext);

        return FuickNodeManagerProvider(
          manager: nodeManager,
          child: FuickAppScope(
            controller: controller!,
            child: FuickPageScope(
              pageId: pageId ?? -1,
              child: Builder(
                builder: (ctx) => widgetFactory.buildFromNode(
                  ctx,
                  rootNode,
                  forceWrap: true,
                ),
              ),
            ),
          ),
        );
      },
    ).then((result) {
      // Cleanup when dialog is closed (via barrier or pop)
      // Note: If dismiss() was called, it might have already been removed or will be here.
      // We use removeWhere to be safe.
      _dialogContexts.removeWhere((ctx) => !ctx.mounted);
      return result;
    });
  }

  /// showModal: 显示系统风格的 AlertDialog（不需要 DSL）
  Future<bool> _showModal(dynamic args) async {
    final Map params = args is Map ? args : {};
    final String title = params['title']?.toString() ?? '';
    final String content = params['content']?.toString() ?? '';
    final bool showCancel = params['showCancel'] ?? true;
    final String cancelText = params['cancelText']?.toString() ?? '取消';
    final String confirmText = params['confirmText']?.toString() ?? '确定';

    if (controller == null) return false;
    final contexts = controller!.navigation.pageContexts;
    if (contexts.isEmpty) return false;
    final context = contexts.last;
    if (!context.mounted) return false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: title.isNotEmpty ? Text(title) : null,
        content: content.isNotEmpty ? Text(content) : null,
        actions: [
          if (showCancel)
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(cancelText),
            ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// showActionSheet: 显示底部动作菜单
  Future<int> _showActionSheet(dynamic args) async {
    final Map params = args is Map ? args : {};
    final List items = params['items'] is List ? params['items'] as List : [];

    if (controller == null) return -1;
    final contexts = controller!.navigation.pageContexts;
    if (contexts.isEmpty) return -1;
    final context = contexts.last;
    if (!context.mounted) return -1;

    final result = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...items.asMap().entries.map((entry) => ListTile(
              title: Text(entry.value.toString()),
              onTap: () => Navigator.of(ctx).pop(entry.key),
            )),
            const Divider(height: 1),
            ListTile(
              title: const Text('取消', textAlign: TextAlign.center),
              onTap: () => Navigator.of(ctx).pop(-1),
            ),
          ],
        ),
      ),
    );
    return result ?? -1;
  }

  /// showPicker: 底部滚轮选择器（selector / multiSelector）
  Future<Map?> _showPicker(dynamic args) async {
    final Map params = args is Map ? args : {};
    final String mode = params['mode']?.toString() ?? 'selector';
    final String? title = params['title']?.toString();
    final String cancelText = params['cancelText']?.toString() ?? '取消';
    final String confirmText = params['confirmText']?.toString() ?? '确定';

    if (controller == null) return null;
    final contexts = controller!.navigation.pageContexts;
    if (contexts.isEmpty) return null;
    final context = contexts.last;
    if (!context.mounted) return null;

    if (mode == 'multiSelector') {
      return _showMultiColumnPicker(context, params, cancelText, confirmText, title);
    } else {
      return _showSingleColumnPicker(context, params, cancelText, confirmText, title);
    }
  }

  Future<Map?> _showSingleColumnPicker(
    BuildContext context,
    Map params,
    String cancelText,
    String confirmText,
    String? title,
  ) async {
    final List range = params['range'] is List ? params['range'] as List : [];
    final int initialIndex = asInt(params['value'] ?? 0);
    int selectedIndex = initialIndex.clamp(0, range.isEmpty ? 0 : range.length - 1);

    final result = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setState) => SizedBox(
          height: 300,
          child: Column(
            children: [
              // 顶部操作栏
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx2).pop(null),
                      child: Text(cancelText, style: const TextStyle(color: Colors.grey)),
                    ),
                    if (title != null)
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    TextButton(
                      onPressed: () => Navigator.of(ctx2).pop(selectedIndex),
                      child: Text(confirmText, style: const TextStyle(color: Color(0xFF1976D2))),
                    ),
                  ],
                ),
              ),
              // 滚轮
              Expanded(
                child: CupertinoPicker(
                  scrollController: FixedExtentScrollController(initialItem: selectedIndex),
                  itemExtent: 44,
                  onSelectedItemChanged: (i) => selectedIndex = i,
                  children: range
                      .map((e) => Center(child: Text(e.toString(), style: const TextStyle(fontSize: 16))))
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (result == null) return null;
    return {'value': result, 'label': range.isNotEmpty ? range[result].toString() : ''};
  }

  Future<Map?> _showMultiColumnPicker(
    BuildContext context,
    Map params,
    String cancelText,
    String confirmText,
    String? title,
  ) async {
    final List rangeList = params['range'] is List ? params['range'] as List : [];
    final List initialValues = params['value'] is List ? params['value'] as List : [];
    final List<int> selectedIndices = List.generate(
      rangeList.length,
      (i) => (i < initialValues.length ? asInt(initialValues[i]) : 0)
          .clamp(0, rangeList[i] is List && (rangeList[i] as List).isNotEmpty ? (rangeList[i] as List).length - 1 : 0),
    );

    final result = await showModalBottomSheet<List<int>>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setState) => SizedBox(
          height: 300,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx2).pop(null),
                      child: Text(cancelText, style: const TextStyle(color: Colors.grey)),
                    ),
                    if (title != null)
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    TextButton(
                      onPressed: () => Navigator.of(ctx2).pop(List<int>.from(selectedIndices)),
                      child: Text(confirmText, style: const TextStyle(color: Color(0xFF1976D2))),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: List.generate(rangeList.length, (colIdx) {
                    final col = rangeList[colIdx] is List ? rangeList[colIdx] as List : [];
                    return Expanded(
                      child: CupertinoPicker(
                        scrollController: FixedExtentScrollController(initialItem: selectedIndices[colIdx]),
                        itemExtent: 44,
                        onSelectedItemChanged: (i) => selectedIndices[colIdx] = i,
                        children: col
                            .map((e) => Center(child: Text(e.toString(), style: const TextStyle(fontSize: 16))))
                            .toList(),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (result == null) return null;
    final labels = List.generate(
      rangeList.length,
      (i) => rangeList[i] is List && result[i] < (rangeList[i] as List).length
          ? (rangeList[i] as List)[result[i]].toString()
          : '',
    );
    return {'value': result, 'labels': labels};
  }

  /// showDatePicker: 日期选择器
  Future<String?> _showDatePicker(dynamic args) async {
    final Map params = args is Map ? args : {};
    final String? startStr = params['start']?.toString();
    final String? endStr = params['end']?.toString();
    final String? valueStr = params['value']?.toString();

    DateTime parseDate(String? s, DateTime fallback) {
      if (s == null) return fallback;
      try { return DateTime.parse(s.replaceAll('/', '-')); } catch (_) { return fallback; }
    }

    final now = DateTime.now();
    final start = parseDate(startStr, DateTime(1900));
    final end = parseDate(endStr, DateTime(2100));
    final initial = parseDate(valueStr, now);

    if (controller == null) return null;
    final contexts = controller!.navigation.pageContexts;
    if (contexts.isEmpty) return null;
    final context = contexts.last;
    if (!context.mounted) return null;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(start) ? start : (initial.isAfter(end) ? end : initial),
      firstDate: start,
      lastDate: end,
    );
    if (picked == null) return null;
    return '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
  }

  /// showTimePicker: 时间选择器
  Future<String?> _showTimePicker(dynamic args) async {
    final Map params = args is Map ? args : {};
    final String? valueStr = params['value']?.toString();

    TimeOfDay initial = TimeOfDay.now();
    if (valueStr != null) {
      final parts = valueStr.split(':');
      if (parts.length >= 2) {
        initial = TimeOfDay(hour: int.tryParse(parts[0]) ?? 0, minute: int.tryParse(parts[1]) ?? 0);
      }
    }

    if (controller == null) return null;
    final contexts = controller!.navigation.pageContexts;
    if (contexts.isEmpty) return null;
    final context = contexts.last;
    if (!context.mounted) return null;

    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return null;
    return '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
  }

  bool _dismiss(dynamic args) {
    // Remove stale unmounted contexts first
    _dialogContexts.removeWhere((ctx) => !ctx.mounted);

    if (_dialogContexts.isNotEmpty) {
      final context = _dialogContexts.removeLast();
      Navigator.of(context).pop(args);
      return true;
    }

    // Fallback: if no tracked dialogs, try to pop from navigation stack
    if (controller != null) {
      final contexts = controller!.navigation.pageContexts;
      if (contexts.isNotEmpty) {
        final context = contexts.last;
        if (context.mounted) {
          Navigator.of(context).pop(args);
          return true;
        }
      }
    }
    return false;
  }
}
