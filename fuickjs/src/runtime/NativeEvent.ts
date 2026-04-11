import { NativeEventService } from '../services/NativeEventService';
import { Fuick } from './Fuick';

type EventHandler = (data: unknown) => void;

class NativeEventImpl {
  private listeners: Map<string, EventHandler[]> = new Map();

  constructor() {
    // 暴露 receive 方法给 Native 调用
    // Native 端通过 ctx.invoke('NativeEvent', 'receive', [event, data]) 调用
  }

  /**
   * 监听事件
   * @param event 事件名称
   * @param callback 回调函数
   * @returns 取消监听的函数
   */
  on(event: string, callback: EventHandler): () => void {
    if (!this.listeners.has(event)) {
      this.listeners.set(event, []);
    }
    this.listeners.get(event)!.push(callback);
    return () => this.off(event, callback);
  }

  /**
   * 移除事件监听
   * @param event 事件名称
   * @param callback 回调函数
   */
  off(event: string, callback: EventHandler) {
    const callbacks = this.listeners.get(event);
    if (callbacks) {
      const index = callbacks.indexOf(callback);
      if (index > -1) {
        callbacks.splice(index, 1);
      }
      if (callbacks.length === 0) {
        this.listeners.delete(event);
      }
    }
  }

  /**
   * 发送事件（同时发送给 JS 内部监听器和 Native）
   * @param event 事件名称
   * @param data 事件数据
   */
  emit(event: string, data?: unknown) {
    // 1. 发送给 Native
    NativeEventService.emit(event, data);

    // 2. 触发本地监听器 (可选，取决于是否需要回环)
    this.dispatchLocal(event, data);
  }

  /**
   * 仅触发本地监听器（不发送给 Native）
   * 主要供 Native 调用 receive 时使用
   */
  dispatchLocal(event: string, data?: unknown) {
    const callbacks = this.listeners.get(event);
    if (callbacks) {
      // 复制一份防止在回调中修改 listeners 导致的问题
      [...callbacks].forEach((callback) => {
        try {
          callback(data);
        } catch (e) {
          console.error(`[NativeEvent] Error in listener for event "${event}":`, e);
        }
      });
    }
  }

  /**
   * 接收来自 Native 的事件
   * @param event 事件名称
   * @param data 事件数据
   */
  receive(event: string, data?: unknown) {
    this.dispatchLocal(event, data);
  }
}

export const NativeEvent = new NativeEventImpl();

// 暴露给 Native
Fuick.expose('NativeEvent', NativeEvent);
