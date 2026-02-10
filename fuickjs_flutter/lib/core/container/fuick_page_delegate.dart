import 'fuick_app_controller.dart';

class FuickPageDelegate {
  final FuickAppController controller;
  final Map<int, Function(Map<String, dynamic>)> onPageRender = {};
  final Map<int, Function(List<dynamic>)> onPagePatch = {};
  final Map<int, Function(List<dynamic>)> onPagePatchOps = {};

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
    controller.ctx
        .invoke('FuickAppController', 'render', [pageId, path, params]);
  }

  void destroyPage(int pageId) {
    controller.ctx.invoke('FuickAppController', 'destroy', [pageId]);
  }

  void notifyLifecycle(int pageId, String type) {
    controller.ctx
        .invoke('FuickAppController', 'notifyLifecycle', [pageId, type]);
  }

  dynamic getItemDSL(int pageId, String refId, int index) {
    return controller.ctx.invoke('FuickAppController', 'getItemDSL', [
      pageId,
      refId,
      index,
    ]);
  }
}
