let _debug = false;

export function setDebug(enabled: boolean) {
  _debug = enabled;
}

export function isDebug(): boolean {
  return _debug;
}

export function perfLog(message: string) {
  if (_debug) {
    console.log(message);
  }
}
