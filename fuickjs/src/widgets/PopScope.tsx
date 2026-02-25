import React, { ReactNode } from 'react';
import { WidgetProps } from './types';

export interface PopScopeProps extends WidgetProps {
  canPop?: boolean;
  onPopInvoked?: (didPop: boolean) => void;
  children?: ReactNode;
}

export class PopScope extends React.Component<PopScopeProps> {
  render(): ReactNode {
    return React.createElement('PopScope', { ...this.props });
  }
}

export default PopScope;
