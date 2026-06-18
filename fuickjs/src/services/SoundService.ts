export class SoundService {
  static play(type?: 'move' | 'capture' | 'check' | 'win'): void {
    dartCallNative('Sound.play', { type: type ?? 'move' });
  }
}
