import { elementToDsl } from '../core/page_render';
import React from 'react';

export class OverlayService {
  static show(key: string, element: React.ReactNode, pageId?: number): void {
    // If pageId is not provided, we might default to -1 or some global ID,
    // but elementToDsl requires a pageId to generate IDs and register callbacks.
    // If the user doesn't provide pageId, the overlay will be rendered but events might not work
    // or might conflict if we use a dummy ID.
    // However, usually we want to attach to the current page.
    // Since we don't have global context access here easily without passing it,
    // we require pageId for interactive overlays.
    // For static overlays, any ID might work.

    const targetPageId = pageId ?? -1;
    const dsl = elementToDsl(targetPageId, element);
    dartCallNative('Overlay.show', { key, dsl, pageId: targetPageId });
  }

  static hide(key: string): void {
    dartCallNative('Overlay.hide', key);
  }

  /** 显示 loading 遮罩（不需要 DSL） */
  static showLoading(key: string, message?: string): void {
    dartCallNative('Overlay.show', { key, type: 'loading', message: message ?? '' });
  }
}
