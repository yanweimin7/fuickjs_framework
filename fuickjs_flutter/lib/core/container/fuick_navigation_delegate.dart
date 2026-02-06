import 'package:flutter/cupertino.dart';
import 'fuick_app_controller.dart';
import 'fuick_page.dart';
import 'fuick_page_view.dart';

class FuickNavigationDelegate {
  final FuickAppController controller;
  final Map<int, GlobalKey<NavigatorState>> _navigators = {};
  final Map<int, Function(dynamic)> onCloseContainer = {};

  FuickNavigationDelegate(this.controller);

  void registerNavigator(int pageId, GlobalKey<NavigatorState> key) {
    _navigators[pageId] = key;
  }

  void unregisterNavigator(int pageId) {
    _navigators.remove(pageId);
  }

  GlobalKey<NavigatorState>? getNavigatorKey(int? pageId) {
    if (pageId != null && _navigators.containsKey(pageId)) {
      return _navigators[pageId];
    }
    // Fallback: return the last registered navigator (LIFO assumption for active view)
    if (_navigators.isNotEmpty) {
      return _navigators.values.last;
    }
    return null;
  }

  Future<dynamic> pushWithPath(String path, Map<String, dynamic> params,
      {int? pageId}) async {
    final navKey = getNavigatorKey(pageId);
    final nav = navKey?.currentState;
    if (nav == null) return null;
    final id = nextPageId;

    if (navKey != null) {
      registerNavigator(id, navKey);
    }

    return await nav.push(
      CupertinoPageRoute(
        settings: RouteSettings(name: path),
        builder: (_) => FuickPage(
          pageId: id,
          controller: controller,
          routeInfo: RouteInfo(path, params),
        ),
      ),
    );
  }

  void pop({int? pageId, dynamic result}) {
    final navKey = getNavigatorKey(pageId);
    final nav = navKey?.currentState;
    if (nav == null) return;
    if (nav.canPop()) {
      nav.pop(result);
    } else {
      // Fallback: use callback to close container
      if (pageId != null && onCloseContainer.containsKey(pageId)) {
        onCloseContainer[pageId]?.call(result);
        return;
      }
      try {
        Navigator.of(nav.context, rootNavigator: true).pop(result);
      } catch (e) {
        debugPrint('Failed to pop root navigator: $e');
      }
    }
  }

  void popTo(String name, {int? pageId}) {
    final navKey = getNavigatorKey(pageId);
    final nav = navKey?.currentState;
    if (nav == null) return;
    nav.popUntil((route) => route.settings.name == name);
  }
}
