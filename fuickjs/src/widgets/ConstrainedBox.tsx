import React, { ReactNode } from 'react';
import { BaseProps, BoxConstraints } from './types';

export interface ConstrainedBoxProps extends BaseProps {
  constraints: BoxConstraints;
}

export class ConstrainedBox extends React.Component<ConstrainedBoxProps> {
  render(): ReactNode {
    return React.createElement('ConstrainedBox', { ...this.props });
  }
}

export default ConstrainedBox;
