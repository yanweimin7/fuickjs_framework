import React, { ReactNode } from 'react';
import { WidgetProps } from './types';
import { FlutterProps } from './FlutterProps';

export interface TabBarProps extends WidgetProps {
  tabs: ReactNode[];
  isScrollable?: boolean;
  indicatorColor?: string;
  indicatorWeight?: number;
  labelColor?: string;
  unselectedLabelColor?: string;
  onTap?: (index: number) => void;
}

export class TabBar extends React.Component<TabBarProps> {
  render(): ReactNode {
    const { tabs, ...otherProps } = this.props;
    return React.createElement(
      'TabBar',
      { ...otherProps, isBoundary: false },
      tabs && tabs.map((tab, index) => React.createElement(FlutterProps, { key: index, propsKey: 'tabs' }, tab)),
    );
  }
}

export interface TabBarViewProps extends WidgetProps {
  children: ReactNode[];
  onPageChanged?: (index: number) => void;
}

export class TabBarView extends React.Component<TabBarViewProps> {
  render(): ReactNode {
    return React.createElement('TabBarView', { ...this.props, isBoundary: true });
  }
}

export interface DefaultTabControllerProps extends WidgetProps {
  length: number;
  initialIndex?: number;
  children?: ReactNode;
}

export class DefaultTabController extends React.Component<DefaultTabControllerProps> {
  render(): ReactNode {
    return React.createElement('DefaultTabController', { ...this.props, isBoundary: true });
  }
}

export interface TabProps extends WidgetProps {
  text?: string;
  icon?: ReactNode;
  child?: ReactNode;
}

export class Tab extends React.Component<TabProps> {
  render(): ReactNode {
    return React.createElement('Tab', { ...this.props, isBoundary: false });
  }
}
