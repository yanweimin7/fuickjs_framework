import React, { ReactNode } from 'react';
import { BaseProps } from './types';

export interface OverlayProps extends BaseProps {
  visible: boolean;
  overlayKey?: string;
}

export class Overlay extends React.Component<OverlayProps> {
  render(): ReactNode {
    return React.createElement(
      'Overlay',
      {
        visible: this.props.visible,
        overlayKey: this.props.overlayKey,
        isBoundary: true,
      },
      this.props.children,
    );
  }
}
