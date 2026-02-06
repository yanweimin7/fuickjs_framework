import React, { ReactNode } from 'react';
import { WidgetProps } from './types';
import { BaseWidget } from './BaseWidget';

export interface TextFieldProps extends WidgetProps {
  text?: string;
  hintText?: string;
  hint?: string;
  onChanged?: (value: string) => void;
  onSubmitted?: (value: string) => void;
}

export class TextField extends BaseWidget<TextFieldProps> {
  public setText(text: string) {
    this.callNativeCommand('setText', { text });
  }

  public clear() {
    this.callNativeCommand('clear', {});
  }

  public focus() {
    this.callNativeCommand('focus', {});
  }

  public unfocus() {
    this.callNativeCommand('unfocus', {});
  }

  public setSelection(start: number, end: number) {
    this.callNativeCommand('setSelection', { start, end });
  }

  public selectAll() {
    this.callNativeCommand('selectAll', {});
  }

  render(): ReactNode {
    return React.createElement('TextField', {
      ...this.props,
      refId: this.scopedRefId,
      isBoundary: true,
    });
  }
}

export default TextField;
