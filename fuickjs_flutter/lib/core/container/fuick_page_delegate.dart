import 'dart:async';

import '../logger.dart';
import '../widgets/fuick_node.dart';
import 'fuick_app_controller.dart';

class PrewarmEntry {
  final int pageId;
  final String path;
  final Map<String, dynamic> params;
  Map<String, dynamic>? dsl;
  final Completer<Map<String, dynamic>> _completer = Completer();

  /// 预构建产物：DSL 就绪时立即 createNode，动画期间跳过此步
  FuickNodeManager? prebuiltNodeManager;
  FuickNode? prebuiltRootNode;

  PrewarmEntry(this.pageId, this.path, this.params);

  bool get hasDsl => dsl != null;

  /// 是否有预构建的 Node 树可直接复用
  bool get hasPrebuiltNodes => prebuiltRootNode != null;

  Future<Map<String, dynamic>> get future => _completer.future;

  void resolveDsl(Map<String, dynamic> d) {
    dsl = d;
    // 立即解析 DSL 为 FuickNode 树，不等 FuickPageView
    prebuiltNodeManager = FuickNodeManager();
    prebuiltRootNode = prebuiltNodeManager!.createNode(d, prebuiltNodeManager!);
    if (!_completer.isCompleted) _completer.complete(d);
  }
}

class FuickPageDelegate {
  final FuickAppController controller;
  final Map<int, Function(Map<String, dynamic>)> onPageRender = {};
  final Map<int, Function(List<dynamic>)> onPagePatch = {};
  final Map<int, Function(List<dynamic>)> onPagePatchOps = {};

  /// key: path, value: 预渲染条目（只保留参数匹配的）
  final Map<String, PrewarmEntry> _prewarmCache = {};

  /// key: pageId, value: 已被 navigation delegate 认领、等待 FuickPageView 消费的条目
  final Map<int, PrewarmEntry> _claimedEntries = {};

  FuickPageDelegate(this.controller);

  void render(int pageId, Map<String, dynamic> dsl) {
    onPageRender[pageId]?.call(dsl);
  }

  void patch(int pageId, List<dynamic> patches) {
    onPagePatch[pageId]?.call(patches);
  }

  void patchOps(int pageId, List<dynamic> ops) {
    onPagePatchOps[pageId]?.call(ops);
  }

  void renderPage(int pageId, String path, Map<String, dynamic> params) {
    controller.jsProxy.render(pageId, path, params);
  }

  /// 预渲染指定页面，提前执行 JS render 并缓存 DSL。
  /// 幂等：相同 path + params 重复调用无副作用。
  /// 参数不同则取消旧的、重新预渲染。
  void prewarmPage(String path, Map<String, dynamic> params) {
    final existing = _prewarmCache[path];
    if (existing != null) {
      if (_paramsEqual(existing.params, params)) {
        logger.d('[Prewarm] prewarmPage: $path already cached, skipping');
        return; // 完全一致，幂等
      }
      // 参数不同，取消旧的重新来
      _cancelEntry(existing);
    }

    final id = nextPageId;
    logger.d('[Prewarm] prewarmPage: path=$path, pageId=$id');
    final entry = PrewarmEntry(id, path, params);
    _prewarmCache[path] = entry;

    // 临时 render 回调：捕获 DSL 后移除自身，等真实 FuickPageView 注册
    onPageRender[id] = (dsl) {
      entry.resolveDsl(dsl);
      onPageRender.remove(id);
    };

    controller.jsProxy.render(id, path, params);
  }

  /// 获取预热条目（不消费，仅用于等待 DSL 就绪）
  PrewarmEntry? getPrewarmEntry(String path) => _prewarmCache[path];

  /// 认领预渲染条目（navigation delegate 调用）：
  /// 从 path 缓存移到 pageId 缓存，返回 entry 以便取 pageId。
  PrewarmEntry? claimPrewarm(String path, Map<String, dynamic> params) {
    final entry = _prewarmCache[path];
    if (entry == null) {
      logger.d('[Prewarm] claimPrewarm: $path entry=null (not found)');
      return null;
    }
    if (!_paramsEqual(entry.params, params)) {
      logger.d('[Prewarm] claimPrewarm: $path params mismatch');
      return null;
    }
    _prewarmCache.remove(path);
    _claimedEntries[entry.pageId] = entry;
    logger.d('[Prewarm] claimPrewarm: $path claimed pageId=${entry.pageId}');
    return entry;
  }

  /// 消费已认领的预渲染条目（FuickPageView 调用）：
  /// 按 pageId 取出条目，用完即删。
  PrewarmEntry? consumeByPageId(int pageId) {
    return _claimedEntries.remove(pageId);
  }

  /// 取消预渲染，清理 JS 侧 PageContainer 及缓存。
  void cancelPrewarm(String path) {
    final entry = _prewarmCache.remove(path);
    if (entry != null) _cancelEntry(entry);
  }

  void _cancelEntry(PrewarmEntry entry) {
    onPageRender.remove(entry.pageId);
    controller.jsProxy.destroy(entry.pageId);
  }

  bool _paramsEqual(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key)) return false;
      final av = a[key];
      final bv = b[key];
      if (av is Map<String, dynamic> && bv is Map<String, dynamic>) {
        if (!_paramsEqual(av, bv)) return false;
      } else if (av is List && bv is List) {
        if (av.length != bv.length) return false;
        for (int i = 0; i < av.length; i++) {
          if (av[i] is Map<String, dynamic> && bv[i] is Map<String, dynamic>) {
            if (!_paramsEqual(
                av[i] as Map<String, dynamic>, bv[i] as Map<String, dynamic>)) {
              return false;
            }
          } else if (av[i] != bv[i]) {
            return false;
          }
        }
      } else if (av != bv) {
        return false;
      }
    }
    return true;
  }

  void destroyPage(int pageId) {
    controller.jsProxy.destroy(pageId);
  }

  void notifyLifecycle(int pageId, String type) {
    controller.jsProxy.notifyLifecycle(pageId, type);
  }

  dynamic getItemDSL(int pageId, String refId, int index) {
    return controller.jsProxy.getItemDSL(pageId, refId, index);
  }

  void disposeItem(int pageId, String refId, int index) {
    controller.jsProxy.disposeItem(pageId, refId, index);
  }
}
