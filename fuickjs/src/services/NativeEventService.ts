export class NativeEventService {
  static emit(event: string, data: unknown) {
    // worker isolate 中 NativeEventService 不在白名单, 必须 async。
    void dartCallNativeAsync('NativeEvent.emit', [event, data]);
  }
}
