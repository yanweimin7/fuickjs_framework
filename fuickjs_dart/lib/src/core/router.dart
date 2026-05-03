import '../state/stateful_widget.dart';

typedef PageFactory = FuickWidget Function(dynamic params);

/// Simple path → widget factory registry.
class Router {
  static final _routes = <String, PageFactory>{};

  /// Register a route. Call this in your app's main() before anything renders.
  static void register(String path, PageFactory factory) {
    _routes[path] = factory;
  }

  /// Returns the factory for [path], or null if not found.
  static PageFactory? match(String path) => _routes[path];
}
