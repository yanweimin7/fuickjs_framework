import React, { ReactNode } from 'react';
import { BaseProps } from './types';

export interface FittedBoxProps extends BaseProps {
  fit?: 'fill' | 'contain' | 'cover' | 'fitWidth' | 'fitHeight' | 'none' | 'scaleDown';
  alignment?: string;
  clipBehavior?: 'none' | 'hardEdge' | 'antiAlias' | 'antiAliasWithSaveLayer';
}

export class FittedBox extends React.Component<FittedBoxProps> {
  render(): ReactNode {
    return React.createElement('FittedBox', { ...this.props });
  }
}

export default FittedBox;
