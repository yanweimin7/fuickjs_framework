import React, { ReactNode } from 'react';
import { BaseProps } from './types';

export interface AnimatedSwitcherProps extends BaseProps {
  duration?: number; // in milliseconds
  reverseDuration?: number; // in milliseconds
  switchInCurve?: string;
  switchOutCurve?: string;
}

export class AnimatedSwitcher extends React.Component<AnimatedSwitcherProps> {
  render(): ReactNode {
    return React.createElement('AnimatedSwitcher', { ...this.props });
  }
}

export default AnimatedSwitcher;
