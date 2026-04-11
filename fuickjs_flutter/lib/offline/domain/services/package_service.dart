import '../../util/logger.dart';
import '../entities/package.dart';
import '../repositories/package_repository.dart';

class PackageService {
  final PackageRepository _repository;

  PackageService(this._repository);

  final List<Package> _activePackages = [];
  List<Package> _remotePackages = [];
  List<Package> _internalPackages = [];
  bool _initialized = false;

  List<Package> get activePackages => List.from(_activePackages);
  List<Package> get remotePackages => List.from(_remotePackages);
  List<Package> get internalPackages => List.from(_internalPackages);

  bool isInternal(Package package) {
    return _internalPackages.any((p) => p.isSameVersion(package));
  }

  Future<void> init() async {
    if (_initialized) {
      return;
    }
    _initialized = true;

    final loadedPackages = await _repository.loadActivePackages();
    final invalidPackages = <Package>[];

    for (final pkg in loadedPackages) {
      if (await _repository.validatePackage(pkg)) {
        _activePackages.add(pkg);
      } else {
        invalidPackages.add(pkg);
      }
    }

    if (invalidPackages.isNotEmpty) {
      logger(() =>
          'Invalid packages found: ${invalidPackages.map((e) => e.name)}');
    }

    logger(() =>
        'Active packages: ${_activePackages.map((e) => '${e.name}:${e.versionShasumName}')}');

    if (invalidPackages.isNotEmpty) {
      await _repository.saveActivePackages(_activePackages);
    }
  }

  void setRemotePackages(List<Package> packages) {
    _remotePackages = List.from(packages);
    logger(() => 'Remote packages set: ${packages.length}');
  }

  void setInternalPackages(List<Package> packages) {
    _internalPackages = List.from(packages);
    logger(() => 'Internal packages set: ${packages.length}');
  }

  Future<void> activatePackages(List<Package> packages) async {
    if (packages.isEmpty) return;

    _activePackages
        .removeWhere((e1) => packages.any((e2) => e2.name == e1.name));
    _activePackages.addAll(packages);

    await _repository.saveActivePackages(_activePackages);

    for (final pkg in packages) {
      logger(() => 'Activated: ${pkg.name} ${pkg.versionShasumName}');
    }
  }

  Future<void> deactivatePackages(List<Package> packages) async {
    if (packages.isEmpty) return;

    _activePackages
        .removeWhere((e1) => packages.any((e2) => e2.name == e1.name));
    await _repository.saveActivePackages(_activePackages);

    for (final pkg in packages) {
      logger(() => 'Deactivated: ${pkg.name}');
    }
  }

  bool isActive(String name, String versionShasumName) {
    return _activePackages
        .any((e) => e.name == name && e.versionShasumName == versionShasumName);
  }

  Package? getActivePackage(String name) {
    try {
      return _activePackages.firstWhere((e) => e.name == name);
    } catch (_) {
      return null;
    }
  }
}
