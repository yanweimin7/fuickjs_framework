import React, { ReactNode } from 'react';
import { WidgetProps } from './types';
import { BaseWidget } from './BaseWidget';

export interface CardProps extends WidgetProps {
  color?: string;
  shadowColor?: string;
  surfaceTintColor?: string;
  elevation?: number;
  clipBehavior?: 'none' | 'hardEdge' | 'antiAlias' | 'antiAliasWithSaveLayer';
  child?: ReactNode;
  children?: ReactNode; // Support children alias for child
}

export class Card extends BaseWidget<CardProps> {
  render(): ReactNode {
    const { child, children, ...rest } = this.props;
    // Prefer child, fallback to children (standard React pattern)
    const content = child || children;

    return React.createElement('Card', { ...rest, isBoundary: true }, content);
  }
}
