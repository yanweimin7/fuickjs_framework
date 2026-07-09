import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuickjs_flutter/core/widgets/parsers/image_parser.dart';
import 'package:fuickjs_flutter/core/widgets/widget_factory.dart';

void main() {
  group('ImageParser centerSlice 强制 fit=fill', () {
    final parser = ImageParser();

    // 从 Widget 树里把所有 Image widget 收集出来,验证 fit/centerSlice
    List<Image> collectImages(Widget w) {
      final out = <Image>[];
      void visit(Widget? node) {
        if (node == null) return;
        if (node is SafeCenterSliceImage) {
          // SafeCenterSliceImage wraps Image with runtime centerSlice safety check
          out.add(Image(
            image: const AssetImage('__safe__'),
            fit: node.fit,
            centerSlice: node.centerSlice,
          ));
          return;
        }
        if (node is Image) {
          out.add(node);
          return;
        }
        if (node is Padding) {
          visit(node.child);
        } else if (node is ClipRRect) {
          visit(node.child);
        } else if (node is Container) {
          visit(node.child);
        } else if (node is DecoratedBox) {
          visit(node.child);
        } else if (node is ColoredBox) {
          visit(node.child);
        } else if (node is DefaultTextStyle) {
          visit(node.child);
        } else if (node is IconTheme) {
          visit(node.child);
        } else if (node is MediaQuery) {
          visit(node.child);
        } else if (node is CachedNetworkImage) {
          // imageBuilder 包装的内层 Image 是真正带 centerSlice 的那个
          if (node.imageBuilder != null) {
            // 用一个永远不会 resolve 的 provider,只为了拿到 builder 内部的 Image
            final builder = node.imageBuilder!;
            final inner = builder(
              _NullBuildContext(),
              ResizeImage(const AssetImage('__nope__'), width: 1),
            );
            visit(inner);
          }
        }
      }

      visit(w);
      return out;
    }

    Widget parse(Map<String, dynamic> props) {
      return parser.parse(
        _NullBuildContext(),
        props,
        null,
        WidgetFactory(),
      );
    }

    test('fit=cover + centerSlice → 强制 fit=fill', () {
      final w = parse({
        'src': 'https://example.com/a.png',
        'width': 100,
        'height': 100,
        'fit': 'cover',
        'centerSlice': {
          'left': 10,
          'top': 10,
          'right': 50,
          'bottom': 50,
        },
      });
      final images = collectImages(w);
      expect(images, isNotEmpty);
      for (final img in images) {
        expect(img.fit, BoxFit.fill, reason: 'centerSlice 模式下 fit 必须被强制为 fill');
        expect(img.centerSlice, const Rect.fromLTRB(10, 10, 50, 50));
      }
    });

    test('fit=contain + centerSlice → 强制 fit=fill', () {
      final w = parse({
        'src': 'https://example.com/a.png',
        'width': 100,
        'height': 100,
        'fit': 'contain',
        'centerSlice': {
          'left': 5,
          'top': 5,
          'right': 95,
          'bottom': 95,
        },
      });
      for (final img in collectImages(w)) {
        expect(img.fit, BoxFit.fill);
      }
    });

    test('无 fit + centerSlice → 强制 fit=fill', () {
      final w = parse({
        'src': 'https://example.com/a.png',
        'width': 100,
        'height': 100,
        'centerSlice': {
          'left': 10,
          'top': 10,
          'right': 50,
          'bottom': 50,
        },
      });
      for (final img in collectImages(w)) {
        expect(img.fit, BoxFit.fill,
            reason: '即使原 fit=null,centerSlice 也必须强制为 fill');
      }
    });

    test('fit=fill + centerSlice → 保持 fill', () {
      final w = parse({
        'src': 'https://example.com/a.png',
        'width': 100,
        'height': 100,
        'fit': 'fill',
        'centerSlice': {
          'left': 10,
          'top': 10,
          'right': 50,
          'bottom': 50,
        },
      });
      for (final img in collectImages(w)) {
        expect(img.fit, BoxFit.fill);
      }
    });

    test('无 centerSlice 时 fit 原样透传(cover,asset 图)', () {
      final w = parse({
        // asset 路径走 Image.asset 路径,直接构造 Image widget
        'src': 'assets/foo.png',
        'width': 100,
        'height': 100,
        'fit': 'cover',
      });
      final images = collectImages(w);
      expect(images, isNotEmpty);
      expect(images.any((img) => img.fit == BoxFit.cover), isTrue,
          reason: '没设 centerSlice 时 fit 应原样透传,不应被强制改写');
    });

    test('非法 centerSlice 被丢弃(不传 Image)', () {
      // right <= left / bottom <= top / 负值
      for (final bad in [
        {},
        {'left': 10, 'top': 10, 'right': 10, 'bottom': 50},
        {'left': 10, 'top': 10, 'right': 50, 'bottom': 10},
        {'left': -1, 'top': 10, 'right': 50, 'bottom': 50},
      ]) {
        final w = parse({
          'src': 'https://example.com/a.png',
          'width': 100,
          'height': 100,
          'centerSlice': bad,
        });
        for (final img in collectImages(w)) {
          expect(img.centerSlice, isNull, reason: '非法 centerSlice=$bad 应被丢弃');
        }
      }
    });

    test('SVG + centerSlice 静默忽略', () {
      final w = parse({
        'src': 'assets/foo.svg',
        'width': 100,
        'height': 100,
        'centerSlice': {
          'left': 10,
          'top': 10,
          'right': 50,
          'bottom': 50,
        },
      });
      // 不会构造 Image(走 SvgPicture 路径),collectImages 返回空
      expect(collectImages(w), isEmpty);
    });
  });
}

/// BuildContext 空实现。parser 在没有 onLoad/onError 的场景下不会真的用到
/// context 的具体成员,这里把 noSuchMethod 暴露给所有未预期的访问。
class _NullBuildContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
