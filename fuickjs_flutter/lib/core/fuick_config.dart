class FuickConfig {
  static final FuickConfig _instance = FuickConfig._internal();
  factory FuickConfig() => _instance;
  FuickConfig._internal();

  static Future<dynamic> Function(String path, Map<String, dynamic> params)?
      onRootPush;
  static Function()? onRootPop;
  static Function(dynamic result)? onRootPopWithResult;
}
