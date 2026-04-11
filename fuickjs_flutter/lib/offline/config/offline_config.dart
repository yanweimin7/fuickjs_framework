class OfflineConfig {
  final String Function() envGetter;
  final Future<Map?> Function() offlinePackagesGetter;
  final Future<Map?> Function() offlineConfigGetter;
  final void Function(String tag, String? msg) logger;
  final String Function()? uaGetter;
  final bool debug;

  const OfflineConfig({
    required this.envGetter,
    required this.offlinePackagesGetter,
    required this.logger,
    required this.debug,
    this.uaGetter,
    required this.offlineConfigGetter,
  });
}
