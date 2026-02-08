export class ClipboardService {
  static setData(text: string): Promise<void> {
    return dartCallNativeAsync('Clipboard.setData', { text });
  }

  static getData(): Promise<string> {
    return dartCallNativeAsync('Clipboard.getData', {});
  }
}
