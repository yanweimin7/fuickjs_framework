import React, { ReactNode } from 'react';
import { BaseProps } from './types';

export interface AspectRatioProps extends BaseProps {
  aspectRatio: number;
}

export class AspectRatio extends React.Component<AspectRatioProps> {
  render(): ReactNode {
    return React.createElement('AspectRatio', { ...this.props });
  }
}

export default AspectRatio;
