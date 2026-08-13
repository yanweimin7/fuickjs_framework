let _debug = false;

export function setDebug(enabled: boolean) {
  _debug = enabled;
}

export function isDebug(): boolean {
  return _debug;
}

/**
 * 调试日志。生产环境默认静默，通过 `fuickjs.configure({ debug: true })` 打开。
 * 高频路径（列表项创建/销毁、WebSocket 收发、导航兜底等）一律走这里，不要裸 console.log。
 */
export function logDebug(message: string) {
  if (_debug) {
    console.log(message);
  }
}

/** 性能埋点日志，与 logDebug 同一门控，仅语义上区分。 */
export function perfLog(message: string) {
  if (_debug) {
    console.log(message);
  }
}
