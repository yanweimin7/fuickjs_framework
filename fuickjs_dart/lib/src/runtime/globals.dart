import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import '../core/renderer.dart';
import '../core/router.dart';

/// Binds the `fuickjs` global object expected by the Flutter engine.
///
/// Call this once in your app's `main()`:
/// ```dart
/// void main() {
///   bindGlobals();
///   Router.register('/', (_) => MyPage());
/// }
/// ```
void bindGlobals() {
  final obj = JSObject();

  obj['render'] = _render.toJS;
  obj['destroy'] = _destroy.toJS;
  obj['dispatchEvent'] = _dispatchEvent.toJS;
  obj['getItemDSL'] = _getItemDSL.toJS;
  obj['handleTimer'] = _handleTimer.toJS;
  obj['notifyLifecycle'] = _notifyLifecycle.toJS;

  globalContext['fuickjs'] = obj;
  globalContext['window'] = globalContext;
  globalContext['self'] = globalContext;
}

void _render(int pageId, String path, JSAny? params) {
  final factory = Router.match(path);
  if (factory == null) {
    final errDsl =
        '{"id":1,"type":"Text","props":{"text":"404: $path not found"},"children":[]}';
    if (globalContext['dartSetDsl'] != null) {
      globalContext.callMethod<JSAny?>('dartSetDsl'.toJS, pageId.toJS, errDsl.toJS);
    }
    return;
  }
  Renderer.mount(pageId, factory(params));
}

void _destroy(int pageId) => Renderer.destroy(pageId);

void _dispatchEvent(JSAny? eventObj, JSAny? payload) =>
    Renderer.dispatchEvent(eventObj?.dartify(), payload?.dartify());

JSAny? _getItemDSL(int pageId, String refId, int index) => null;

void _handleTimer(String timerId, String type) {}

void _notifyLifecycle(int pageId, String type) {}
