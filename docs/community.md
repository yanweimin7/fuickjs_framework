# Community 扩展包

`fuickjs_community/` 提供官方维护的可选扩展，按需引入，不强制纳入核心框架。每个包独立发布到 npm（`@fuickjs-community/xxx`），Flutter 侧实现放在包内的 `flutter/` 目录。

---

## 快速集成步骤（通用）

所有 community 包的接入流程一致：

1. **JS 侧**：`npm install @fuickjs-community/xxx`，在代码中导入使用
2. **Flutter 侧**：按包说明在 `pubspec.yaml` 追加依赖，将 `flutter/xxx_service.dart` / `flutter/xxx_parser.dart` 软链或复制到宿主 App
3. **注册**：在 `main.dart` 的 `main()` 中，服务类用 `NativeServiceManager().registerService(() => XxxService())`，Widget Parser 用 `widgetFactory.register(XxxParser())`

---

## 服务类（Native Services）

### Haptics — 触觉反馈

**包名**：`@fuickjs-community/haptics`  
**Flutter 依赖**：无（Flutter SDK 自带）

```ts
import { Haptics } from '@fuickjs-community/haptics';

Haptics.impact('medium');          // 'light' | 'medium' | 'heavy' | 'rigid' | 'soft'
Haptics.selection();               // 适合滚轮切换
Haptics.notification('success');   // 'success' | 'warning' | 'error'
Haptics.vibrate(200);              // Android 专用，毫秒
```

---

### Launcher — 系统跳转

**包名**：`@fuickjs-community/launcher`  
**Flutter 依赖**：`url_launcher: ^6.2.0`

```ts
import { Launcher } from '@fuickjs-community/launcher';

await Launcher.openUrl('https://example.com');
await Launcher.call('10086');
await Launcher.sms('10086', 'hello');
await Launcher.email({ to: 'a@b.com', subject: '主题', body: '正文' });
await Launcher.openAppSettings();
const ok = await Launcher.canOpenUrl('weixin://');
```

> **iOS**：`Info.plist` 的 `LSApplicationQueriesSchemes` 需声明要查询的 URL Scheme  
> **Android**：API 30+ 需在 `AndroidManifest.xml` 的 `<queries>` 中声明 intent

---

### Connectivity — 网络状态

**包名**：`@fuickjs-community/connectivity`  
**Flutter 依赖**：`connectivity_plus: ^6.0.0`

```ts
import { Connectivity } from '@fuickjs-community/connectivity';
import { NativeEvent } from 'fuickjs';

const type = await Connectivity.getNetworkType(); // 'wifi' | '4g' | 'ethernet' | 'none' | 'unknown'
const online = await Connectivity.isConnected();

Connectivity.startListener();
NativeEvent.on('networkStatusChange', (data) => {
  console.log(data.networkType, data.isConnected);
});
// 退出时
Connectivity.stopListener();
```

---

### AppInfo — 应用信息

**包名**：`@fuickjs-community/app_info`  
**Flutter 依赖**：`package_info_plus: ^8.0.0`

```ts
import { AppInfo } from '@fuickjs-community/app_info';

const info = await AppInfo.get();
// info.appName / info.version / info.buildNumber / info.packageName
```

结果在 JS 侧缓存，多次调用只请求一次 Native。

---

### Permissions — 运行时权限

**包名**：`@fuickjs-community/permissions`  
**Flutter 依赖**：`permission_handler: ^11.0.0`

```ts
import { Permissions } from '@fuickjs-community/permissions';

const status = await Permissions.check('camera');
const granted = await Permissions.isGranted('camera');
const result = await Permissions.request('camera');
const results = await Permissions.requestMultiple(['camera', 'microphone', 'photos']);
```

**支持权限**：`camera` / `microphone` / `photos` / `photosAddOnly` / `notification` / `locationWhenInUse` / `locationAlways` / `contacts` / `calendar` / `reminders` / `sensors` / `bluetooth` / `storage`

**返回状态**：`granted` / `denied` / `restricted` / `permanentlyDenied` / `limited` / `provisional`

> 需在 `Info.plist` / `AndroidManifest.xml` 中添加对应权限声明

---

### Share — 系统分享

**包名**：`@fuickjs-community/share`  
**Flutter 依赖**：`share_plus: ^9.0.0`

```ts
import { Share } from '@fuickjs-community/share';

await Share.text('Hello FuickJS!', '可选标题');
await Share.files(['/path/to/file.png'], '附带文字');
await Share.share({ text: '内容', subject: '标题', files: ['/path/to/a.pdf'] });
```

---

### Media — 图片/视频选择

**包名**：`@fuickjs-community/media`  
**Flutter 依赖**：`image_picker: ^1.1.0`, `cached_network_image: ^3.4.0`

```ts
import { Media } from '@fuickjs-community/media';

const result = await Media.chooseImage(3, ['album']);
// result.tempFilePaths: string[]

const video = await Media.chooseVideo(['album', 'camera']);
// video.tempFilePath / video.size / video.type

await Media.previewImage(['https://example.com/a.jpg'], 0);
```

> iOS 需在 `Info.plist` 添加 `NSPhotoLibraryUsageDescription` / `NSCameraUsageDescription` / `NSMicrophoneUsageDescription`

---

## Widget 组件

### VideoPlayer — 视频播放

**包名**：`@fuickjs-community/video_player`  
**Flutter 依赖**：`video_player: ^2.9.0`  
**注册**：`widgetFactory.register(VideoPlayerParser())`

```tsx
import { VideoPlayer } from '@fuickjs-community/video_player';

const playerRef = useRef<VideoPlayer>(null);

<VideoPlayer
  ref={playerRef}
  refId="my_player"
  url="https://example.com/demo.mp4"
  autoPlay={false}
  looping={true}
  showControls={false}
  muted={false}
  onInitialized={(info) => console.log('duration:', info.duration)}
  onVideoEnd={() => console.log('ended')}
  onPause={() => console.log('paused')}
  onError={(e) => console.error(e.error)}
/>
```

**命令式控制**（需传 `refId`）：

```ts
playerRef.current?.play()
playerRef.current?.pause()
playerRef.current?.stop()
playerRef.current?.seekTo(3000)       // 毫秒
playerRef.current?.setVolume(0.5)     // 0.0 ~ 1.0
playerRef.current?.setLooping(true)
playerRef.current?.setPlaybackSpeed(1.5)
```

**Props**：

| Prop | 类型 | 说明 |
|------|------|------|
| `refId` | `string` | 命令式控制必须提供 |
| `url` | `string` | 网络视频 URL |
| `asset` | `string` | Flutter Asset 路径 |
| `autoPlay` | `boolean` | 默认 `false` |
| `looping` | `boolean` | 默认 `false` |
| `showControls` | `boolean` | 默认 `false` |
| `muted` | `boolean` | 默认 `false` |
| `onInitialized` | `(info) => void` | `info.duration` (ms), `info.size` |
| `onVideoEnd` | `() => void` | 播放结束 |
| `onPause` | `() => void` | 暂停 |
| `onError` | `(e) => void` | `e.error` 错误描述 |

---

### VisibilityDetector — 可见性检测

**包名**：`@fuickjs-community/visibility_detector`  
**Flutter 依赖**：`visibility_detector: ^0.4.0+2`  
**注册**：`widgetFactory.register(VisibilityDetectorParser())`

```tsx
import { VisibilityDetector } from '@fuickjs-community/visibility_detector';

<VisibilityDetector
  refId="tracker-1"
  onVisibilityChanged={(info) => {
    console.log('visible fraction:', info.visibleFraction); // 0.0 ~ 1.0
  }}
>
  <Text text="Tracked content" />
</VisibilityDetector>
```

> 必须提供 `refId`，否则无法跟踪状态

---

### WebView — 内嵌网页

**包名**：`@fuickjs-community/web_view`  
**Flutter 依赖**：`flutter_inappwebview: ^6.1.5`  
**注册**：`widgetFactory.register(WebViewParser())`

```tsx
import { WebView } from '@fuickjs-community/web_view';

const webViewRef = useRef<WebView>(null);

<WebView
  ref={webViewRef}
  refId="main_webview"
  url="https://flutter.dev"
  javaScriptEnabled={true}
  onTitleChanged={(title) => setTitle(title)}
  onProgressChanged={(progress) => setProgress(progress)}
  onLoadStart={(url) => console.log('start:', url)}
  onLoadStop={(url) => console.log('stop:', url)}
  onLoadError={(info) => console.error(info.code, info.message)}
  onConsoleMessage={(msg) => console.log('[WebView]', msg)}
/>
```

**命令式控制**：

```ts
webViewRef.current?.loadUrl('https://example.com')
webViewRef.current?.reload()
webViewRef.current?.goBack()
webViewRef.current?.goForward()
webViewRef.current?.evaluateJavascript('document.title')
```

> 不传 `refId` 时组件自动生成内部 ID，命令式控制仍可正常使用。`refId` 作用域隔离在各 bundle 的 `commandBus` 内，多 bundle 并发运行不会冲突。

> **Android 返回键**：组件内置 `PopScope`，有 WebView 历史时返回键优先 `goBack()`，无历史时自动 `Navigator.pop()` 回到上一页。

**Props**：

| Prop | 类型 | 说明 |
|------|------|------|
| `url` | `string` | 初始加载 URL（必填）|
| `refId` | `string` | 命令式控制 ID，可选，缺省自动生成 |
| `javaScriptEnabled` | `boolean` | 默认 `true` |
| `onLoadStart` | `(url: string) => void` | 开始加载 |
| `onLoadStop` | `(url: string) => void` | 加载完成 |
| `onLoadError` | `(info: { url, code, message }) => void` | 加载失败 |
| `onProgressChanged` | `(progress: number) => void` | 进度 0~100 |
| `onTitleChanged` | `(title: string) => void` | 页面标题变化 |
| `onConsoleMessage` | `(message: string) => void` | WebView 内 console 输出 |

---

## 添加新 Community 包

包结构规范：

```
fuickjs_community/<pkg_name>/
├── package.json              # name: @fuickjs-community/<pkg_name>
├── tsconfig.json             # extends ../tsconfig.base.json，include ../fuickjs.d.ts
├── src/
│   ├── <Name>.ts(x)          # JS 侧实现
│   └── index.ts              # 统一导出
└── flutter/
    ├── <name>_service.dart   # 或 <name>_parser.dart
    └── pubspec_snippet.yaml  # 宿主需追加的 Flutter 依赖
```

- **纯服务**（无 UI）：继承 `BaseFuickService`，在 `NativeServiceManager` 注册
- **Widget 组件**：继承 `WidgetParser`，通过 `widgetFactory.register()` 注册；需命令式控制时实现 `FuickCommandListenerMixin`
- Demo App 中：`fuickjs_demo/app/lib/community/` 软链到 flutter 实现文件，`fuickjs_demo/js/package.json` 通过 `file:` 引用本地包
