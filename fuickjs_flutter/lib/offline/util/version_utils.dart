/// 语义化版本工具：用于 minAppVersion 兼容性判断与版本排序。
class VersionUtils {
  /// 比较两个 semver 字符串。
  /// 返回负数表示 a < b，0 表示相等，正数表示 a > b。
  /// 仅比较数字主体（major.minor.patch...），忽略预发布/构建元数据后缀。
  static int compare(String a, String b) {
    final pa = _parse(a);
    final pb = _parse(b);
    final len = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < len; i++) {
      final na = i < pa.length ? pa[i] : 0;
      final nb = i < pb.length ? pb[i] : 0;
      if (na != nb) return na < nb ? -1 : 1;
    }
    return 0;
  }

  /// 当前 App 版本是否满足 minAppVersion 约束（appVersion >= minAppVersion）。
  /// minAppVersion 为空时视为无约束，恒满足。
  static bool isAppVersionSatisfied(String appVersion, String? minAppVersion) {
    if (minAppVersion == null || minAppVersion.isEmpty) return true;
    return compare(appVersion, minAppVersion) >= 0;
  }

  static List<int> _parse(String version) {
    // 去掉预发布/构建元数据（- 或 + 之后）。
    var core = version.trim();
    final dashOrPlus = core.indexOf(RegExp(r'[-+]'));
    if (dashOrPlus >= 0) core = core.substring(0, dashOrPlus);
    if (core.isEmpty) return const [0];
    return core.split('.').map((s) {
      return int.tryParse(s.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    }).toList();
  }
}
