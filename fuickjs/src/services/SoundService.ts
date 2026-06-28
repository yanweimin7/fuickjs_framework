export class SoundService {
  static play(type?: 'move' | 'capture' | 'check' | 'win'): void {
    // worker isolate 中 SoundService 不在白名单, 必须 async。
    void dartCallNativeAsync('Sound.play', { type: type ?? 'move' });
  }
}
