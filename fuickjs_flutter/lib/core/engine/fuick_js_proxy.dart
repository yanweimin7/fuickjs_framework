import 'package:fjs_engine/core/jscontext_interface.dart';

class FuickJsProxy {
  final IQuickJsContext ctx;

  FuickJsProxy(this.ctx);

  void render(int pageId, String path, Map<String, dynamic> params) {
    ctx.invoke('fuickjs', 'render', [pageId, path, params]);
  }

  void destroy(int pageId) {
    ctx.invoke('fuickjs', 'destroy', [pageId]);
    // destroy 后强制 GC:QuickJS 默认无 malloc_limit,不会自动触发周期检测,
    // React fiber 树与闭包的循环引用必须靠 JS_RunGC 打破。
    // fire-and-forget:runGC 在 worker isolate 中按顺序排在 destroy 之后执行。
    ctx.runGC();
  }

  void notifyLifecycle(int pageId, String type) {
    ctx.invoke('fuickjs', 'notifyLifecycle', [pageId, type]);
  }

  dynamic getItemDSL(int pageId, String refId, int index) {
    return ctx.invoke('fuickjs', 'getItemDSL', [pageId, refId, index]);
  }

  void disposeItem(int pageId, String refId, int index) {
    ctx.invoke('fuickjs', 'disposeItem', [pageId, refId, index]);
  }

  void dispatchEvent(dynamic eventObj, dynamic payload) {
    ctx.invoke('fuickjs', 'dispatchEvent', [eventObj, payload]);
  }

  void handleTimer(int id) {
    ctx.invoke('fuickjs', 'handleTimer', [id]);
  }
}
