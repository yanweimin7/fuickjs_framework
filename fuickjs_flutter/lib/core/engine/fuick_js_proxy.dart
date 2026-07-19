import 'package:fjs_engine/core/jscontext_interface.dart';

class FuickJsProxy {
  final IQuickJsContext ctx;

  FuickJsProxy(this.ctx);

  void render(int pageId, String path, Map<String, dynamic> params) {
    ctx.invoke('fuickjs', 'render', [pageId, path, params]);
  }

  void destroy(int pageId) {
    // QuickJS 自带 threshold-based GC(默认 256KB 触发一次 mark-sweep,
    // 触发后阈值自适应涨到 malloc_size*1.5),destroy 后下一次 malloc
    // 就会自动回收 React fiber 树与闭包循环引用,无需手动 JS_RunGC。
    ctx.invoke('fuickjs', 'destroy', [pageId]);
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
