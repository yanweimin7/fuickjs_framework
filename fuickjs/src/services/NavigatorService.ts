export class NavigatorService {
  static push(path: string, params: unknown, pageId?: number | null, rootNavigator?: boolean): Promise<unknown> {
    return dartCallNative('Navigator.push', { path, params, pageId, rootNavigator });
  }

  static pop(pageId?: number | null, rootNavigator?: boolean, result?: unknown) {
    dartCallNative('Navigator.pop', { pageId, rootNavigator, result });
  }
}
