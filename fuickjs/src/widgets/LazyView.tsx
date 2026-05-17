import React from 'react';
import { SizedBox } from '../index';

export interface LazyViewProps {
  load?: boolean;
  fallback?: React.ReactNode;
  builder: () => React.ReactNode;
}

export function LazyView({ load, fallback, builder }: LazyViewProps) {
  const isLoaded = load;
  if (!isLoaded) {
    return fallback || <SizedBox width={0} height={0} />;
  }
  return builder();
}

export default LazyView;
