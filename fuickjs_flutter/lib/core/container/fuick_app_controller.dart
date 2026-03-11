import 'package:fjs_engine/core/jscontext_interface.dart';
import 'package:flutter/cupertino.dart';

import '../engine/bundle_preloader.dart';
import '../engine/fuick_js_proxy.dart';
import '../service/app_service_binder.dart';
import '../service/base_fuick_service.dart';
import '../service/fuick_command_bus.dart';
import 'fuick_navigation_delegate.dart';
import 'fuick_page_delegate.dart';

class FuickAppController {
  final IQuickJsContext ctx;
  late final FuickJsProxy jsProxy;

  late final FuickNavigationDelegate navigation;
  late final FuickPageDelegate page;

  final RouteObserver<ModalRoute<void>> routeObserver =
      RouteObserver<ModalRoute<void>>();

  final FuickCommandBus commandBus = FuickCommandBus();
  final serviceBinder = AppServiceBinder();
  final ValueNotifier<bool> isBundleLoaded = ValueNotifier<bool>(false);

  static Future<void> preloadBundle(String bundleName) {
    return BundlePreloader().preloadBundle(bundleName);
  }

  FuickAppController(this.ctx) {
    jsProxy = FuickJsProxy(ctx);
    navigation = FuickNavigationDelegate(this);
    page = FuickPageDelegate(this);
    serviceBinder.init(ctx, this);
  }

  T? getService<T extends BaseFuickService>() {
    return serviceBinder.getService<T>(ctx);
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

  Map<int, Function(dynamic)> get onCloseContainer =>
      navigation.onCloseContainer;

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

  void dispose() {
    // Store context locally to avoid race conditions
    final currentCtx = ctx;
    final currentServiceBinder = serviceBinder;

    // Use a shorter delay and add cleanup tracking
    Future.delayed(const Duration(seconds: 2), () {
      currentCtx.dispose();
      currentServiceBinder.dispose(currentCtx);
    });
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
