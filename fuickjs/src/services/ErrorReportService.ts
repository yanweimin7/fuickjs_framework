import type { ErrorSource } from '../core/ErrorHandler';

export interface ErrorReportPayload {
  message: string;
  stack?: string;
  source: ErrorSource;
  detail?: unknown;
  timestamp: number;
}

/**
 * 专用错误上报服务。
 *
 * JS 侧 [ErrorHandler] 捕获到未处理异常时，通过此服务发送结构化 payload 到
 * Flutter 侧的 `ErrorReportService`，由 Flutter 端做 sourcemap 还原并打印。
 *
 * 与 [ConsoleService] 分离：console 只负责纯日志转发，错误堆栈还原收敛在此通道。
 */
export class ErrorReportService {
  /**
   * 上报错误到 Flutter 侧。
   *
   * @param error 错误对象或任意值
   * @param source 错误来源（render / event / timer / promise / runtime）
   * @param detail 附加上下文（pageId / refId / index 等）
   */
  static report(error: unknown, source: ErrorSource, detail?: unknown): void {
    const payload: ErrorReportPayload = {
      message: ErrorReportService.formatMessage(error),
      stack: error instanceof Error ? error.stack : undefined,
      source,
      detail,
      timestamp: Date.now(),
    };
    try {
      dartCallNative('ErrorReport.report', payload);
    } catch {
      // 兜底：dartCallNative 不可用时退回 console.error
      console.error(payload.message, payload.stack);
    }
  }

  private static formatMessage(error: unknown): string {
    if (error instanceof Error) return error.message;
    if (typeof error === 'string') return error;
    try {
      return JSON.stringify(error);
    } catch {
      return String(error);
    }
  }
}
