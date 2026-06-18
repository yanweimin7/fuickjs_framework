import '../entities/package.dart';
import '../value_objects/package_registry.dart';

abstract class PackageRepository {
  Future<void> init();

  /// 包状态机读写。
  Future<PackageRegistry> loadRegistry();
  Future<void> saveRegistry(PackageRegistry registry);

  String getPackageDir(Package package);
  String getStagingDir(Package package);
  String getDownloadDir();
  String getPackageFlagFile(Package package);

  /// packages/ 根目录与 offline/ 根目录（清理用）。
  String get packagesRootDir;
  String get offlineRootDir;

  /// 内置 bundle zip 资源路径。
  String builtinBundleZipAsset(String name);

  /// 校验包是否已完整落盘（flag 文件存在）。
  Future<bool> validatePackage(Package package);

  Future<void> deletePackage(Package package);
  Future<void> deleteStaging(Package package);

  /// 原子提升：staging 目录 → packages 目录，并写完成 flag。
  Future<void> promoteStaging(Package package);
}
