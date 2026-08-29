import 'package:fjs_engine/core/js_bridge.dart';

class FuickJsProxy {
  final JsBridge ctx;

  FuickJsProxy(this.ctx);

  void render(int pageId, String path, Map<String, dynamic> params) {
    ctx.invoke('fuickjs', 'render', [pageId, path, params]);
  }

  void destroy(int pageId) {
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
