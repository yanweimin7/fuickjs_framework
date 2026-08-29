import 'sync_fuick_service.dart';

/// Web 端文件系统服务：浏览器无原生文件系统访问（本框架不引入 IndexedDB/OPFS
/// 抽象）。所有 FileSystem.* 方法不可用——JS 侧调用将命中「no handler registered」。
class FileSystemService extends SyncFuickService {
  @override
  String get name => 'FileSystem';

  FileSystemService();
}
