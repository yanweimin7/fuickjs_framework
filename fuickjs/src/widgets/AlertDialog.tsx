import React, { ReactNode } from 'react';
import { WidgetProps } from './types';

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
    return React.createElement('AlertDialog', { ...this.props });
  }
}

export default AlertDialog;
