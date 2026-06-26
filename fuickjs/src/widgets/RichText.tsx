import React, { ReactNode } from 'react';
import { BaseProps } from './types';

export type RichTextDecoration = 'none' | 'underline' | 'lineThrough' | 'overline';

export type RichTextAlignment = 'top' | 'bottom' | 'middle' | 'aboveBaseline' | 'belowBaseline' | 'baseline';

export interface RichTextSpanStyle {
  color?: string;
  fontSize?: number;
  fontWeight?: 'normal' | 'bold' | string;
  fontStyle?: 'normal' | 'italic';
  decoration?: RichTextDecoration;
  height?: number;
  letterSpacing?: number;
  backgroundColor?: string;
}

export interface RichTextSpan {
  text?: string;
  /**
   * 子 span（递归），用于拼接多段富文本。
   */
  children?: RichTextSpan[];
  style?: RichTextSpanStyle;
  /**
   * 点击事件回调 ID（事件总线名），由 framework 解析。
   */
  onTap?: string;
  /**
   * 内嵌 widget 段落。设为 `'widget'` 时，`widget` 字段为 DSL 子树。
   */
  type?: 'widget';
  /**
   * type === 'widget' 时指定对齐方式。
   */
  alignment?: RichTextAlignment;
  /**
   * type === 'widget' 时，传入要内嵌的 widget DSL：
   *   { type, props, children }
   */
  widget?: {
    type: string;
    props?: Record<string, unknown>;
    children?: unknown;
  };
}

export interface RichTextProps extends BaseProps {
  /**
   * 富文本树（根 TextSpan）。
   */
  text: RichTextSpan;
  textAlign?: 'center' | 'end' | 'justify' | 'left' | 'right' | 'start';
  textDirection?: 'ltr' | 'rtl';
  softWrap?: boolean;
  overflow?: 'clip' | 'fade' | 'ellipsis' | 'visible';
  maxLines?: number;
}

/**
 * 富文本组件。
 *
 * 与 `Text` 的区别：支持多段不同样式的文字、内嵌 widget、可点击 span。
 *
 * @example
 * ```tsx
 * <RichText
 *   text={{
 *     text: 'Hello ',
 *     children: [
 *       { text: 'world', style: { color: '#FF0000', fontWeight: 'bold' } },
 *       { text: '!', style: { decoration: 'underline' } },
 *     ],
 *   }}
 * />
 * ```
 */
export class RichText extends React.Component<RichTextProps> {
  render(): ReactNode {
    return React.createElement('RichText', { ...this.props });
  }
}

export default RichText;
