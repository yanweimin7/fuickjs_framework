import React, { ReactNode } from 'react';
import { BaseProps } from './types';

export interface DrawerProps extends BaseProps {
  backgroundColor?: string;
  elevation?: number;
  width?: number;
}

export class Drawer extends React.Component<DrawerProps> {
  render(): ReactNode {
    return React.createElement('Drawer', { ...this.props });
  }
}

export default Drawer;
