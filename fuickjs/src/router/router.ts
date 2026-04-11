import React from 'react';

type ComponentFactory = (params?: unknown) => React.ReactElement;
const routes: Record<string, ComponentFactory> = {};

export function register(path: string, componentFactory: ComponentFactory) {
  routes[path] = componentFactory;
}

export function match(path: string): ComponentFactory | undefined {
  return routes[path];
}

export const Router = {
  register,
  match,
};
