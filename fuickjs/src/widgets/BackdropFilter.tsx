import React, { ReactNode } from 'react';
import { BaseProps } from './types';

export interface BackdropFilterProps extends BaseProps {
  sigmaX?: number;
  sigmaY?: number;
  blendMode?: string;
}

export class BackdropFilter extends React.Component<BackdropFilterProps> {
  render(): ReactNode {
    return React.createElement('BackdropFilter', { ...this.props });
  }
}

export default BackdropFilter;
