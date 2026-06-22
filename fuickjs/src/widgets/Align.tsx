import React, { ReactNode } from 'react';
import { BaseProps } from './types';

export interface AlignProps extends BaseProps {
  alignment:
    | 'topLeft'
    | 'topCenter'
    | 'topRight'
    | 'centerLeft'
    | 'center'
    | 'centerRight'
    | 'bottomLeft'
    | 'bottomCenter'
    | 'bottomRight';
  widthFactor?: number;
  heightFactor?: number;
}

export class Align extends React.Component<AlignProps> {
  render(): ReactNode {
    return React.createElement('Align', { ...this.props });
  }
}

export default Align;
