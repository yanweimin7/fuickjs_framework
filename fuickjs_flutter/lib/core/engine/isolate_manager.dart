import 'dart:async';
import 'dart:isolate';

import 'package:easy_isolate/easy_isolate.dart';
import 'package:fjs_engine/core/jscontext_interface.dart';

import 'package:flutter/foundation.dart';

import '../logger.dart';
import '../service/app_service_binder.dart';
import '../service/console_service.dart';
import '../service/file_system_service.dart';
import '../service/timer_service.dart';
import 'engine.dart';

// ─── Generic IsolateHandler ────────────────────────────────────────────────

class IsolateHandler {
  final SendPort mainSendPort;
  final IQuickJsContext Function() contextFactory;

  final Map<String, IQuickJsContext> contexts = {};
  final Map<String, AppServiceBinder> _binders = {};

  IsolateHandler(this.mainSendPort, this.contextFactory);

  Future<dynamic> _waitForResponse(ReceivePort port) async {
    final result = await port.first;
    port.close();
    return result;
  }

  void handleMessage(
    String contextId,
    String type,
    String id,
    dynamic payload,
  ) async {
    runZonedGuarded(
      () async {
        try {
          if (type == 'createContext') {
            if (!contexts.containsKey(contextId)) {
              final ctx = contextFactory();
              contexts[contextId] = ctx;

              final binder = AppServiceBinder();
              _binders[contextId] = binder;
              binder.init(
                ctx,
                null,
                allowedServices: [
                  TimerService,
                  ConsoleService,
                  FileSystemService
                ],
                fallbackSync: (method, args) {
                  try {
                    final responsePort = ReceivePort();
                    mainSendPort.send({
                      'contextId': contextId,
                      'type': 'callNative',
                      'replyPort': responsePort.sendPort,
                      'payload': {'method': method, 'args': args},
                    });
                    return _waitForResponse(responsePort);
                  } catch (e, s) {
                    logger.e("Isolate onCallNative error: $e\n$s");
                    rethrow;
                  }
                },
                fallbackAsync: (method, args) async {
                  final responsePort = ReceivePort();
                  mainSendPort.send({
                    'contextId': contextId,
                    'type': 'callNativeAsync',
                    'replyPort': responsePort.sendPort,
                    'payload': {'method': method, 'args': args},
                  });
                  return _waitForResponse(responsePort);
                },
              );

              mainSendPort.send({
                'type': 'response',
                'id': id,
                'payload': null,
              });
              return;
            }
          }

          final ctx = contexts[contextId];
          if (ctx == null && type != 'disposeContext') {
            mainSendPort.send({
              'type': 'response',
              'id': id,
              'payload': null,
              'error': 'Context not found: $contextId',
            });
            return;
          }

          dynamic result;
          if (type == 'setSourceMap') {
            final map = payload as Map<String, dynamic>?;
            ConsoleService.setSourceMap(map);
            result = null;
          } else if (type == 'eval') {
            final code = payload['code'] as String;
            final returnValue = payload['returnValue'] as bool? ?? true;
            result = await ctx!.eval(code, returnValue: returnValue);
          } else if (type == 'evalModule') {
            result = await ctx!.evalModule(payload as String);
          } else if (type == 'evalBinary') {
            final bytecode = payload['bytecode'] as Uint8List;
            final returnValue = payload['returnValue'] as bool? ?? false;
            final isModule = payload['isModule'] as bool? ?? false;
            result = await ctx!.evalBinary(bytecode,
                returnValue: returnValue, isModule: isModule);
          } else if (type == 'evalFileFromPath') {
            final path = payload['path'] as String;
            final returnValue = payload['returnValue'] as bool? ?? true;
            final isModule = payload['isModule'] as bool? ?? false;
            result = await ctx!.evalFileFromPath(path,
                returnValue: returnValue, isModule: isModule);
          } else if (type == 'evalBinaryFileFromPath') {
            final path = payload['path'] as String;
            final returnValue = payload['returnValue'] as bool? ?? false;
            final isModule = payload['isModule'] as bool? ?? false;
            result = await ctx!.evalBinaryFileFromPath(path,
                returnValue: returnValue, isModule: isModule);
          } else if (type == 'compile') {
            final code = payload['code'] as String;
            final isModule = payload['isModule'] as bool? ?? false;
            final stripSource = payload['stripSource'] as bool? ?? true;
            result = await ctx!
                .compile(code, isModule: isModule, stripSource: stripSource);
          } else if (type == 'runJobs') {
            result = await ctx!.runJobs();
          } else if (type == 'bytecodeVersion') {
            result = await ctx!.bytecodeVersion;
          } else if (type == 'invoke') {
            final objectName = payload['objectName'] as String?;
            final methodName = payload['methodName'] as String;
            final args = payload['args'] as List;
            result = await ctx!.invoke(objectName, methodName, args);
          } else if (type == 'invokeAsync') {
            final objectName = payload['objectName'] as String?;
            final methodName = payload['methodName'] as String;
            final args = payload['args'] as List;
            final timeoutMs = payload['timeoutMs'] as int?;
            result = await ctx!.invokeAsync(
              objectName,
              methodName,
              args,
              timeout:
                  timeoutMs == null ? null : Duration(milliseconds: timeoutMs),
            );
          } else if (type == 'registerModule') {
            final name = payload['name'] as String;
            final code = payload['code'] as String;
            ctx!.registerModule(name, code);
            result = null;
          } else if (type == 'disposeContext') {
            if (ctx != null) {
              contexts.remove(contextId);
              _binders.remove(contextId)?.dispose();
              ctx.dispose();
            }
            result = null;
          }

          mainSendPort.send({
            'contextId': contextId,
            'type': 'response',
            'id': id,
            'payload': result,
          });
        } finally {}
      },
      (e, s) {
        logger.e("Error in IsolateManager.handleMessage: $e\n$s");
        mainSendPort.send({
          'contextId': contextId,
          'type': 'response',
          'id': id,
          'payload': null,
          'error': e.toString(),
        });
      },
    );
  }
}

// ─── QuickJS isolate entry point ───────────────────────────────────────────

IsolateHandler? _quickJsHandler;

@pragma('vm:entry-point')
FutureOr<void> quickJsIsolateEntry(
  dynamic data,
  SendPort mainSendPort,
  SendErrorFunction onSendError,
) {
  _quickJsHandler ??= IsolateHandler(mainSendPort, _createQuickJsContext);
  if (data is! Map) return null;
  _quickJsHandler!.handleMessage(
    data['contextId'] as String,
    data['type'] as String,
    data['id'] as String,
    data['payload'],
  );
  return null;
}

IQuickJsContext _createQuickJsContext() {
  if (EngineInit.qjs == null) EngineInit.initQjs();
  if (EngineInit.runtime == null) {
    throw Exception('Failed to initialize QuickJS runtime in isolate');
  }
  return EngineInit.runtime!.createContext();
}

IQuickJsContext _createJscContext() {
  if (EngineInit.jscRuntime == null) EngineInit.initJsc();
  return EngineInit.jscRuntime!.createContext();
}

// ─── JSC isolate entry point ───────────────────────────────────────────────

IsolateHandler? _jscHandler;

@pragma('vm:entry-point')
FutureOr<void> jscIsolateEntry(
  dynamic data,
  SendPort mainSendPort,
  SendErrorFunction onSendError,
) {
  _jscHandler ??= IsolateHandler(mainSendPort, _createJscContext);
  if (data is! Map) return null;
  _jscHandler!.handleMessage(
    data['contextId'] as String,
    data['type'] as String,
    data['id'] as String,
    data['payload'],
  );
  return null;
}
