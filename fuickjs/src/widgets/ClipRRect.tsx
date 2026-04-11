import React, { ReactNode } from 'react';
import { WidgetProps } from './types';

export interface ClipRRectProps extends WidgetProps {
  borderRadius?: number | { topLeft?: number; topRight?: number; bottomLeft?: number; bottomRight?: number };
  clipBehavior?: 'none' | 'hardEdge' | 'antiAlias' | 'antiAliasWithSaveLayer';
}

export class ClipRRect extends React.Component<ClipRRectProps> {
  render(): ReactNode {
    return React.createElement('ClipRRect', { ...this.props });
  }
}

export default ClipRRect;
