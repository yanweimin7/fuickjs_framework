import React, { ReactNode } from 'react';
import { BaseProps } from './types';

export type SafeAreaProps = BaseProps;

export class SafeArea extends React.Component<SafeAreaProps> {
  render(): ReactNode {
    return React.createElement('SafeArea', { ...this.props, isBoundary: false });
  }
}

export default SafeArea;
