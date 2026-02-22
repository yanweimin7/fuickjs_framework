import 'base_fuick_service.dart';
import 'clipboard_service.dart';
import 'console_service.dart';
import 'file_system_service.dart';
import 'native_event_service.dart';
import 'navigation_service.dart';
import 'network_service.dart';
import 'timer_service.dart';
import 'ui_service.dart';

typedef ServiceBuilder = BaseFuickService Function();

class NativeServiceManager {
  static final NativeServiceManager _instance =
      NativeServiceManager._internal();

  factory NativeServiceManager() => _instance;

  final List<ServiceBuilder> serviceBuilders = [];

  NativeServiceManager._internal() {
    registerService(() => TimerService());
    registerService(() => ConsoleService());
    registerService(() => NavigationService());
    registerService(() => UIService());
    registerService(() => NetworkService());
    registerService(() => NativeEventService());
    registerService(() => ClipboardService());
    registerService(() => FileSystemService());
  }

  void registerService(ServiceBuilder serviceBuilder) {
    serviceBuilders.add(serviceBuilder);
  }
}
