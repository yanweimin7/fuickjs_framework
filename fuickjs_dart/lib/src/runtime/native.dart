import 'dart:js_interop';
import 'dart:js_interop_unsafe';

JSAny? _toJS(dynamic value) => value?.jsify() as JSAny?;

/// Synchronously call a Flutter Native Service method.
///
/// Equivalent to the TS-side: `dartCallNative('ServiceName.method', args)`
///
/// Example:
/// ```dart
/// callNative('Dialog.show', {'title': 'Hello'});
/// callNative('Navigator.push', {'path': '/detail', 'params': {'id': 1}});
/// ```
T? callNative<T>(String method, [dynamic args]) {
  if (globalContext['dartCallNative'] == null) return null;
  final result = globalContext.callMethod<JSAny?>(
    'dartCallNative'.toJS,
    method.toJS,
    _toJS(args),
  );
  return result?.dartify() as T?;
}

/// Asynchronously call a Flutter Native Service method.
///
/// Equivalent to the TS-side: `await dartCallNativeAsync('ServiceName.method', args)`
///
/// Example:
/// ```dart
/// final value = await callNativeAsync<String?>('LocalStorage.getItem', ['key']);
/// final user = await callNativeAsync<Map>('UserService.getUser', {'id': 123});
/// ```
Future<T?> callNativeAsync<T>(String method, [dynamic args]) async {
  if (globalContext['dartCallNativeAsync'] == null) return null;
  final promise = globalContext.callMethod<JSAny?>(
    'dartCallNativeAsync'.toJS,
    method.toJS,
    _toJS(args),
  );
  if (promise == null) return null;
  final result = await (promise as JSPromise<JSAny?>).toDart;
  return result?.dartify() as T?;
}
