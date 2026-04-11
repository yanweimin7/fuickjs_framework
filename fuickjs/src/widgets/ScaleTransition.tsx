import React, { ReactNode } from 'react';
import { BaseProps } from './types';

export interface ScaleTransitionProps extends BaseProps {
  scale: number;
  alignment?: string;
}

export class ScaleTransition extends React.Component<ScaleTransitionProps> {
  render(): ReactNode {
    return React.createElement('ScaleTransition', { ...this.props });
  }
}

export default ScaleTransition;
