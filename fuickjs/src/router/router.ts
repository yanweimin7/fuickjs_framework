import React from 'react';
import { GenericPage } from '../widgets/GenericPage';

type ComponentFactory = (params?: unknown) => React.ReactElement;
const routes: Record<string, ComponentFactory> = {};

// Internal routes registered by the framework
routes['/_generic_dialog'] = (args) => React.createElement(GenericPage, args as any);

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
