/**
 * 程序化动画控制服务（对应 Flutter 侧 AnimationService）。
 *
 * 动画本身由 Flutter 端 AnimationController 驱动（每帧 Native 渲染，无高频 JS 通信），
 * JS 侧只负责声明（useAnimation 产生 DSL 动画引用）与命令控制（start/stop/reverse/reset/setValue）。
 */
export interface AnimationControlSpec {
  /** 起始值，默认 0 */
  from?: number;
  /** 结束值，默认 1 */
  to?: number;
  /** 时长（毫秒），默认 300 */
  duration?: number;
  /** 曲线名，可选值见 WidgetUtils.curve（ease/easeIn/easeOut/easeInOut/linear/bounceIn...），默认 easeInOut */
  curve?: string;
  /** 循环播放，默认 false */
  loop?: boolean;
  /** loop 时是否往返（reverse: true = 正向→反向循环），默认 false */
  reverse?: boolean;
  /** 渲染完成后自动播放，默认 false */
  autoStart?: boolean;
}

export class AnimationService {
  /**
   * 开始播放动画。
   * @param spec 传入后可覆盖 DSL 引用中的初始 spec（to/duration/curve 等）
   */
  static start(animId: string, pageId: number, spec?: AnimationControlSpec) {
    void dartCallNativeAsync('Animation.start', { animId, pageId, spec: spec ?? null });
  }

  /** 停止动画（保留当前值） */
  static stop(animId: string, pageId: number) {
    void dartCallNativeAsync('Animation.stop', { animId, pageId });
  }

  /** 反向播放（从当前值动画到 from） */
  static reverse(animId: string, pageId: number) {
    void dartCallNativeAsync('Animation.reverse', { animId, pageId });
  }

  /** 重置回初始值（from），立即生效 */
  static reset(animId: string, pageId: number) {
    void dartCallNativeAsync('Animation.reset', { animId, pageId });
  }

  /** 直接设置当前值（跳帧，不带动画） */
  static setValue(animId: string, pageId: number, value: number) {
    void dartCallNativeAsync('Animation.setValue', { animId, pageId, value });
  }

  /** 动画过渡到指定值 */
  static setTo(animId: string, pageId: number, value: number, duration?: number, curve?: string) {
    void dartCallNativeAsync('Animation.setTo', { animId, pageId, value, duration, curve });
  }
}
