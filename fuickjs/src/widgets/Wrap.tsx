import React, { ReactNode } from 'react';
import { WidgetProps } from './types';
import { BaseWidget } from './BaseWidget';

export interface WrapProps extends WidgetProps {
  direction?: 'horizontal' | 'vertical';
  alignment?: 'start' | 'end' | 'center' | 'spaceBetween' | 'spaceAround' | 'spaceEvenly';
  spacing?: number;
  runAlignment?: 'start' | 'end' | 'center' | 'spaceBetween' | 'spaceAround' | 'spaceEvenly';
  runSpacing?: number;
  crossAxisAlignment?: 'start' | 'end' | 'center' | 'baseline' | 'stretch';
  verticalDirection?: 'up' | 'down';
  clipBehavior?: 'none' | 'hardEdge' | 'antiAlias' | 'antiAliasWithSaveLayer';
  children?: ReactNode;
}

export class Wrap extends BaseWidget<WrapProps> {
  render(): ReactNode {
    return React.createElement('Wrap', { ...this.props, isBoundary: true });
  }
}
