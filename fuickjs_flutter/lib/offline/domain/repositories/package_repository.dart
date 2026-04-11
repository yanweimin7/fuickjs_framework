import '../entities/package.dart';

abstract class PackageRepository {
  Future<List<Package>> loadActivePackages();
  Future<void> saveActivePackages(List<Package> packages);

  String getPackageDir(Package package);
  String getDownloadDir();
  String getPackageFlagFile(Package package);
  Future<bool> validatePackage(Package package);
  Future<void> deletePackage(Package package);
  Future<void> init();
}

abstract class DownloadRepository {
  Future<void> download(
    String url,
    String savePath, {
    void Function(int received, int total)? onProgress,
    void Function()? onComplete,
    void Function(Object error)? onError,
  });

  Future<void> pause(String url);
  Future<void> resume(String url);
  Future<void> cancel(String url);

  double getProgress(String url);
  bool isDownloading(String url);
  bool isCompleted(String url);
}
