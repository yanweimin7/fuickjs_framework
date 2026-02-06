export class TimerService {
  static createTimer(id: number, delay: number, isInterval: boolean) {
    dartCallNative('Timer.createTimer', { id, delay, isInterval });
  }

  static deleteTimer(id: number) {
    dartCallNative('Timer.deleteTimer', { id });
  }
}
