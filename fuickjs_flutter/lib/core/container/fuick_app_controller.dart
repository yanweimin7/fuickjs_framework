import 'package:fjs_engine/core/jscontext_interface.dart';
import 'package:flutter/cupertino.dart';

import '../engine/fuick_js_proxy.dart';
import '../service/app_service_binder.dart';
import '../service/base_fuick_service.dart';
import '../service/fuick_command_bus.dart';
import '../widgets/widget_factory.dart';
import 'fuick_navigation_delegate.dart';
import 'fuick_page_delegate.dart';

int pageId = 0;

int get nextPageId {
  return ++pageId;
}

WidgetFactory widgetFactory = WidgetFactory();

class FuickAppController {
  final IQuickJsContext ctx;
  late final FuickJsProxy jsProxy;

  late final FuickNavigationDelegate navigation;
  late final FuickPageDelegate page;

  final RouteObserver<Route<dynamic>> routeObserver =
      RouteObserver<Route<dynamic>>();

  final FuickCommandBus commandBus = FuickCommandBus();
  final serviceBinder = AppServiceBinder();
  final ValueNotifier<bool> isBundleLoaded = ValueNotifier<bool>(false);

  /// 预渲染页面（需 bundle 已加载，否则 render 消息排队等 bundle eval 完成后执行）
  void prewarmPage(String path, Map<String, dynamic> params) =>
      page.prewarmPage(path, params);

  /// 认领预渲染条目（navigation delegate 调用，path + params 必须匹配）
  PrewarmEntry? claimPrewarm(String path, Map<String, dynamic> params) =>
      page.claimPrewarm(path, params);

  /// 取消预渲染
  void cancelPrewarm(String path) => page.cancelPrewarm(path);

  FuickAppController(this.ctx) {
    jsProxy = FuickJsProxy(ctx);
    navigation = FuickNavigationDelegate(this);
    page = FuickPageDelegate(this);
    serviceBinder.init(ctx, this);
  }

  T? getService<T extends BaseFuickService>() {
    return serviceBinder.getService<T>();
  }

  // --- Navigation Delegates ---

  void registerNavigator(int pageId, GlobalKey<NavigatorState> key) =>
      navigation.registerNavigator(pageId, key);

  void registerPageContext(int pageId, BuildContext context) =>
      navigation.registerPageContext(pageId, context);

  void unregisterNavigator(int pageId) =>
      navigation.unregisterNavigator(pageId);

  Future<dynamic> pushWithPath(String path, Map<String, dynamic> params,
          {int? pageId, bool rootNavigator = false}) =>
      navigation.pushWithPath(path, params,
          pageId: pageId, rootNavigator: rootNavigator);

  Future<dynamic> pushReplacementWithPath(
          String path, Map<String, dynamic> params,
          {int? pageId, bool rootNavigator = false}) =>
      navigation.pushReplacementWithPath(path, params,
          pageId: pageId, rootNavigator: rootNavigator);

  void pop({int? pageId, dynamic result}) =>
      navigation.pop(pageId: pageId, result: result);

  void popTo(String name, {int? pageId}) =>
      navigation.popTo(name, pageId: pageId);

  void popAll({int? pageId}) => navigation.popAll(pageId: pageId);

  void switchTab(String path) => navigation.switchTab(path);

  // --- Page/Rendering Delegates ---

  Map<int, Function(Map<String, dynamic>)> get onPageRender =>
      page.onPageRender;

  Map<int, Function(List<dynamic>)> get onPagePatch => page.onPagePatch;

  Map<int, Function(List<dynamic>)> get onPagePatchOps => page.onPagePatchOps;

  void render(int pageId, Map<String, dynamic> dsl) => page.render(pageId, dsl);

  void patch(int pageId, List<dynamic> patches) => page.patch(pageId, patches);

  void patchOps(int pageId, List<dynamic> ops) => page.patchOps(pageId, ops);

  void renderPage(int pageId, String path, Map<String, dynamic> params) =>
      page.renderPage(pageId, path, params);

  void destroyPage(int pageId) => page.destroyPage(pageId);

  void notifyLifecycle(int pageId, String type) =>
      page.notifyLifecycle(pageId, type);

  dynamic getItemDSL(int pageId, String refId, int index) =>
      page.getItemDSL(pageId, refId, index);

  void disposeItem(int pageId, String refId, int index) =>
      page.disposeItem(pageId, refId, index);

  void dispose() {
    // 先销毁 service（如 Timer、WebSocket），再销毁 context
    // JsContextDelegate.dispose() 通过 isolate 消息队列发送 disposeContext，
    // 天然保证在所有 pending 操作之后执行，无需人为延迟
    serviceBinder.dispose();
    ctx.dispose();
    isBundleLoaded.dispose();
  }
}

class FuickAppScope extends InheritedWidget {
  final FuickAppController controller;

  const FuickAppScope({
    super.key,
    required this.controller,
    required super.child,
  });

  static FuickAppController? of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<FuickAppScope>()
        ?.controller;
  }

  static FuickAppController? find(BuildContext context) {
    return (context
            .getElementForInheritedWidgetOfExactType<FuickAppScope>()
            ?.widget as FuickAppScope?)
        ?.controller;
  }

  @override
  bool updateShouldNotify(FuickAppScope oldWidget) {
    return controller != oldWidget.controller;
  }
}
