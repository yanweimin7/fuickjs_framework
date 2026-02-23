import 'dart:async';
import 'dart:isolate';

import 'package:fjs_engine/core/jscontext.dart';

import 'package:flutter/foundation.dart';

import '../logger.dart';
import '../service/app_service_binder.dart';
import '../service/console_service.dart';
import '../service/timer_service.dart';
import 'engine.dart';

class IsolateHandler {
  final SendPort mainSendPort;

  final Map<String, QuickJsContext> contexts = {};

  IsolateHandler(this.mainSendPort);

  final serviceBinder = AppServiceBinder();

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
          if (EngineInit.qjs == null) {
            EngineInit.initQjs();
          }
          if (type == 'createContext') {
            if (!contexts.containsKey(contextId)) {
              if (EngineInit.runtime == null) {
                throw Exception(
                  "Failed to initialize QuickJS runtime in isolate",
                );
              }
              final ctx = EngineInit.runtime!.createContext();
              contexts[contextId] = ctx;
              serviceBinder.init(
                ctx,
                null,
                allowedServices: [TimerService, ConsoleService],
              );

              ctx.onCallNative = (method, args) {
                try {
                  if (serviceBinder.canHandle(ctx, method)) {
                    return serviceBinder.handleNativeCall(ctx, method, args);
                  }
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
              };

              ctx.onCallNativeAsync = (method, args) {
                final responsePort = ReceivePort();
                mainSendPort.send({
                  'contextId': contextId,
                  'type': 'callNativeAsync',
                  'replyPort': responsePort.sendPort,
                  'payload': {'method': method, 'args': args},
                });
                return _waitForResponse(responsePort);
              };

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
          if (type == 'eval') {
            result = await ctx!.eval(payload as String);
          } else if (type == 'evalModule') {
            result = await ctx!.evalModule(payload as String);
          } else if (type == 'evalBinary') {
            result = await ctx!.evalBinary(payload as Uint8List);
          } else if (type == 'runJobs') {
            result = await ctx!.runJobs();
          } else if (type == 'invoke') {
            final objectName = payload['objectName'] as String?;
            final methodName = payload['methodName'] as String;
            final args = payload['args'] as List;
            result = await ctx!.invoke(objectName, methodName, args);
          } else if (type == 'registerModule') {
            final name = payload['name'] as String;
            final code = payload['code'] as String;
            ctx!.registerModule(name, code);
            result = null;
          } else if (type == 'disposeContext') {
            if (ctx != null) {
              contexts.remove(contextId);
              serviceBinder.dispose(ctx);
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
