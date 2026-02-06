import React from 'react';
import { createRenderer, Renderer } from './renderer';
import * as Router from './router';
import { PageContext } from './PageContext';
import { ErrorBoundary } from './ErrorBoundary';

let renderer: Renderer | null = null;
let globalErrorFallback: ((error: Error) => React.ReactNode) | null = null;

export function setGlobalErrorFallback(fallback: (error: Error) => React.ReactNode) {
  globalErrorFallback = fallback;
}

export function ensureRenderer() {
  if (renderer) return renderer;
  renderer = createRenderer();
  return renderer;
}

export function render(pageId: number, path: string, params: unknown) {
  const startTime = Date.now();
  const r = ensureRenderer();
  console.log(`[JS Performance] render start for ${path}, pageId: ${pageId}`);
  const factory = Router.match(path);

  let app: React.ReactNode;
  if (typeof factory === 'function') {
    app = factory(params || {});
  } else {
    app = React.createElement(
      'Column',
      { padding: 16, mainAxisAlignment: 'center' },
      React.createElement('Text', { text: `Route ${path} not found`, fontSize: 16, color: '#cc0000' }),
    );
  }

  // Wrap with PageContext and ErrorBoundary
  const fallbackUI =
    globalErrorFallback ||
    ((error: Error) =>
      React.createElement(
        'Column',
        {
          mainAxisAlignment: 'center',
          crossAxisAlignment: 'center',
          padding: 20,
          decoration: { color: '#FFF0F0' },
        },
        React.createElement('Text', {
          text: 'Application Error',
          fontSize: 20,
          color: '#D32F2F',
          fontWeight: 'bold',
          margin: { bottom: 10 },
        }),
        React.createElement('Text', {
          text: error?.message || 'Unknown error occurred',
          fontSize: 14,
          color: '#333333',
          maxLines: 10,
          overflow: 'ellipsis',
        }),
      ));

  const wrappedApp = React.createElement(
    PageContext.Provider,
    { value: { pageId } },
    React.createElement(
      ErrorBoundary,
      {
        fallback: fallbackUI,
      },
      app,
    ),
  );
  r.update(wrappedApp, pageId);

  console.log(`[JS Performance] render total cost for ${path}: ${Date.now() - startTime}ms`);
}

export function destroy(pageId: number) {
  const r = ensureRenderer();
  r.destroy(pageId);
}

export function getItemDSL(pageId: number, refId: string, index: number) {
  const r = ensureRenderer();
  return r.getItemDSL(pageId, refId, index);
}

export function elementToDsl(pageId: number, element: React.ReactNode) {
  const r = ensureRenderer();
  return r.elementToDsl(pageId, element);
}

export function notifyLifecycle(pageId: number, type: 'visible' | 'invisible') {
  const r = ensureRenderer();
  r.notifyLifecycle(pageId, type);
}

export function getContainer(pageId: number) {
  const r = ensureRenderer();
  return r.getContainer(pageId);
}
