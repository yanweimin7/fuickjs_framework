import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fjs_engine/fuickjs_core.dart';
import 'package:fuickjs_flutter/core/utils/extensions.dart';
import 'package:fuickjs_flutter/core/widgets/fuick_node.dart';
import 'package:fuickjs_flutter/core/widgets/widget_factory.dart';

/// renderUI 端到端基准:拆分 FFI 解码 / createNode / Widget 构建,
/// 对比 binary / json,说明协议优化在整条链路中的占比。
///
/// 运行:cd fuickjs_framework/fuickjs_flutter && flutter test test/render_ui_e2e_benchmark_test.dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('renderUI e2e benchmark', () {
    late QuickJsFFI ffi;
    late QuickJsRuntime runtime;
    late QuickJsContext context;
    late WidgetFactory widgetFactory;
    late FuickNodeManager nodeManager;
    BuildContext? buildContext;

    // 各阶段累计（µs）
    int decodeUs = 0;
    int createNodeUs = 0;
    int buildWidgetUs = 0;
    int handlerUs = 0;

    setUp(() {
      ffi = QuickJsFFI(QuickJsFFI.load());
      runtime = QuickJsRuntime(ffi);
      context = runtime.createContext();
      widgetFactory = WidgetFactory();
      nodeManager = FuickNodeManager();
      JSObject.captureNativeDecodeTiming = true;

      context.onCallNative = (method, args) {
        if (method != 'UI.renderUI') return true;
        final handlerSw = Stopwatch()..start();
        final m = args is Map ? args : (args as List).first as Map;
        final renderData = asMap(m['renderData']);

        final cnSw = Stopwatch()..start();
        final root = nodeManager.createNode(renderData, nodeManager);
        cnSw.stop();
        createNodeUs += cnSw.elapsedMicroseconds;

        if (buildContext != null) {
          final bwSw = Stopwatch()..start();
          widgetFactory.buildFromNode(buildContext!, root);
          bwSw.stop();
          buildWidgetUs += bwSw.elapsedMicroseconds;
        }

        handlerSw.stop();
        handlerUs += handlerSw.elapsedMicroseconds;
        decodeUs += JSObject.lastNativeDecodeMicros;
        return true;
      };
    });

    tearDown(() {
      JSObject.captureNativeDecodeTiming = false;
      context.dispose();
      runtime.dispose();
    });

    Future<void> buildDsl(int nodeCount) async {
      await context.eval('''
        globalThis.__buildDsl = function (total) {
          var counter = 0;
          var types = ['Column', 'Row', 'Container', 'Text', 'Image', 'Button'];
          function make() {
            var id = ++counter;
            return {
              id: id,
              type: types[id % types.length],
              props: {
                width: id % 375,
                height: id % 200,
                flex: id % 3,
                text: 'item ' + id,
                color: '#FF8800'
              },
              children: []
            };
          }
          var root = make();
          var queue = [root];
          while (counter < total && queue.length) {
            var parent = queue.shift();
            for (var i = 0; i < 4 && counter < total; i++) {
              var c = make();
              parent.children.push(c);
              queue.push(c);
            }
          }
          return root;
        };
        globalThis.dsl = globalThis.__buildDsl($nodeCount);
        true;
      ''');
    }

    Future<void> runRenderUi(int iterations) async {
      decodeUs = 0;
      createNodeUs = 0;
      buildWidgetUs = 0;
      handlerUs = 0;
      for (var i = 0; i < iterations; i++) {
        nodeManager = FuickNodeManager();
        await context.eval('''
          dartCallNative("UI.renderUI", { pageId: 1, renderData: globalThis.dsl });
        ''');
      }
    }

    Future<_PhaseStats> benchMode({
      required bool binary,
      required int nodeCount,
      required int iterations,
    }) async {
      ffi.setUseBinaryProtocol(binary);
      await buildDsl(nodeCount);

      for (var i = 0; i < 3; i++) {
        await runRenderUi(1);
      }
      await runRenderUi(iterations);

      final n = iterations.toDouble();
      return _PhaseStats(
        decodeUs: decodeUs / n,
        createNodeUs: createNodeUs / n,
        buildWidgetUs: buildWidgetUs / n,
        handlerUs: handlerUs / n,
      );
    }

    testWidgets('renderUI pipeline breakdown (binary vs json)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) {
              buildContext = ctx;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      const rounds = 3;
      const configs = [
        ('binary', true),
        ('json', false),
      ];

      // ignore: avoid_print
      print('=== renderUI 端到端基准(含 createNode + Widget 构建)===');
      // ignore: avoid_print
      print('每轮:dartCallNative(UI.renderUI) -> FFI 解码 -> createNode -> buildFromNode');

      for (final nodeCount in [50, 500, 2000]) {
        final iterations = nodeCount <= 50 ? 100 : (nodeCount <= 500 ? 50 : 20);
        final results = <String, List<_PhaseStats>>{
          for (final c in configs) c.$1: [],
        };

        for (var r = 0; r < rounds; r++) {
          for (final (name, binary) in configs) {
            results[name]!.add(await benchMode(
              binary: binary,
              nodeCount: nodeCount,
              iterations: iterations,
            ));
          }
        }

        // ignore: avoid_print
        print('\n--- 节点≈$nodeCount  迭代 $iterations 次/模式  $rounds 轮 ---');
        for (final (name, _) in configs) {
          final list = results[name]!;
          final decode = _avg(list.map((e) => e.decodeUs));
          final create = _avg(list.map((e) => e.createNodeUs));
          final build = _avg(list.map((e) => e.buildWidgetUs));
          final total = decode + create + build;
          // ignore: avoid_print
          print(
            '$name: total=${total.toStringAsFixed(1)}µs '
            '(decode=${decode.toStringAsFixed(1)} '
            'createNode=${create.toStringAsFixed(1)} '
            'buildWidget=${build.toStringAsFixed(1)}) '
            '| decode占比=${(decode / total * 100).toStringAsFixed(1)}%',
          );
        }

        final binTotal = _avg(results['binary']!.map((e) => e.totalUs));
        final jsonTotal = _avg(results['json']!.map((e) => e.totalUs));
        // ignore: avoid_print
        print(
          '总耗时对比: binary=${(binTotal / 1000).toStringAsFixed(2)}ms '
          'json=${(jsonTotal / 1000).toStringAsFixed(2)}ms '
          '| binary省json=${((jsonTotal - binTotal) / 1000).toStringAsFixed(2)}ms '
          '(${(jsonTotal / binTotal).toStringAsFixed(2)}×)',
        );
      }

      ffi.setUseBinaryProtocol(true);
      expect(buildContext, isNotNull);
    });
  });
}

class _PhaseStats {
  final double decodeUs;
  final double createNodeUs;
  final double buildWidgetUs;
  final double handlerUs;

  const _PhaseStats({
    required this.decodeUs,
    required this.createNodeUs,
    required this.buildWidgetUs,
    required this.handlerUs,
  });

  double get totalUs => decodeUs + createNodeUs + buildWidgetUs;
}

double _avg(Iterable<double> values) =>
    values.reduce((a, b) => a + b) / values.length;
