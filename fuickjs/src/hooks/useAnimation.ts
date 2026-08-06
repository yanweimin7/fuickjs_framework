import { useEffect, useMemo, useRef } from 'react';
import { usePageId } from './hooks';
import { NativeEvent } from '../runtime/NativeEvent';
import { refsId } from '../utils/ids';
import { AnimationControlSpec, AnimationService } from '../services/AnimationService';

/**
 * 动画描述（同 AnimationControlSpec，from 默认 0 / to 默认 1 / duration 默认 300 / curve 默认 easeInOut）。
 */
export interface AnimationSpec extends AnimationControlSpec {
  from?: number;
  to?: number;
  duration?: number;
  curve?: string;
  loop?: boolean;
  reverse?: boolean;
  autoStart?: boolean;
}

/**
 * 数值型动画引用：绑定到支持动画的属性（opacity / width / height / rotate / scale / translate）。
 * DSL 序列化为 `{ "@anim": id, "spec": {...} }`，Flutter 侧解析后用 AnimationController 驱动。
 */
export interface AnimationRef {
  '@anim': string;
  spec: AnimationSpec;
}

/** 变换动画引用：`anim.transform.scale()` 等生成，绑定到 Transform 的 scale/rotate/translate 属性。 */
export interface AnimationTransformRef {
  '@anim': string;
  prop: 'scale' | 'scaleX' | 'scaleY' | 'rotate' | 'translateX' | 'translateY';
  spec: AnimationSpec;
}

export interface AnimationHandle {
  /** 动画唯一 ID */
  id: string;
  /**
   * 数值动画引用。绑定到支持动画的属性：
   * `<Opacity opacity={anim.value} />`、`<SizedBox width={anim.value} />`、
   * `<Container height={anim.value} />` 等。
   */
  value: AnimationRef;
  /**
   * 变换动画：`<Transform scale={anim.transform.scale()} rotate={anim.transform.rotate()} />`。
   * scale() 等比缩放（值与 from/to 直接对应）；scaleX/scaleY 独立轴；
   * rotate() 旋转（弧度）；translateX/translateY 位移（像素）。
   */
  transform: {
    scale(): AnimationTransformRef;
    scaleX(): AnimationTransformRef;
    scaleY(): AnimationTransformRef;
    rotate(): AnimationTransformRef;
    translateX(): AnimationTransformRef;
    translateY(): AnimationTransformRef;
  };
  /** 开始播放（可覆盖 spec 参数） */
  start(spec?: Partial<AnimationSpec>): void;
  /** 停止动画（保留当前值） */
  stop(): void;
  /** 反向播放到 from */
  reverse(): void;
  /** 重置回初始值 */
  reset(): void;
  /** 直接设置当前值 */
  setValue(value: number): void;
  /** 动画过渡到指定值 */
  setTo(value: number, duration?: number, curve?: string): void;
  /** 注册动画完成回调（loop 动画不触发），返回取消函数 */
  onComplete(cb: () => void): () => void;
}

const ANIM_DEFAULTS: Required<
  Pick<AnimationSpec, 'from' | 'to' | 'duration' | 'curve' | 'loop' | 'reverse' | 'autoStart'>
> = {
  from: 0,
  to: 1,
  duration: 300,
  curve: 'easeInOut',
  loop: false,
  reverse: false,
  autoStart: false,
};

/**
 * 程序化动画 Hook。
 *
 * 由 Flutter 端 AnimationController 驱动（60fps，无 JS 每帧通信），JS 侧只声明与发命令。
 * 动画值绑定到属性后，DSL 引用中带完整 spec，Flutter 渲染时创建 controller；
 * `anim.start()` 等命令通过 AnimationService 控制。动画完成后推送
 * `animationComplete` 事件（含 animId），可用 `onComplete` 订阅。
 *
 * @example
 * ```tsx
 * function Demo() {
 *   const fade = useAnimation({ from: 0, to: 1, duration: 500, autoStart: true });
 *   const bounce = useAnimation({ to: 0.6, duration: 400, curve: 'easeOut', autoStart: true, loop: true, reverse: true });
 *
 *   return (
 *     <Column>
 *       <Opacity opacity={fade.value}>
 *         <Text text="Fade In" />
 *       </Opacity>
 *       <Transform scale={bounce.transform.scale()}>
 *         <Container width={100} height={100} color="#FF5252" />
 *       </Transform>
 *     </Column>
 *   );
 * }
 * ```
 */
export function useAnimation(spec: AnimationSpec = {}): AnimationHandle {
  const pageId = usePageId();
  const id = useMemo(() => `anim_${pageId}_${refsId()}`, [pageId]);

  // 每次渲染捕获最新 spec；AnimationRef 内容随 spec 变化而重建，
  // 但仅当内容真正变化时才触发 DSL 失效（hostConfig 深度比较）。
  const specRef = useRef<AnimationSpec>(spec);
  specRef.current = { ...ANIM_DEFAULTS, ...spec };
  const currentSpec = specRef.current;

  const specKey = useMemo(
    () =>
      JSON.stringify([
        currentSpec.from,
        currentSpec.to,
        currentSpec.duration,
        currentSpec.curve,
        currentSpec.loop,
        currentSpec.reverse,
        currentSpec.autoStart,
      ]),

    [
      currentSpec.from,
      currentSpec.to,
      currentSpec.duration,
      currentSpec.curve,
      currentSpec.loop,
      currentSpec.reverse,
      currentSpec.autoStart,
    ],
  );

  const value = useMemo<AnimationRef>(
    () => ({ '@anim': id, spec: currentSpec }),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [id, specKey],
  );

  const transformRef = useMemo(
    () => ({
      scale: (): AnimationTransformRef => ({ '@anim': id, prop: 'scale', spec: currentSpec }),
      scaleX: (): AnimationTransformRef => ({ '@anim': id, prop: 'scaleX', spec: currentSpec }),
      scaleY: (): AnimationTransformRef => ({ '@anim': id, prop: 'scaleY', spec: currentSpec }),
      rotate: (): AnimationTransformRef => ({ '@anim': id, prop: 'rotate', spec: currentSpec }),
      translateX: (): AnimationTransformRef => ({ '@anim': id, prop: 'translateX', spec: currentSpec }),
      translateY: (): AnimationTransformRef => ({ '@anim': id, prop: 'translateY', spec: currentSpec }),
    }),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [id, specKey],
  );

  // 完成回调：动画完成后 Native 推送 'animationComplete' 事件（自动随页面销毁清理）
  const onCompleteRef = useRef<(() => void) | null>(null);
  useEffect(() => {
    return NativeEvent.on(
      'animationComplete',
      (data) => {
        const payload = data as { animId?: string } | null;
        if (payload && payload.animId === id) {
          onCompleteRef.current?.();
        }
      },
      pageId,
    );
  }, [id, pageId]);

  return {
    id,
    value,
    transform: transformRef,
    start: (override?: Partial<AnimationSpec>) =>
      AnimationService.start(id, pageId, override ? { ...currentSpec, ...override } : undefined),
    stop: () => AnimationService.stop(id, pageId),
    reverse: () => AnimationService.reverse(id, pageId),
    reset: () => AnimationService.reset(id, pageId),
    setValue: (v: number) => AnimationService.setValue(id, pageId, v),
    setTo: (v: number, duration?: number, curve?: string) => AnimationService.setTo(id, pageId, v, duration, curve),
    onComplete: (cb: () => void) => {
      onCompleteRef.current = cb;
      return () => {
        onCompleteRef.current = null;
      };
    },
  };
}
