import React, { ReactNode } from 'react';
import { WidgetProps, EdgeInsets } from './types';

export interface PaddingProps extends WidgetProps {
  padding: number | EdgeInsets;
}

export class Padding extends React.Component<PaddingProps> {
  render(): ReactNode {
    return React.createElement('Padding', { ...this.props });
  }
}

export default Padding;
