import React from 'react';
import { GenericPage } from '../widgets/GenericPage';

type ComponentFactory = (params?: unknown) => React.ReactElement;

export interface RouteConfig {
  prewarmMs?: number;
}

const routes: Record<string, ComponentFactory> = {};
const routeConfigs: Record<string, RouteConfig> = {};

// Internal routes registered by the framework
routes['/_generic_dialog'] = (args) => React.createElement(GenericPage, args as any);

export function register(path: string, componentFactory: ComponentFactory, config?: RouteConfig) {
  routes[path] = componentFactory;
  if (config) {
    routeConfigs[path] = config;
  }
}

export function match(path: string): ComponentFactory | undefined {
  return routes[path];
}

export function getConfig(path: string): RouteConfig | undefined {
  return routeConfigs[path];
}

export const Router = {
  register,
  match,
  getConfig,
};
