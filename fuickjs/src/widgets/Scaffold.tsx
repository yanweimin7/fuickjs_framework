import React, { ReactNode } from 'react';
import { BaseProps } from './types';
import { FlutterProps } from './FlutterProps';

export interface ScaffoldProps extends BaseProps {
  appBar?: ReactNode;
  floatingActionButton?: ReactNode;
  drawer?: ReactNode;
  endDrawer?: ReactNode;
  bottomNavigationBar?: ReactNode;
  bottomSheet?: ReactNode;
  backgroundColor?: string;
}

export class Scaffold extends React.Component<ScaffoldProps> {
  render(): ReactNode {
    const {
      appBar,
      floatingActionButton,
      drawer,
      endDrawer,
      bottomNavigationBar,
      bottomSheet,
      children,
      ...otherProps
    } = this.props;
    return React.createElement(
      'Scaffold',
      {
        isBoundary: true,
        ...otherProps,
      },
      appBar && React.createElement(FlutterProps, { propsKey: 'appBar' }, appBar),
      floatingActionButton &&
        React.createElement(FlutterProps, { propsKey: 'floatingActionButton' }, floatingActionButton),
      drawer && React.createElement(FlutterProps, { propsKey: 'drawer' }, drawer),
      endDrawer && React.createElement(FlutterProps, { propsKey: 'endDrawer' }, endDrawer),
      bottomNavigationBar &&
        React.createElement(FlutterProps, { propsKey: 'bottomNavigationBar' }, bottomNavigationBar),
      bottomSheet && React.createElement(FlutterProps, { propsKey: 'bottomSheet' }, bottomSheet),
      children,
    );
  }
}

export default Scaffold;
