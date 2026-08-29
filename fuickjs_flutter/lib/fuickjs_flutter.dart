// FuickJS Flutter 框架公开 API 入口。
//
// 宿主 App 与 community 扩展包统一通过 `package:fuickjs_flutter/fuickjs_flutter.dart`
// 导入所需类型，避免按内部文件路径 import。
//
// native 专用 API 统一以 core/_web_absent.dart（空 library）作为 Web 默认分支，
// 因此同一 URI 会作为条件导出的默认分支出现多次；analyzer 的 duplicate_export
// 在这里是误报。
// ignore_for_file: duplicate_export

// ── 全局配置 ──
export 'core/fuick_config.dart';
export 'core/version.dart';

// ── 容器入口（宿主集成主入口） ──
export 'core/container/fuick_app_view.dart';
export 'core/container/fuick_app_controller.dart' show widgetFactory;
export 'core/container/fuick_app_controller.dart' show nextPageId;
export 'core/container/fuick_app_controller.dart' show FuickAppController;
export 'core/container/fuick_navigation_delegate.dart';
export 'core/container/fuick_page_delegate.dart' show PrewarmEntry;
export 'core/_web_absent.dart'
    if (dart.library.io) 'core/container/dev_fuick_app_page.dart';

// ── 引擎初始化（native 专用；Web 分支导出空） ──
export 'core/_web_absent.dart'
    if (dart.library.io) 'core/engine/engine.dart';

// ── 服务管理（宿主注册、扩展基类） ──
export 'core/service/native_services.dart';
export 'core/service/base_fuick_service.dart';
export 'core/service/native_event_service.dart' show NativeEventService;
export 'core/service/navigation_service.dart' show NavigationService;
export 'core/service/lifecycle_service.dart' show LifecycleService;
export 'core/service/dialog_service.dart' show DialogService;
export 'core/service/toast_service.dart' show ToastService;
export 'core/service/ui_service.dart' show UIService;
export 'core/service/clipboard_service.dart' show ClipboardService;
export 'core/service/device_info_service.dart' show DeviceInfoService;
export 'core/service/local_storage_service.dart' show LocalStorageService;
export 'core/service/timer_service.dart' show TimerService;
export 'core/service/network_service.dart' show NetworkService;
export 'core/service/file_system_service_web.dart'
    if (dart.library.io) 'core/service/file_system_service.dart'
    show FileSystemService;
export 'core/service/websocket_service_web.dart'
    if (dart.library.io) 'core/service/websocket_service.dart'
    show WebSocketService;
export 'core/service/console_service.dart' show ConsoleService;
export 'core/service/sound_service.dart' show SoundService;
export 'core/service/error_report_service.dart' show ErrorReportService;
export 'core/service/error_sink.dart' show ErrorSink, ErrorSinks;
export 'core/service/js_error_bus.dart' show JsErrorBus, JsErrorInfo;
export 'core/widgets/red_box.dart' show RedBoxOverlay;

// ── Widget 扩展（community 包用基类） ──
export 'core/widgets/widget_factory.dart';
export 'core/widgets/parsers/widget_parser.dart';
export 'core/widgets/fuick_command_listener_mixin.dart';
export 'core/widgets/fuick_node.dart' show FuickNode, FuickNodeManager;
export 'core/widgets/widget_utils.dart';
export 'core/widgets/deferred_builder.dart';
export 'core/widgets/fuick_dsl_cache_mixin.dart';
export 'core/widgets/fuick_state_widgets.dart';
export 'core/widgets/fuick_sliver_widgets.dart';
export 'core/container/fuick_action.dart';

// ── 工具扩展 ──
export 'core/utils/extensions.dart';

// ── 日志 ──
export 'core/logger.dart';

// ── Bundle 动态下发（native 专用；Web 分支导出空） ──
export 'core/_web_absent.dart'
    if (dart.library.io) 'offline/offline.dart';
export 'core/_web_absent.dart'
    if (dart.library.io) 'offline/config/offline_config.dart';
export 'core/_web_absent.dart'
    if (dart.library.io) 'offline/domain/entities/package.dart';
export 'core/_web_absent.dart'
    if (dart.library.io) 'offline/domain/entities/bundle_manifest.dart';
