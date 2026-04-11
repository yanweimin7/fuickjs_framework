import React, { ReactNode } from 'react';
import { BaseProps } from './types';
import { FlutterProps } from './FlutterProps';

export interface BottomNavigationBarItemProps {
  icon: ReactNode;
  label?: string;
  activeIcon?: ReactNode;
  backgroundColor?: string;
  tooltip?: string;
}

export class BottomNavigationBarItem extends React.Component<BottomNavigationBarItemProps> {
  render(): ReactNode {
    const { icon, activeIcon, ...otherProps } = this.props;
    return React.createElement(
      'BottomNavigationBarItem',
      { ...otherProps },
      icon && React.createElement(FlutterProps, { propsKey: 'icon' }, icon),
      activeIcon && React.createElement(FlutterProps, { propsKey: 'activeIcon' }, activeIcon),
    );
  }
}

export interface BottomNavigationBarProps extends BaseProps {
  items: ReactNode[];
  onTap?: (index: number) => void;
  currentIndex?: number;
  elevation?: number;
  type?: string;
  fixedColor?: string;
  backgroundColor?: string;
  iconSize?: number;
  selectedItemColor?: string;
  unselectedItemColor?: string;
  selectedIconTheme?: Record<string, unknown>;
  unselectedIconTheme?: Record<string, unknown>;
  selectedFontSize?: number;
  unselectedFontSize?: number;
  selectedLabelStyle?: Record<string, unknown>;
  unselectedLabelStyle?: Record<string, unknown>;
  showSelectedLabels?: boolean;
  showUnselectedLabels?: boolean;
  mouseCursor?: string;
  enableFeedback?: boolean;
  landscapeLayout?: string;
  useLegacyColorScheme?: boolean;
}

export class BottomNavigationBar extends React.Component<BottomNavigationBarProps> {
  render(): ReactNode {
    const { items, children, ...otherProps } = this.props;
    return React.createElement(
      'BottomNavigationBar',
      { ...otherProps },
      items &&
        items.map((item, index) =>
          React.createElement(FlutterProps, { key: `item-${index}`, propsKey: 'items' }, item),
        ),
      children,
    );
  }
}

export default BottomNavigationBar;
