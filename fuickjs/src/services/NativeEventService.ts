export class NativeEventService {
  static emit(event: string, data: unknown) {
    dartCallNative('NativeEvent.emit', [event, data]);
  }
}
