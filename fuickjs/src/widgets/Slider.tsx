import React, { ReactNode } from 'react';
import { WidgetProps } from './types';

export interface SliderProps extends WidgetProps {
  value: number;
  min?: number;
  max?: number;
  step?: number;
  activeColor?: string;
  inactiveColor?: string;
  onChanged?: (value: number) => void;
  onChanging?: (value: number) => void;
}

export class Slider extends React.Component<SliderProps> {
  render(): ReactNode {
    return React.createElement('Slider', { ...this.props });
  }
}

export default Slider;
