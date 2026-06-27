import 'base_fuick_service.dart';
import 'clipboard_service.dart';
import 'console_service.dart';
import 'device_info_service.dart';
import 'error_report_service.dart';
import 'file_system_service.dart';
import 'native_event_service.dart';
import 'navigation_service.dart';
import 'network_service.dart';
import 'lifecycle_service.dart';
import 'local_storage_service.dart';
import 'timer_service.dart';
import 'toast_service.dart';
import 'ui_service.dart';
import 'dialog_service.dart';
import 'websocket_service.dart';
import 'sound_service.dart';

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
    registerService(() => LocalStorageService());
    registerService(() => DeviceInfoService());
    registerService(() => ToastService());
    registerService(() => DialogService());
    registerService(() => WebSocketService());
    registerService(() => SoundService());
    registerService(() => LifecycleService());
    registerService(() => ErrorReportService());
  }

  void registerService(ServiceBuilder serviceBuilder) {
    serviceBuilders.add(serviceBuilder);
  }
}
