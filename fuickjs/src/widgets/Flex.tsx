import React, { ReactNode } from 'react';
import { WidgetProps } from './types';

export interface FlexProps extends WidgetProps {
  direction: 'horizontal' | 'vertical';
  mainAxisAlignment?: 'start' | 'end' | 'center' | 'spaceBetween' | 'spaceAround' | 'spaceEvenly';
  crossAxisAlignment?: 'start' | 'end' | 'center' | 'stretch' | 'baseline';
  mainAxisSize?: 'min' | 'max';
  verticalDirection?: 'up' | 'down';
  textDirection?: 'ltr' | 'rtl';
  textBaseline?: 'alphabetic' | 'ideographic';
  clipBehavior?: 'none' | 'hardEdge' | 'antiAlias' | 'antiAliasWithSaveLayer';
}

export class Flex extends React.Component<FlexProps> {
  render(): ReactNode {
    return React.createElement('Flex', { ...this.props });
  }
}
