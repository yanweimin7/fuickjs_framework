import React, { ReactNode } from 'react';
import { WidgetProps } from './types';
import { BaseWidget } from './BaseWidget';

export interface CustomScrollViewProps extends WidgetProps {
  scrollDirection?: 'horizontal' | 'vertical';
  reverse?: boolean;
  shrinkWrap?: boolean;
  physics?: 'never' | 'bouncing' | 'clamping' | 'always';
}

export class CustomScrollView extends BaseWidget<CustomScrollViewProps> {
  render(): ReactNode {
    const { children, ...rest } = this.props;
    return React.createElement(
      'CustomScrollView',
      {
        ...rest,
      },
      children,
    );
  }
}

export default CustomScrollView;
