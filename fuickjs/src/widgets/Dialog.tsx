import React, { ReactNode } from 'react';
import { WidgetProps } from './types';
import { BaseWidget } from './BaseWidget';

export interface DialogProps extends WidgetProps {
  elevation?: number;
  backgroundColor?: string;
  borderRadius?: number;
  insetPadding?: number | { horizontal?: number; vertical?: number };
  child?: ReactNode;
  children?: ReactNode;
}

export class Dialog extends BaseWidget<DialogProps> {
  render(): ReactNode {
    const { child, children, ...rest } = this.props;
    const content = child || children;
    return React.createElement('Dialog', { ...rest }, content);
  }
}
