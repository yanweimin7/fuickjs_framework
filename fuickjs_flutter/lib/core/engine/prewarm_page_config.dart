/// 预渲染页面描述（native / web 共用，纯数据）。
class PrewarmPageConfig {
  final String path;
  final Map<String, dynamic> params;

  const PrewarmPageConfig(this.path, [this.params = const {}]);
}
