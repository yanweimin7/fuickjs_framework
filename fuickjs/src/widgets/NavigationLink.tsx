import React, { ReactNode, useRef } from 'react';
import { NavigatorService } from '../services/NavigatorService';
import { usePageId } from '../hooks/hooks';
import GestureDetector from './GestureDetector';

export interface NavigationLinkProps {
  /** 目标路由路径 */
  url: string;
  /** 路由参数 */
  params?: Record<string, unknown>;
  /** 是否使用根 Navigator */
  rootNavigator?: boolean;
  /**
   * onTapDown 时触发预热，onTap 时 push 最多再等待的毫秒数。
   * 默认 50ms。设为 0 禁用 prewarm。
   */
  prewarmMs?: number;
  /** 扩大点击热区的 padding，默认 8 */
  hitSlop?: number;
  children?: ReactNode;
}

/**
 * NavigationLink — 带 prewarm 优化的导航组件。
 *
 * - onTapDown：立即触发目标页面 JS render（fire & forget）
 * - onTap：调用带 prewarmMs 的 push，若 DSL 已就绪直接命中缓存；
 *          若还未就绪则最多再等 prewarmMs ms
 *
 * 用法：
 * ```tsx
 * <NavigationLink url="/demo/container" params={{ id: 1 }}>
 *   <Text text="进入详情" />
 * </NavigationLink>
 * ```
 */
export function NavigationLink({
  url,
  params = {},
  rootNavigator = false,
  prewarmMs = 50,
  hitSlop = 8,
  children,
}: NavigationLinkProps) {
  const pageId = usePageId();
  const tapDownTime = useRef<number>(0);

  const handleTapDown = () => {
    if (prewarmMs <= 0) return;
    tapDownTime.current = Date.now();
    NavigatorService.prewarm(url, params, pageId, prewarmMs);
  };

  const handleTapCancel = () => {
    if (prewarmMs > 0 && tapDownTime.current > 0) {
      tapDownTime.current = 0;
      NavigatorService.cancelPrewarm(url);
    }
  };

  const handleTap = () => {
    if (prewarmMs > 0 && tapDownTime.current > 0) {
      const elapsed = Date.now() - tapDownTime.current;
      tapDownTime.current = 0;
      const remaining = prewarmMs - elapsed;
      if (remaining > 0) {
        NavigatorService.push(url, params, pageId, rootNavigator, remaining);
      } else {
        NavigatorService.push(url, params, pageId, rootNavigator);
      }
    } else {
      NavigatorService.push(url, params, pageId, rootNavigator);
    }
  };

  const padding = hitSlop > 0 ? { all: hitSlop } : undefined;

  return (
    <GestureDetector
      onTapDown={handleTapDown}
      onTapCancel={handleTapCancel}
      onTap={handleTap}
      padding={padding}
    >
      {children}
    </GestureDetector>
  );
}

export default NavigationLink;
