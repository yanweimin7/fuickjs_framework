import { NativeEvent } from '../runtime/NativeEvent';

type LifecycleState = 'foreground' | 'background';
type LifecycleListener = (state: LifecycleState) => void;

/**
 * App-level lifecycle notification bridge.
 *
 * Receives `appDidEnterBackground` / `appWillEnterForeground` events from
 * Flutter's [LifecycleService] (WidgetsBindingObserver) and translates them
 * into page-level `notifyLifecycle(visible/invisible)` calls so that existing
 * [useVisible] / [useInvisible] hooks automatically respond to app state
 * transitions with zero code changes.
 *
 * Also exposes direct subscription via [onChange] and [isInBackground] for
 * components that need to know about app state independently.
 */
class LifecycleServiceImpl {
  /** Pages currently visible at the navigation level (not overlay-dialogs). */
  private _visiblePages: Set<number> = new Set();

  /** Whether the app is currently in the background. */
  private _isInBackground: boolean = false;

  /**
   * Snapshot of visible pages taken when the app enters background.
   * Used to restore visibility when the app returns to foreground.
   */
  private _backgroundedPages?: Set<number>;

  /** Registered state-change listeners. */
  private _listeners: Set<LifecycleListener> = new Set();

  /**
   * Bridge function to the renderer's notifyLifecycle.
   * Set by page_render.ts at module init time to avoid circular imports.
   */
  private _notifier: ((pageId: number, type: 'visible' | 'invisible') => void) | null = null;

  constructor() {
    NativeEvent.on('appDidEnterBackground', this._handleBackground.bind(this));
    NativeEvent.on('appWillEnterForeground', this._handleForeground.bind(this));
  }

  // ---------------------------------------------------------------------------
  // Internal — called by page_render.ts
  // ---------------------------------------------------------------------------

  /**
   * Set the lifecycle notification bridge.
   *
   * Called once by [page_render.ts] at module init to wire the renderer's
   * `notifyLifecycle` into this service, avoiding a circular import.
   */
  setNotifier(notifier: (pageId: number, type: 'visible' | 'invisible') => void): void {
    this._notifier = notifier;
  }

  /**
   * Track page-level visibility changes.
   *
   * Called by [page_render.ts]'s `notifyLifecycle()` BEFORE dispatching to
   * the renderer, and also by `destroy()` to clean up tracked pages.
   */
  _onPageLifecycle(pageId: number, type: 'visible' | 'invisible'): void {
    if (type === 'visible') {
      this._visiblePages.add(pageId);
    } else {
      this._visiblePages.delete(pageId);
    }
  }

  // ---------------------------------------------------------------------------
  // App state handlers
  // ---------------------------------------------------------------------------

  private _handleBackground(): void {
    if (this._isInBackground) return;
    this._isInBackground = true;

    // Save a snapshot BEFORE notifying — the notification chain calls
    // _onPageLifecycle('invisible') which clears _visiblePages.
    this._backgroundedPages = new Set(this._visiblePages);

    this._notifyListeners();

    if (this._notifier) {
      for (const pageId of this._backgroundedPages) {
        this._notifier(pageId, 'invisible');
      }
    }
  }

  private _handleForeground(): void {
    if (!this._isInBackground) return;
    this._isInBackground = false;

    const pages = this._backgroundedPages ?? new Set();
    this._backgroundedPages = undefined;

    this._notifyListeners();

    if (this._notifier) {
      for (const pageId of pages) {
        this._notifier(pageId, 'visible');
      }
    }
  }

  private _notifyListeners(): void {
    const state: LifecycleState = this._isInBackground ? 'background' : 'foreground';
    for (const listener of this._listeners) {
      try {
        listener(state);
      } catch (e) {
        console.error('[LifecycleService] Error in listener:', e);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /** Whether the app is currently in the background. */
  get isInBackground(): boolean {
    return this._isInBackground;
  }

  /**
   * Subscribe to app foreground/background state changes.
   *
   * @returns An unsubscribe function.
   */
  onChange(callback: LifecycleListener): () => void {
    this._listeners.add(callback);
    return () => {
      this._listeners.delete(callback);
    };
  }

  /**
   * Query the current app lifecycle state from Flutter.
   *
   * @returns The AppLifecycleState name string (e.g. 'resumed', 'paused').
   */
  async getState(): Promise<string> {
    return await dartCallNativeAsync<string>('Lifecycle.getState', null);
  }
}

export const LifecycleService = new LifecycleServiceImpl();
