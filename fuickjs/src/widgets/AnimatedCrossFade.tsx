import React, { ReactNode } from 'react';
import { BaseProps } from './types';

export interface AnimatedCrossFadeProps extends BaseProps {
  crossFadeState: 'showFirst' | 'showSecond';
  duration?: number; // in milliseconds
  firstCurve?: string;
  secondCurve?: string;
  sizeCurve?: string;
  alignment?: string;
}

/**
 * AnimatedCrossFade fades between two children.
 *
 * Use FlutterProps to specify named children:
 * ```tsx
 * <AnimatedCrossFade crossFadeState="showFirst">
 *   <FlutterProps propsKey="firstChild"><MyWidget /></FlutterProps>
 *   <FlutterProps propsKey="secondChild"><OtherWidget /></FlutterProps>
 * </AnimatedCrossFade>
 * ```
 */
export class AnimatedCrossFade extends React.Component<AnimatedCrossFadeProps> {
  render(): ReactNode {
    return React.createElement('AnimatedCrossFade', { ...this.props });
  }
}

export default AnimatedCrossFade;
