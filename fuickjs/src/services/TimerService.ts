export class TimerService {
  static createTimer(id: number, delay: number, isInterval: boolean) {
    console.log(`[TimerService] createTimer() id=${id}, delay=${delay}ms, isInterval=${isInterval}`);
    dartCallNative('Timer.createTimer', { id, delay, isInterval });
  }

  static deleteTimer(id: number) {
    console.log(`[TimerService] deleteTimer() id=${id}`);
    dartCallNative('Timer.deleteTimer', { id });
  }
}
