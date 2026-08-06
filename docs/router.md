# 路由系统 (Router)

FuickJS 提供了一套轻量的路由系统，支持路径参数、命名路由、路由守卫、重定向与 404 兜底。

路由职责分层：

- **JS 侧**：路由声明、路径匹配、参数解析、守卫执行
- **Flutter 侧**：页面栈管理、转场动画、原生 Navigator 集成（[FuickNavigationDelegate](../fuickjs_flutter/lib/core/container/fuick_navigation_delegate.dart)）

## 快速开始

### 1. 旧 API（仍然支持）

最简单的用法，与历史代码完全兼容：

```typescript
import { Router } from 'fuickjs';

Router.register('/', (params) => <HomePage />);
Router.register('/news', (params) => <NewsPage />);
Router.register('/detail', (params) => <DetailPage params={params} />);
```

### 2. 声明式配置（推荐）

支持路径参数、命名路由、守卫、重定向、meta 元信息：

```typescript
Router.config({
  routes: [
    { path: '/', component: () => <HomePage /> },
    { path: '/news', component: () => <NewsPage /> },
    // 路径参数：/news/123 → params.id = '123'
    { path: '/news/:id', component: (p) => <NewsDetail id={p.id} /> },
    // 命名路由：可通过 pushByName('detail', { id: 1 }) 跳转
    { path: '/detail/:id', name: 'detail', component: (p) => <DetailPage id={p.id} /> },
    // 重定向
    { path: '/old-home', redirect: '/' },
    // 受保护页面（配合守卫使用）
    { path: '/profile', component: () => <ProfilePage />, meta: { requiresAuth: true } },
  ],
  guards: [authGuard],
  notFound: () => <NotFoundPage />,
});
```

`register` 与 `config` 可混用，路由按注册顺序匹配。

## 路径参数

路径中以 `:` 开头的段视为参数占位：

| 模式                     | 匹配              | 不匹配                         | params                      |
| ------------------------ | ----------------- | ------------------------------ | --------------------------- |
| `/news/:id`              | `/news/123`       | `/news` / `/news/123/comments` | `{ id: '123' }`             |
| `/user/:id/post/:postId` | `/user/5/post/42` | `/user/5`                      | `{ id: '5', postId: '42' }` |
| `/news`                  | `/news`           | `/news/123`                    | `{}`                        |

参数值会自动 `decodeURIComponent`。调用方传入的 params 会与路径参数合并（调用方优先）：

```typescript
nav.push("/news/123", { ref: "search" });
// 组件收到的 params: { id: '123', ref: 'search' }
```

## 跳转 API

### useNavigator hook

在组件内获取导航器：

```typescript
const nav = useNavigator();

// 基础跳转
nav.push('/news/123');
nav.push('/news/123', { ref: 'search' });

// 跳转并等待 pop(result) 返回
const result = await nav.push('/picker', { type: 'image' });
console.log(result); // { uri: '...' }

// 替换当前路由（不可返回）
nav.replace('/login');

// 重定向（语义同 replace，用于主动重定向场景）
nav.redirect('/login');

// 命名路由跳转
nav.pushByName('detail', { id: 123 });

// 弹出
nav.pop();
nav.pop({ userId: 123 }); // 带返回结果
nav.popTo('/');           // 弹出到指定路径
nav.popAll();             // 回到根页面

// 弹窗
nav.showDialog(<CustomDialog />);
nav.showBottomSheet(<Sheet />, { maxHeight: 400 });
```

### NavigatorService（非组件场景）

在组件外（service / 工具函数）可直接用 `NavigatorService`，需手动传 `pageId`：

```typescript
import { NavigatorService } from "fuickjs";

NavigatorService.push("/login", null, currentpageId);
```

## 守卫 (Guards)

守卫用于在跳转前进行鉴权、日志、参数校验等。支持同步或异步。

### 守卫签名

```typescript
type Guard = (
  to: RouteLocation,
  from: RouteLocation | null,
) => Promise<GuardResult> | GuardResult;

type GuardResult =
  | boolean // true 放行，false 取消
  | void // 等价于 true
  | string // 重定向到该 path
  | { path: string; params?: unknown }; // 重定向带参数
```

### 全局守卫

对所有跳转生效，按注册顺序执行，任一守卫返回非放行值即短路：

```typescript
const authGuard = (to, from) => {
  if (to.meta?.requiresAuth && !isLoggedIn()) {
    return '/login'; // 重定向到登录页
  }
  return true;
};

Router.config({ routes: [...], guards: [authGuard] });
// 或动态追加
Router.addGuard(authGuard);
```

### 路由级守卫

仅对当前路由生效，在全局守卫之后执行：

```typescript
Router.config({
  routes: [
    {
      path: '/admin',
      component: () => <AdminPage />,
      beforeEnter: async (to, from) => {
        const ok = await checkAdmin();
        return ok ? true : false;
      },
    },
  ],
});
```

### 执行顺序

`runGuards(to, from)` 按以下顺序执行：

1. **redirect**：路由配置的 `redirect` 字段（静态字符串或函数），命中即重定向，跳过后续守卫
2. **全局守卫**：`guards` 数组，按顺序执行
3. **路由级守卫**：`beforeEnter`

### 首屏守卫

首屏（`initialRoute`）也会跑守卫。`from` 为 `null`。

- 守卫**拒绝**：渲染 fallback UI（可通过 `setRouteGuardFallback` 自定义）
- 守卫**重定向**：触发 `Navigator.pushReplace` 替换当前路由，本页渲染 loading 占位
- 守卫**通过**：正常渲染

```typescript
import { setRouteGuardFallback } from 'fuickjs';

setRouteGuardFallback((to) => (
  <Column mainAxisAlignment="center" crossAxisAlignment="center">
    <Text text="无访问权限" fontSize={20} color="#D32F2F" />
    <Text text={`请先登录后访问 ${to.path}`} fontSize={14} color="#666" />
  </Column>
));
```

## 重定向 (Redirect)

两种方式：

```typescript
// 静态重定向
{ path: '/old-home', redirect: '/' }

// 函数重定向（可根据 to 动态决定）
{
  path: '/legacy/:id',
  redirect: (to) => ({ path: '/new/' + to.params.id }),
}
```

重定向在守卫之前执行，不会触发守卫。重定向目标会重新走完整的 resolve + guard 流程。

> 注意：避免配置循环重定向（A→B→A），否则会无限递归。

## 404 兜底

两种方式：

```typescript
// 方式 1：全局 notFound 配置
Router.config({ routes: [...], notFound: () => <NotFoundPage /> });

// 方式 2：路由表中放 path:'*'
Router.config({
  routes: [
    { path: '*', component: () => <NotFoundPage /> },
  ],
});
```

未配置 notFound 且未匹配任何路由时，显示框架默认 404 UI（"Route xxx not found"）。

## Native Fallback（混合开发）

混合开发场景下，JS 可能需要直接打开原生页面（如宿主 go_router 中注册的路由）。
`nativeFallback` **默认开启**：未匹配到任何 JS 路由的路径不再报错，而是交给 Native 侧处理：

```typescript
// 默认已开启，无需配置
const res = await navigator.push('/native_page', { data: 'hello' });
console.log(res); // 原生页面 pop 时携带的返回结果
```

如需关闭：

```typescript
Router.config({
  routes: [...],
  nativeFallback: false,
});
```

注意事项：

- 仅对 `navigator.push` / `pushReplace` 生效；`pushByName` 找不到命名路由仍按原逻辑返回 null
- 透传时强制走根 Navigator（`rootNavigator: true`），因为原生页面位于宿主路由栈
- `notFound` 优先级更高：配置了 `notFound` 时未匹配路径渲染 404 页，不会走 nativeFallback

## useRoute hook

获取当前页面的路由位置信息：

```typescript
const route = useRoute();
if (route) {
  console.log(route.path); // '/news/123'
  console.log(route.params); // { id: '123' }
  console.log(route.name); // 'detail'（若配置了 name）
  console.log(route.meta); // { requiresAuth: true }
}
```

`useRoute` 在守卫通过后、组件渲染前记录，组件首次渲染时即可读取。若页面未通过守卫（渲染了 fallback），返回 `null`。

## 类型定义

```typescript
interface RouterConfig {
  routes: RouteConfig[];
  guards?: Guard[];
  notFound?: ComponentFactory;
  nativeFallback?: boolean; // 未匹配路径交给 Native 侧处理（默认 true，混合开发）
}

interface RouteConfig {
  path: string; // 路径模式，支持 :param；'*' 为 404
  component?: ComponentFactory;
  redirect?:
    | string
    | ((to: RouteLocation) => string | { path: string; params?: unknown });
  name?: string; // 命名路由
  meta?: Record<string, unknown>; // 业务自定义元信息
  beforeEnter?: Guard; // 路由级守卫
  prewarmMs?: number; // 预热时长（ms）
}

interface RouteLocation {
  path: string; // 完整路径
  matched: RouteConfig; // 匹配到的路由配置
  params: Record<string, unknown>; // 合并后的参数
  name?: string;
  meta: Record<string, unknown>;
}
```

## 与 Flutter 侧的关系

JS 侧完成路由解析与守卫后，调用 `dartCallNativeAsync('Navigator.push', ...)` 通知 Flutter 创建页面。Flutter 侧由 [FuickNavigationDelegate](../fuickjs_flutter/lib/core/container/fuick_navigation_delegate.dart) 负责：

- 维护 Navigator 路由栈（push / pop / pushReplace / popTo / popAll）
- 转场动画（cupertino / materialZoom / fadeUpwards / platformAdaptive / none）
- 弹窗路由（DialogRoute / ModalBottomSheetRoute）
- 预热机制（prewarm）
- 宿主集成钩子（`onRootPush`，可对接 go_router / auto_route）

pageId 由 Flutter 侧全局计数器 `nextPageId`（[fuick_app_controller.dart](../fuickjs_flutter/lib/core/container/fuick_app_controller.dart)）分配，JS 侧通过 `Router.recordLocation(pageId, location)` 维护 pageId → RouteLocation 映射，用于守卫的 `from` 参数。

## 完整示例

参考 demo 应用的 [RouterDemo.tsx](../fuickjs_demo/js/src/demos/RouterDemo.tsx) 与 [app.ts](../fuickjs_demo/js/src/app.ts) 路由注册部分，演示了：

- 路径参数 `/demo/router/user/:id`
- 命名路由 `pushByName('user', { id: 789 })`
- 守卫保护页面（`meta.requiresAuth` + 全局守卫）
- 重定向 `/demo/router/old → /demo/router`
- 404 兜底（访问不存在的路径）
- `pushAndWait` 等待子页面返回结果
