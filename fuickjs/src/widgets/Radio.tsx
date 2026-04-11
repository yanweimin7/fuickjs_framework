import React, { ReactNode } from 'react';
import { WidgetProps } from './types';

export interface RadioProps extends WidgetProps {
  value: string;
  groupValue: string;
  activeColor?: string;
  onChanged?: (value: string) => void;
}

export class Radio extends React.Component<RadioProps> {
  render(): ReactNode {
    return React.createElement('Radio', { ...this.props });
  }
}

export default Radio;
