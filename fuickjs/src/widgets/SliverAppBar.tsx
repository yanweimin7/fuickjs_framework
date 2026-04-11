import React, { ReactNode } from 'react';
import { WidgetProps } from './types';
import { BaseWidget } from './BaseWidget';
import { FlutterProps } from './FlutterProps';

export interface SliverAppBarProps extends WidgetProps {
  title?: ReactNode;
  leading?: ReactNode;
  actions?: ReactNode[];
  expandedHeight?: number;
  pinned?: boolean;
  floating?: boolean;
  snap?: boolean;
  backgroundColor?: string;
  elevation?: number;
  toolbarHeight?: number;
  bottom?: ReactNode;
}

export class SliverAppBar extends BaseWidget<SliverAppBarProps> {
  render(): ReactNode {
    const { children, title, leading, actions, bottom, ...rest } = this.props;
    return React.createElement(
      'SliverAppBar',
      {
        ...rest,
        isBoundary: true,
      },
      title && React.createElement(FlutterProps, { propsKey: 'title' }, title),
      leading && React.createElement(FlutterProps, { propsKey: 'leading' }, leading),
      actions &&
        actions.map((action, index) => (
          <FlutterProps key={`action-${index}`} propsKey="actions">
            {action}
          </FlutterProps>
        )),
      bottom && React.createElement(FlutterProps, { propsKey: 'bottom' }, bottom),
      children,
    );
  }
}

export default SliverAppBar;
