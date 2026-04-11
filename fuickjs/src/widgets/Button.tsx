import React, { ReactNode } from 'react';
import { WidgetProps } from './types';

export interface ButtonProps extends WidgetProps {
  text?: string;
  onTap?: () => void;
  disabled?: boolean;
  loading?: boolean;
  backgroundColor?: string;
  textColor?: string;
  fontSize?: number;
  borderRadius?: number;
  elevation?: number;
  outlined?: boolean;
  borderColor?: string;
  borderWidth?: number;
  minWidth?: number;
  minHeight?: number;
  paddingH?: number;
  paddingV?: number;
}

export class Button extends React.Component<ButtonProps> {
  render(): ReactNode {
    return React.createElement('Button', {
      ...this.props,
    });
  }
}

export default Button;
