import globalAny from './global';

if (!(globalAny as any).process) {
  (globalAny as any).process = {
    env: { NODE_ENV: 'production' },
    version: 'v16.0.0',
    nextTick: (cb: () => void) => setTimeout(cb, 0),
    browser: false,
  };
}
