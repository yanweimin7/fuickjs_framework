import React from 'react';
import { PageContext, PageContextValue } from '../core/PageContext';
import { refsId } from '../utils/ids';
import { WidgetProps } from './types';
import { UIService } from '../services/UIService';

export abstract class BaseWidget<
  P extends WidgetProps = WidgetProps,
  S = Record<string, unknown>,
> extends React.Component<P, S> {
  static contextType = PageContext;
  declare context: React.ContextType<typeof PageContext>;
  private _internalRefId = refsId();

  public get rawRefId(): string {
    return (
      this.props.refId ||
      this.props.id?.toString() ||
      (this.props as { key?: React.Key }).key?.toString() ||
      this._internalRefId
    );
  }

  public get pageId(): number {
    return (this.context as PageContextValue)?.pageId || 0;
  }

  public get scopedRefId(): string {
    const raw = this.rawRefId;
    // If it already contains ':', it's likely already scoped
    if (raw.indexOf(':') !== -1) {
      return raw;
    }
    return `${this.pageId}:${raw}`;
  }

  protected callNativeCommand(method: string, args: Record<string, unknown> = {}, nodeType?: string) {
    UIService.componentCommand(
      this.pageId,
      this.scopedRefId,
      method,
      args,
      nodeType || (this.constructor as unknown as { name: string }).name,
    );
  }
}
