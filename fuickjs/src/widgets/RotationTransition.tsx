import React, { ReactNode } from 'react';
import { BaseProps } from './types';

export interface RotationTransitionProps extends BaseProps {
  turns: number;
  alignment?: string;
}

export class RotationTransition extends React.Component<RotationTransitionProps> {
  render(): ReactNode {
    return React.createElement('RotationTransition', { ...this.props });
  }
}

export default RotationTransition;
