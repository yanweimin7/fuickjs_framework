import React, { ReactNode } from 'react';
import { WidgetProps } from './types';

export interface FloatingActionButtonProps extends WidgetProps {
  onPressed?: () => void;
}

export class FloatingActionButton extends React.Component<FloatingActionButtonProps> {
  render(): ReactNode {
    return React.createElement('FloatingActionButton', { ...this.props });
  }
}

export default FloatingActionButton;
