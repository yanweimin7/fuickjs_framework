import React, { ReactNode } from 'react';
import { WidgetProps } from './types';
import { ScrollableBaseWidget } from './ScrollableBaseWidget';

export interface ListViewProps extends WidgetProps {
  scrollDirection?: 'horizontal' | 'vertical';
  orientation?: 'horizontal' | 'vertical';
  shrinkWrap?: boolean;
  itemCount?: number;
  itemBuilder?: (index: number) => ReactNode;
  cacheKey?: unknown;
  /** 是否为有状态列表（走 reconciler sub-root，支持 useState/useEffect）。默认 false。设为 true 则走 reconciler，拥有完整生命周期。 */
  stateful?: boolean;
}

export class ListView extends ScrollableBaseWidget<ListViewProps> {
  public animateTo(offset: number, duration: number = 300, curve: string = 'easeInOut') {
    this.callNativeCommand('animateTo', { offset, duration, curve });
  }

  public jumpTo(offset: number) {
    this.callNativeCommand('jumpTo', { offset });
  }

  render(): ReactNode {
    const { children, ...rest } = this.props;

    return React.createElement(
      'ListView',
      {
        ...rest,
        hasBuilder: !!this.props.itemBuilder,
        stateful: this.props.stateful === true,
        refId: this.scopedRefId,
        isBoundary: true,
      },
      children,
    );
  }
}

export default ListView;
