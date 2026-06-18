import '../entities/package.dart';

/// 包状态机的持久化容器：维护 active / staged / history 三组列表。
/// 以 bundle name 为单位语义独立（同一 name 下 active 至多 1、staged 至多 1）。
class PackageRegistry {
  final List<Package> active;
  final List<Package> staged;
  final List<Package> history;

  const PackageRegistry({
    this.active = const [],
    this.staged = const [],
    this.history = const [],
  });

  /// registry 引用集（仍需保留文件的包）：active ∪ staged ∪ history。
  List<Package> get retained => [...active, ...staged, ...history];

  Package? activeOf(String name) =>
      active.where((p) => p.name == name).firstOrNull;

  Package? stagedOf(String name) =>
      staged.where((p) => p.name == name).firstOrNull;

  PackageRegistry copyWith({
    List<Package>? active,
    List<Package>? staged,
    List<Package>? history,
  }) {
    return PackageRegistry(
      active: active ?? this.active,
      staged: staged ?? this.staged,
      history: history ?? this.history,
    );
  }

  factory PackageRegistry.fromJson(Map<String, dynamic> json) {
    List<Package> parse(String key) {
      final list = json[key] as List<dynamic>? ?? const [];
      return list
          .map((e) => Package.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return PackageRegistry(
      active: parse('active'),
      staged: parse('staged'),
      history: parse('history'),
    );
  }

  Map<String, dynamic> toJson() => {
        'active': active.map((e) => e.toJson()).toList(),
        'staged': staged.map((e) => e.toJson()).toList(),
        'history': history.map((e) => e.toJson()).toList(),
      };
}
