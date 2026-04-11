import React, { ReactNode } from 'react';
import { BaseProps } from './types';

export interface VisibilityProps extends BaseProps {
  visible: boolean;
  replacement?: ReactNode;
  maintainState?: boolean;
  maintainAnimation?: boolean;
  maintainSize?: boolean;
  maintainSemantics?: boolean;
  maintainInteractivity?: boolean;
}

export class Visibility extends React.Component<VisibilityProps> {
  render(): ReactNode {
    return React.createElement('Visibility', { ...this.props });
  }
}
