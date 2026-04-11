import React, { ReactNode } from 'react';
import { WidgetProps } from './types';
import { BaseWidget } from './BaseWidget';

export interface CheckboxProps extends WidgetProps {
  value?: boolean;
  onChanged?: (value: boolean) => void;
  activeColor?: string;
  checkColor?: string;
  tristate?: boolean;
}

export class Checkbox extends BaseWidget<CheckboxProps> {
  render(): ReactNode {
    return React.createElement('Checkbox', { ...this.props });
  }
}
