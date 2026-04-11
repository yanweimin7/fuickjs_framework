import React, { ReactNode } from 'react';
import { BaseProps } from './types';

export interface FractionallySizedBoxProps extends BaseProps {
  widthFactor?: number;
  heightFactor?: number;
  alignment?: string;
}

export class FractionallySizedBox extends React.Component<FractionallySizedBoxProps> {
  render(): ReactNode {
    return React.createElement('FractionallySizedBox', { ...this.props });
  }
}

export default FractionallySizedBox;
