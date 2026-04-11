import React, { ReactNode } from 'react';
import { BaseProps, Offset } from './types';

export interface SlideTransitionProps extends BaseProps {
  position: Offset;
  transformHitTests?: boolean;
}

export class SlideTransition extends React.Component<SlideTransitionProps> {
  render(): ReactNode {
    return React.createElement('SlideTransition', { ...this.props });
  }
}

export default SlideTransition;
