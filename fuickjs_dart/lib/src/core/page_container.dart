import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'node.dart';

/// Global current-page context, set during any build() invocation so that
/// widget functions (container/text/…) can call registerEvent() on it.
PageContainer? _activePage;

PageContainer? get currentPage => _activePage;
void setActivePage(PageContainer? page) => _activePage = page;

/// Holds per-page state: event callbacks and root DSL node.
class PageContainer {
  final int pageId;
  DslNode? root;

  /// Root State object (dynamic to avoid circular import with stateful_widget).
  /// Set by buildWidget(); rebuild() calls state.build() to get fresh DSL.
  dynamic rootState;

  /// Root StatelessWidget (for stateless pages).
  dynamic rootWidget;

  // Store as void Function() so dart2js compiles the call site as .call$0()
  // instead of .call$1(payload) which fails on zero-arg closures.
  final _callbacks = <int, Map<String, void Function()>>{};

  PageContainer(this.pageId);

  /// Register a Dart callback and return the isFuickEvent descriptor for DSL.
  Map<String, dynamic> registerEvent(
      int nodeId, String eventKey, void Function() fn) {
    (_callbacks[nodeId] ??= {})[eventKey] = fn;
    return {
      'id': nodeId,
      'nodeId': nodeId,
      'eventKey': eventKey,
      'pageId': pageId,
      'isFuickEvent': true,
    };
  }

  /// Fire a callback. eventObj is a Dart Map (dartify()-ed by globals.dart).
  void dispatch(Map<Object?, Object?> eventObj, dynamic payload) {
    final nodeId = (eventObj['nodeId'] as num?)?.toInt();
    final key = eventObj['eventKey'] as String?;
    if (nodeId == null || key == null) return;
    _callbacks[nodeId]?[key]?.call();
  }

  /// Rebuild DSL and push to Flutter.
  void rebuild() {
    _callbacks.clear();

    final prev = _activePage;
    _activePage = this;
    try {
      if (rootState != null) {
        // ignore: avoid_dynamic_calls
        final fw = (rootState as dynamic).build();
        // ignore: avoid_dynamic_calls
        root = fw.toDslNode() as DslNode?;
      } else if (rootWidget != null) {
        // ignore: avoid_dynamic_calls
        final fw = (rootWidget as dynamic).build();
        // ignore: avoid_dynamic_calls
        root = fw.toDslNode() as DslNode?;
      }
    } finally {
      _activePage = prev;
    }

    if (root == null) return;
    _pushDsl(pageId, jsonEncode(root!.toJson()));
  }

  static void _pushDsl(int pageId, String dslJson) {
    if (globalContext['dartCallNative'] == null) return;
    final args = JSObject();
    args['pageId'] = pageId.toJS;
    args['renderData'] = (globalContext['JSON'] as JSObject?)
        ?.callMethod<JSAny?>('parse'.toJS, dslJson.toJS);
    globalContext.callMethod<JSAny?>(
      'dartCallNative'.toJS,
      'UI.renderUI'.toJS,
      args,
    );
  }
}
