import React, { ReactNode } from 'react';
import { WidgetProps } from './types';
import { FlutterProps } from './FlutterProps';

export interface AlertDialogProps extends WidgetProps {
  title?: ReactNode;
  content?: ReactNode;
  actions?: ReactNode[];
  actionsPadding?: number | number[]; // padding for actions
  actionsAlignment?: 'start' | 'end' | 'center' | 'spaceBetween' | 'spaceAround' | 'spaceEvenly';
  shape?: unknown; // To be defined more strictly if needed
  backgroundColor?: string;
  elevation?: number;
}

export class AlertDialog extends React.Component<AlertDialogProps> {
  render(): ReactNode {
    const { title, content, actions, ...otherProps } = this.props;
    return React.createElement(
      'AlertDialog',
      { ...otherProps },
      title && React.createElement(FlutterProps, { propsKey: 'title' }, title),
      content && React.createElement(FlutterProps, { propsKey: 'content' }, content),
      actions && React.createElement(FlutterProps, { propsKey: 'actions' }, actions),
    );
  }
}

export default AlertDialog;
