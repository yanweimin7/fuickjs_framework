import React, { ReactNode } from 'react';
import { WidgetProps } from './types';
import { BaseWidget } from './BaseWidget';

export interface MaterialProps extends WidgetProps {
  type?: 'canvas' | 'card' | 'circle' | 'button' | 'transparency';
  elevation?: number;
  color?: string;
  shadowColor?: string;
  surfaceTintColor?: string;
  textStyle?: {
    color?: string;
    fontSize?: number;
    fontWeight?: 'normal' | 'bold';
    fontStyle?: 'normal' | 'italic';
  };
  borderRadius?:
    | number
    | {
        topLeft?: number;
        topRight?: number;
        bottomLeft?: number;
        bottomRight?: number;
      };
  borderOnForeground?: boolean;
  clipBehavior?: 'none' | 'hardEdge' | 'antiAlias' | 'antiAliasWithSaveLayer';
  animationDuration?: number;
  child?: ReactNode;
  children?: ReactNode;
}

export class Material extends BaseWidget<MaterialProps> {
  render(): ReactNode {
    const { child, children, ...rest } = this.props;
    const content = child || children;
    return React.createElement('Material', { ...rest }, content);
  }
}
