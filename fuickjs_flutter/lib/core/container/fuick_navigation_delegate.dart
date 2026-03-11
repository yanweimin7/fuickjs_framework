import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../logger.dart';
import '../widgets/widget_factory.dart';
import 'fuick_app_controller.dart';
import 'fuick_page.dart';
import 'fuick_page_view.dart';

class FuickNavigationDelegate {
  final FuickAppController controller;
  final Map<int, GlobalKey<NavigatorState>> _navigators = {};
  final Map<int, BuildContext> _pageContexts = {};
  final Map<int, Function(dynamic)> onCloseContainer = {};

  /// 外部导航推送回调
  Future<dynamic> Function(String path, Map<String, dynamic> params)?
      onRootPush;

  List<BuildContext> get pageContexts => _pageContexts.values.toList();

  FuickNavigationDelegate(this.controller);

  void registerNavigator(int pageId, GlobalKey<NavigatorState> key) {
    _navigators[pageId] = key;
  }

  void registerPageContext(int pageId, BuildContext context) {
    _pageContexts[pageId] = context;
  }

  void unregisterNavigator(int pageId) {
    _navigators.remove(pageId);
    _pageContexts.remove(pageId);
  }

  GlobalKey<NavigatorState>? getNavigatorKey(int? pageId) {
    if (pageId != null && _navigators.containsKey(pageId)) {
      return _navigators[pageId];
    }
    return _navigators.isNotEmpty ? _navigators.values.last : null;
  }

  Future<dynamic> pushWithPath(String path, Map<String, dynamic> params,
      {int? pageId, bool rootNavigator = false}) async {
    return _push(path, params, pageId: pageId, rootNavigator: rootNavigator);
  }

  Future<dynamic> pushReplacementWithPath(
      String path, Map<String, dynamic> params,
      {int? pageId, bool rootNavigator = false}) async {
    return _push(path, params,
        pageId: pageId, replacement: true, rootNavigator: rootNavigator);
  }

  Future<dynamic> _push(String path, Map<String, dynamic> params,
      {int? pageId,
      bool replacement = false,
      bool rootNavigator = false}) async {
    if (rootNavigator) {
      if (onRootPush != null) {
        return onRootPush!(path, params);
      }
      // 如果没有设置 onRootPush，尝试通过当前 context 的 Navigator 往上找
      final context = _pageContexts[pageId] ?? _pageContexts.values.lastOrNull;
      if (context != null) {
        try {
          final nav = Navigator.of(context, rootNavigator: true);
          final route = _createRoute(context, path, params, nextPageId);
          return replacement ? nav.pushReplacement(route) : nav.push(route);
        } catch (e) {
          logger.w('Failed to push to root navigator: $e');
        }
      }
    }

    final navKey = getNavigatorKey(pageId);
    final nav = navKey?.currentState;
    if (nav == null) return null;

    final id = nextPageId;
    registerNavigator(id, navKey!);

    final route = _createRoute(nav.context, path, params, id);
    return replacement ? nav.pushReplacement(route) : nav.push(route);
  }

  Route _createRoute(BuildContext context, String path,
      Map<String, dynamic> params, int pageId) {
    final page = FuickPage(
      pageId: pageId,
      controller: controller,
      routeInfo: RouteInfo(path, params),
    );
    final settings = RouteSettings(name: path);
    final presentation = params['presentation'];

    if (presentation == 'dialog') {
      return DialogRoute(
          context: context, settings: settings, builder: (_) => page);
    } else if (presentation == 'bottomSheet') {
      return ModalBottomSheetRoute(
        settings: settings,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => _buildBottomSheet(ctx, page, params),
      );
    }
    return CupertinoPageRoute(settings: settings, builder: (_) => page);
  }

  Widget _buildBottomSheet(
      BuildContext context, Widget child, Map<String, dynamic> params) {
    final height = MediaQuery.of(context).size.height;
    final minHeight = (params['minHeight'] as num?)?.toDouble();
    final maxHeight = (params['maxHeight'] as num?)?.toDouble() ?? 0.9;

    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: minHeight != null ? height * minHeight : 0,
        maxHeight: height * maxHeight,
      ),
      child: child,
    );
  }

  void pop({int? pageId, dynamic result}) {
    if (_tryPopContext(pageId, result)) return;

    final nav = getNavigatorKey(pageId)?.currentState;
    if (nav == null) return;

    if (nav.canPop()) {
      nav.pop(result);
    } else {
      _handleFallbackPop(nav, pageId, result);
    }
  }

  bool _tryPopContext(int? pageId, dynamic result) {
    if (pageId != null) {
      final context = _pageContexts[pageId];
      if (context != null && context.mounted) {
        try {
          Navigator.of(context).pop(result);
          return true;
        } catch (e) {
          logger.w('Failed to pop context: $e');
        }
      }
    }
    return false;
  }

  void _handleFallbackPop(NavigatorState nav, int? pageId, dynamic result) {
    if (pageId != null && onCloseContainer.containsKey(pageId)) {
      onCloseContainer[pageId]?.call(result);
    } else {
      try {
        Navigator.of(nav.context).pop(result);
      } catch (_) {}
    }
  }

  void popTo(String name, {int? pageId}) {
    getNavigatorKey(pageId)
        ?.currentState
        ?.popUntil((route) => route.settings.name == name);
  }
}
