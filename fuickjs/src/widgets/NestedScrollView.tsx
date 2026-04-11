import React, { ReactNode } from 'react';
import { BaseProps } from './types';

export interface NestedScrollViewProps extends BaseProps {
  scrollDirection?: string;
  reverse?: boolean;
  physics?: string;
}

/**
 * NestedScrollView with a pinned header and scrollable body.
 *
 * Use FlutterProps to specify named children:
 * ```tsx
 * <NestedScrollView>
 *   <FlutterProps propsKey="headerSliverBuilder">
 *     <SliverAppBar ... />
 *   </FlutterProps>
 *   <FlutterProps propsKey="body">
 *     <ListView ... />
 *   </FlutterProps>
 * </NestedScrollView>
 * ```
 */
export class NestedScrollView extends React.Component<NestedScrollViewProps> {
  render(): ReactNode {
    return React.createElement('NestedScrollView', { ...this.props });
  }
}

export default NestedScrollView;
